import AVKit
import PTCore
import PTWeb
import SGitVault
import SwiftUI

// Videos (news app redesign, at Indi's word, 10 November 2026: "people need to watch videos within the app").
// The interviews on promptugal.news live in a public SG/Vault, cut into 4-second fragmented-MP4 segments. The site lists
// them in api/v1/live/videos.json with the same public coordinates each page carries (endpoint, vault id, public read
// key, folder). The app reads the folder's manifest with SGitVault, decrypts init.mp4 and the segments in order, joins
// them into one MP4 in Caches, and plays it with AVKit. A video played once plays again offline.

/// One interview video from api/v1/live/videos.json.
public struct VideoItem: Decodable, Identifiable, Hashable, Sendable {
    public struct Vault: Decodable, Hashable, Sendable {
        public let endpoint: String
        public let id: String
        public let readKey: String
        public let path: String

        enum CodingKeys: String, CodingKey {
            case endpoint, id, path
            case readKey = "read_key"
        }
    }

    public let title: String
    public let person: String
    public let company: String
    public let interviewer: String?
    public let date: String?
    public let summary: String?
    public let page: String
    public let vault: Vault

    public var id: String { page }
    var pageURL: URL { FeedClient.site.appendingPathComponent(page) }
    /// The video's folder in the vault, without a trailing slash.
    var folder: String { vault.path.hasSuffix("/") ? String(vault.path.dropLast()) : vault.path }
}

struct VideoList: Decodable {
    let items: [VideoItem]
}

/// The folder's manifest.json: the init segment, then the media segments in order.
struct VideoManifest: Decodable {
    struct Segment: Decodable {
        let file: String
    }

    let initFile: String
    let segments: [Segment]
    let duration: Double?

    enum CodingKeys: String, CodingKey {
        case segments, duration
        case initFile = "init"
    }

    /// The files to join, in order. A name with a slash or "..": the manifest is refused.
    func files() throws -> [String] {
        let all = [initFile] + segments.map(\.file)
        guard all.allSatisfy(VideoRules.isPlainName) else { throw URLError(.badURL) }
        return all
    }
}

/// Pure rules, so the unit tests can check them.
enum VideoRules {
    /// A file name inside the video's folder: no path, no "..", not empty.
    static func isPlainName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && name != "." && name != ".."
    }

    /// The vault server must be https.
    static func server(_ endpoint: String) -> URL? {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host() != nil else { return nil }
        return url
    }

    /// How much of the video has arrived, 0 to 100.
    static func percent(_ done: Int, _ total: Int) -> Int {
        total > 0 ? min(100, done * 100 / total) : 0
    }

    /// The name of the joined file in Caches, from the video's folder.
    static func fileName(folder: String) -> String {
        folder.replacingOccurrences(of: "/", with: "_") + ".mp4"
    }
}

/// One turn of a machine transcript: "Speaker 1: words".
struct TranscriptTurn: Equatable, Identifiable {
    let id: Int
    let speaker: String?
    let text: String

    static func parse(_ text: String) -> [TranscriptTurn] {
        var turns: [TranscriptTurn] = []
        var speaker: String?
        var words: [String] = []
        func flush() {
            let joined = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !joined.isEmpty { turns.append(TranscriptTurn(id: turns.count, speaker: speaker, text: joined)) }
            words = []
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let colon = line.firstIndex(of: ":"), line[..<colon].hasPrefix("Speaker "), line[..<colon].count <= 12 {
                flush()
                speaker = String(line[..<colon])
                words.append(String(line[line.index(after: colon)...]))
            } else if line.hasPrefix("Speaker "), line.count <= 12 {
                // A speaker on a line of its own, with the words on the next lines.
                flush()
                speaker = line
            } else {
                words.append(line)
            }
        }
        flush()
        return turns
    }
}

/// The list of videos, from the site, with the last copy kept for offline.
@MainActor @Observable
final class VideoFeed {
    static let shared = VideoFeed()
    static let url = FeedClient.site.appendingPathComponent("api/v1/live/videos.json")

    private(set) var items: [VideoItem] = []
    private(set) var failed = false

    private var saved: URL { URL.cachesDirectory.appending(path: "videos.json") }

    init() {
        if let data = try? Data(contentsOf: saved), let list = try? JSONDecoder().decode(VideoList.self, from: data) {
            items = list.items
        }
    }

    func load() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            items = try JSONDecoder().decode(VideoList.self, from: data).items
            failed = false
            try? data.write(to: saved, options: .atomic)
        } catch {
            failed = items.isEmpty
        }
    }
}

/// Loads one video's poster and the video itself from the vault.
@MainActor @Observable
final class VideoLoader {
    enum Phase: Equatable {
        case idle
        case loading(done: Int, total: Int)
        case ready(URL)
        case failed
    }

    let item: VideoItem
    private(set) var phase: Phase = .idle
    private(set) var poster: UIImage?
    private var vault: SGitVault?

    private static var loaders: [String: VideoLoader] = [:]

    /// One loader per video, so the list and the player share the poster and the download.
    static func loader(_ item: VideoItem) -> VideoLoader {
        if let existing = loaders[item.id] { return existing }
        let made = VideoLoader(item: item)
        loaders[item.id] = made
        return made
    }

    private static var folder: URL { URL.cachesDirectory.appending(path: "videos", directoryHint: .isDirectory) }
    private var file: URL { Self.folder.appending(path: VideoRules.fileName(folder: item.folder)) }

    private init(item: VideoItem) {
        self.item = item
        if FileManager.default.fileExists(atPath: file.path) { phase = .ready(file) }
    }

    private func openVault() throws -> SGitVault {
        if let vault { return vault }
        guard let server = VideoRules.server(item.vault.endpoint) else { throw URLError(.badURL) }
        let key = try VaultKey.parse(item.vault.readKey + ":" + item.vault.id)
        // The encrypted pieces are kept only for this run: the joined MP4 in Caches is the offline copy.
        let made = SGitVault(key: key, server: server,
                             cache: FileManager.default.temporaryDirectory.appending(path: "video-vault"),
                             log: VaultTrafficLog())
        vault = made
        return made
    }

    private(set) var transcript: [TranscriptTurn]?
    private(set) var transcriptFailed = false

    /// The machine transcript beside the video's folder (transcript-machine.txt), as speaker turns.
    func loadTranscript() async {
        guard transcript == nil else { return }
        transcriptFailed = false
        let parent = (item.folder as NSString).deletingLastPathComponent
        guard let vault = try? openVault(),
              let data = try? await vault.read(parent + "/transcript-machine.txt"),
              let text = String(data: data, encoding: .utf8) else {
            transcriptFailed = true
            return
        }
        transcript = TranscriptTurn.parse(text)
    }

    func loadPoster() async {
        guard poster == nil, let vault = try? openVault() else { return }
        let parent = (item.folder as NSString).deletingLastPathComponent
        for path in [item.folder + "/poster.jpg", parent + "/poster.jpg"] {
            if let data = try? await vault.read(path), let image = UIImage(data: data) {
                poster = image
                return
            }
        }
    }

    /// Fetches, decrypts and joins the segments, then the phase is `ready` with the file to play.
    func load() async {
        switch phase {
        case .loading, .ready: return
        case .idle, .failed: break
        }
        do {
            let vault = try openVault()
            let manifest = try JSONDecoder().decode(VideoManifest.self, from: try await vault.read(item.folder + "/manifest.json"))
            let files = try manifest.files()
            phase = .loading(done: 0, total: files.count)
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            let part = file.appendingPathExtension("part")
            FileManager.default.createFile(atPath: part.path, contents: nil)
            let handle = try FileHandle(forWritingTo: part)
            do {
                for (index, name) in files.enumerated() {
                    try handle.write(contentsOf: try await vault.read(item.folder + "/" + name))
                    phase = .loading(done: index + 1, total: files.count)
                }
                try handle.close()
            } catch {
                try? handle.close()
                try? FileManager.default.removeItem(at: part)
                throw error
            }
            try? FileManager.default.removeItem(at: file)
            try FileManager.default.moveItem(at: part, to: file)
            phase = .ready(file)
        } catch {
            phase = .failed
        }
    }
}

// MARK: - Views

/// The Videos form of News: one card per interview, newest first.
struct VideosSection: View {
    @State private var feed = VideoFeed.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if feed.items.isEmpty {
                StateView(phase: feed.failed ? .failed(String(localized: "The videos could not be loaded.", bundle: .module)) : .loading,
                          hasData: false, title: String(localized: "the videos", bundle: .module)) { Task { await feed.load() } }
            }
            ForEach(feed.items) { item in
                NavigationLink { VideoScreen(item: item) } label: { VideoCard(item: item) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pt.video.\(item.id)")
            }
        }
        .task { await feed.load() }
    }
}

/// A card: the poster with a play mark, the title and who is in it.
private struct VideoCard: View {
    let item: VideoItem
    @State private var loader: VideoLoader

    init(item: VideoItem) {
        self.item = item
        _loader = State(initialValue: VideoLoader.loader(item))
    }

    var body: some View {
        Card {
            PosterView(image: loader.poster)
            Text(item.title).font(Typo.headline).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
            Text(VideoScreen.byline(item)).font(Typo.meta).foregroundStyle(Palette.muted)
        }
        .task { await loader.loadPoster() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Plays the video", bundle: .module))
    }
}

private struct PosterView: View {
    let image: UIImage?
    var symbol = "play.fill"

    var body: some View {
        ZStack {
            Rectangle().fill(Palette.ink)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Palette.ink)
                .frame(width: 56, height: 56)
                .background(Palette.card, in: Circle())
                .accessibilityHidden(true)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Space.radius - 6, style: .continuous))
    }
}

/// One video: the player, then the title, who and when, and the interview's page.
struct VideoScreen: View {
    let item: VideoItem
    @State private var loader: VideoLoader
    @State private var player: AVPlayer?
    @State private var part: Part = .article
    @State private var articles = ArticleStore.shared
    @Namespace private var pill

    /// The two pills under the video: the article about the interview, and the transcript of the video.
    enum Part: CaseIterable { case article, transcript }

    init(item: VideoItem) {
        self.item = item
        _loader = State(initialValue: VideoLoader.loader(item))
    }

    static func byline(_ item: VideoItem) -> String {
        [item.person, item.company].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                stage
                Text(item.title).font(Typo.title).foregroundStyle(Palette.ink)
                Text(Self.byline(item)).font(Typo.data).foregroundStyle(Palette.muted)
                pills
                Group {
                    switch part {
                    case .article: articlePart.transition(.push(from: .leading))
                    case .transcript: transcriptPart.transition(.push(from: .trailing))
                    }
                }
                // Slide left for the transcript, right for the article.
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                    withAnimation(.snappy) {
                        if drag.translation.width < -60 { part = .transcript }
                        if drag.translation.width > 60 { part = .article }
                    }
                })
                Link(destination: item.pageURL) {
                    Label(String(localized: "Read the interview on promptugal.news", bundle: .module), systemImage: "arrow.up.right.square")
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(Space.l)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(String(localized: "Video", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loader.loadPoster() }
        .task { if let twin = ArticleTwin.twinURL(for: item.pageURL) { await articles.load(twin) } }
        .task(id: part) { if part == .transcript { await loader.loadTranscript() } }
        .sensoryFeedback(.selection, trigger: part)
        .onChange(of: loader.phase) { _, phase in
            if case .ready(let url) = phase, player == nil { start(url) }
        }
        .onDisappear { player?.pause() }
    }

    private func label(_ part: Part) -> String {
        switch part {
        case .article: String(localized: "Article", bundle: .module)
        case .transcript: String(localized: "Transcript", bundle: .module)
        }
    }

    /// Two pills; the chosen one is filled, and the fill slides between them.
    private var pills: some View {
        HStack(spacing: 4) {
            ForEach(Part.allCases, id: \.self) { candidate in
                Button {
                    withAnimation(.snappy) { part = candidate }
                } label: {
                    Text(label(candidate))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(part == candidate ? Palette.paper : Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if part == candidate {
                                Capsule().fill(Palette.ink).matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(part == candidate ? .isSelected : [])
                .accessibilityIdentifier("pt.video.\(candidate == .article ? "article" : "transcript")")
            }
        }
        .padding(4)
        .background(Palette.paper2, in: Capsule())
    }

    @ViewBuilder private var articlePart: some View {
        if let twin = ArticleTwin.twinURL(for: item.pageURL), let article = articles.articles[twin] {
            VStack(alignment: .leading, spacing: Space.m) {
                if let summary = article.summary { Text(summary).font(.title3).foregroundStyle(Palette.muted) }
                ArticleBody(blocks: article.blocks, base: item.pageURL)
            }
        } else if let summary = item.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                Text(summary).font(Typo.body).foregroundStyle(Palette.ink)
                ProgressView()
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var transcriptPart: some View {
        if let turns = loader.transcript {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("A machine transcript of the video: some words may be wrong.", bundle: .module)
                    .font(.footnote).foregroundStyle(Palette.muted)
                ForEach(turns) { turn in
                    VStack(alignment: .leading, spacing: 2) {
                        if let speaker = turn.speaker {
                            Text(speaker).font(.footnote.weight(.semibold)).foregroundStyle(Palette.red)
                        }
                        Text(turn.text).font(.body).foregroundStyle(Palette.ink).textSelection(.enabled)
                    }
                }
            }
        } else if loader.transcriptFailed {
            Text("The transcript could not be loaded.", bundle: .module).font(.footnote).foregroundStyle(Palette.muted)
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var stage: some View {
        if let player {
            VideoPlayer(player: player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Space.radius - 6, style: .continuous))
        } else {
            ZStack {
                PosterView(image: loader.poster, symbol: "play.fill")
                    .opacity(isLoading ? 0.35 : 1)
                switch loader.phase {
                case .loading(let done, let total):
                    VStack(spacing: Space.s) {
                        ProgressView(value: Double(done), total: Double(max(total, 1))).tint(Palette.card).frame(maxWidth: 220)
                        Text("Loading the video: \(VideoRules.percent(done, total))%", bundle: .module)
                            .font(Typo.data).foregroundStyle(Palette.card)
                    }
                case .failed:
                    VStack(spacing: Space.s) {
                        Text("The video could not be loaded. Check your connection and try again.", bundle: .module)
                            .font(.footnote).foregroundStyle(Palette.card).multilineTextAlignment(.center)
                        Button(String(localized: "Try again", bundle: .module)) { Task { await loader.load() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(Space.l)
                case .idle, .ready:
                    EmptyView()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { play() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("Play the video", bundle: .module))
            .accessibilityIdentifier("pt.video.play")
        }
    }

    private var isLoading: Bool {
        if case .loading = loader.phase { return true }
        return false
    }

    private func play() {
        if case .ready(let url) = loader.phase {
            start(url)
        } else {
            Task { await loader.load() }
        }
    }

    private func start(_ url: URL) {
        // Sound even with the ring switch on silent, as a video app should.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        let made = AVPlayer(url: url)
        player = made
        made.play()
    }
}
