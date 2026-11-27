import PTCore
import SwiftUI

/// Loads one article's record, signature, twin, the keys and the provenance, and checks the signature.
@MainActor @Observable
final class ArticleReader {
    let id: String
    let record: RemoteFeed<ArticleRecord>
    private(set) var check: SignatureCheck = .checking

    /// Shared across articles: the keys file is large and changes rarely; provenance covers every article.
    static let keys: RemoteFeed<SigningKeys> = {
        let feed = RemoteFeed<SigningKeys>(name: "articles.keys", url: ArticleLinks.keys)
        feed.freshFor = 3_600
        return feed
    }()
    static let provenance: RemoteFeed<ArticleProvenanceFile> = {
        let feed = RemoteFeed<ArticleProvenanceFile>(name: "articles.provenance", url: ArticleLinks.provenance)
        feed.freshFor = 600
        return feed
    }()

    init(id: String) {
        self.id = id
        record = RemoteFeed(name: "article.\(id)", url: ArticleLinks.record(id))
        record.freshFor = 600
    }

    func load(force: Bool = false) async {
        async let a: Void = record.load(force: force)
        async let c: Void = Self.keys.load(force: force)
        async let d: Void = Self.provenance.load(force: force)
        _ = await (a, c, d)
        await verify()
    }

    /// The bytes at a URL and its status code; nil when it could not be reached.
    private func fetch(_ url: URL) async -> (Data, Int)? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await HTTPClient.shared.data(for: request, label: "article.signature") else { return nil }
        return (data, response.statusCode)
    }

    private func verify() async {
        if record.value?.status == "withdrawn" {
            check = .notChecked(String(localized: "the article has been withdrawn", bundle: .module))
            return
        }
        let sigURL = record.value.flatMap { URL(string: $0.signature) } ?? ArticleLinks.signature(id)
        guard let fetched = await fetch(sigURL) else {
            check = .notChecked(String(localized: "the signature file did not load", bundle: .module))
            return
        }
        let (sigData, sigStatus) = fetched
        if sigStatus == 404 {
            check = .notSigned
            return
        }
        guard (200..<300).contains(sigStatus), let sig = try? JSONDecoder().decode(ArticleSignature.self, from: sigData) else {
            check = .notChecked(String(localized: "the signature file could not be read", bundle: .module))
            return
        }
        guard let keys = Self.keys.value else {
            check = .notChecked(String(localized: "the published keys did not load", bundle: .module))
            return
        }
        let twinURL = record.value.flatMap { URL(string: $0.twin) } ?? ArticleLinks.twin(id)
        guard let twin = await fetch(twinURL), (200..<300).contains(twin.1),
              let text = String(data: twin.0, encoding: .utf8) else {
            check = .notChecked(String(localized: "the signed text did not load", bundle: .module))
            return
        }
        let keyList = keys.keys
        check = await Task.detached(priority: .userInitiated) {
            ArticleSigning.check(twin: text, signature: sig, keys: keyList)
        }.value
    }
}

/// One of PrompTugal.news's own articles, read in the app: title, date, author, summary, every source as a link,
/// the full page, the signature checked on this phone, and how it was made.
public struct ArticleView: View {
    let id: String
    @State private var reader: ArticleReader
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.openURL) private var openURL
    @Environment(\.placesOfflineData) private var offlineData

    /// The article from the offline edition, when the network gave nothing.
    private var offlineRecord: ArticleRecord? {
        PlacesOffline.shared.value(ArticleRecord.self, PlacesOffline.Path.article(id))
    }

    public init(id: String) {
        self.id = id
        _reader = State(initialValue: ArticleReader(id: id))
    }

    private var wide: Bool { width == .regular }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let record = reader.record.value ?? offlineRecord {
                    header(record)
                    fullPage(record)
                    sources(record)
                    SignaturePanel(check: reader.check, id: id)
                    made
                } else if reader.record.failed {
                    ContentUnavailableView {
                        Label(String(localized: "The article did not load", bundle: .module), systemImage: "wifi.exclamationmark")
                    } actions: {
                        Button(String(localized: "Open it on promptugal.news", bundle: .module)) { openURL(ArticleLinks.page(id)) }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(.horizontal, wide ? Space.xxl : Space.l)
            .padding(.vertical, Space.l)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .navigationTitle(String(localized: "Article", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ArticleLinks.page(id))
            }
        }
        .refreshable { await reader.load(force: true) }
        .task {
            PlacesOffline.shared.use(offlineData)
            await reader.load()
            if let record = reader.record.value ?? offlineRecord {
                await PlacesTranslation.shared.load([record.title, record.summary])
            }
        }
        .accessibilityIdentifier("article.\(id)")
    }

    // MARK: Parts

    private func header(_ record: ArticleRecord) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Kicker(text: String(localized: "Our article", bundle: .module), color: Palette.red)
            PlacesTranslation.shared.content(record.title)
                .font(.system(wide ? .largeTitle : .title, design: .serif, weight: .black))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text([PlaceDates.short(record.date), record.author].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
            PlacesOriginLabel(origin: reader.record.value == nil ? PlacesOffline.origin(dataDate: record.date) : reader.record.origin(dataDate: nil))
            languageNote(record)
            if !record.summary.isEmpty {
                PlacesTranslation.shared.content(record.summary)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Palette.ink.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.s)
            }
        }
    }

    /// In Portuguese: the site's translation of the title and summary (from its memory, marked as machine
    /// translation, English one tap away) when there is one, else "O artigo está em inglês".
    @ViewBuilder private func languageNote(_ record: ArticleRecord) -> some View {
        if PlacesLanguage.isPortuguese {
            let translation = PlacesTranslation.shared
            if let entry = translation.entry(record.title) ?? translation.entry(record.summary) {
                TranslationNote(entry: entry)
            } else {
                Label(String(localized: "This article is in English", bundle: .module), systemImage: "character.bubble")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func fullPage(_ record: ArticleRecord) -> some View {
        Button {
            openURL(URL(string: record.page) ?? ArticleLinks.page(id))
        } label: {
            Label(String(localized: "Read the full article on promptugal.news", bundle: .module), systemImage: "safari")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.red)
    }

    @ViewBuilder private func sources(_ record: ArticleRecord) -> some View {
        if !record.sources.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "Sources", bundle: .module),
                            subtitle: String(localized: "Every source the article cites, as published", bundle: .module), accent: Palette.red)
                ForEach(record.sources, id: \.self) { source in
                    SourceRow(source: source)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder private var made: some View {
        let file = ArticleReader.provenance.value
        if let entry = file?.entry(for: id), !entry.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "How this was made", bundle: .module), accent: Palette.red)
                if !entry.level.isEmpty {
                    let name = entry.levelName.isEmpty ? (file?.ladder[entry.level] ?? "") : entry.levelName
                    Text("\(entry.level) · \(name)").font(.headline).foregroundStyle(Palette.ink)
                }
                ForEach([entry.type, entry.origin, entry.research].filter { !$0.isEmpty }, id: \.self) { line in
                    Label(line, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Palette.ink)
                }
                if let ladder = file?.ladder, !ladder.isEmpty {
                    Text(ladder.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
                PlacesOriginLabel(origin: ArticleReader.provenance.origin(dataDate: nil))
            }
        }
    }
}

/// A cited source: its host and what the article takes from it; a tap opens it.
struct SourceRow: View {
    let source: ArticleSource
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: source.url) { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label(source.host, systemImage: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.red)
                if !source.text.isEmpty {
                    Text(english: source.text)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, Space.s)
        }
        .buttonStyle(.plain)
    }
}

/// The signature, said as it is: checked on this phone, failed, or not checked and why.
struct SignaturePanel: View {
    let check: SignatureCheck
    let id: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            verdict
            // The trust limit, said plainly (spec s. 2).
            Text(String(localized: "The key list comes from the same site as the article: a good signature shows the text was signed with the key listed under that agent's name on promptugal.news, not who holds the key.", bundle: .module))
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.m) {
                link(String(localized: "Signed text", bundle: .module), ArticleLinks.twin(id))
                link(String(localized: "Signature", bundle: .module), ArticleLinks.signature(id))
                link(String(localized: "Keys", bundle: .module), ArticleLinks.keys)
            }
        }
        .padding(Space.l)
        .background(Palette.paper2, in: RoundedRectangle(cornerRadius: Space.radius))
        .accessibilityIdentifier("article.signature")
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button(title) { openURL(url) }
            .font(.caption.weight(.semibold))
            .tint(Palette.red)
    }

    private var verdict: some View {
        HStack(alignment: .top, spacing: Space.m) {
            if check == .checking {
                ProgressView()
            } else {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                if let detail { Text(detail).font(.footnote).foregroundStyle(Palette.muted) }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch check {
        case .checking: String(localized: "Checking the signature on this device", bundle: .module)
        case .verified(let agent, _, false): String(localized: "Signed by \(agent), checked on this device", bundle: .module)
        case .verified(let agent, _, true): String(localized: "Signed with an earlier key of \(agent), still valid, checked on this device", bundle: .module)
        case .failed: String(localized: "The signature does not match this text", bundle: .module)
        case .olderForm: String(localized: "Signed in an older form that cannot be checked", bundle: .module)
        case .notSigned: String(localized: "Not signed", bundle: .module)
        case .notChecked: String(localized: "Signature not checked", bundle: .module)
        }
    }

    private var detail: String? {
        switch check {
        case .checking, .failed, .olderForm, .notSigned: nil
        case .verified(_, let keyID, _): String(localized: "Key \(keyID), from promptugal.news/board/keys.json", bundle: .module)
        case .notChecked(let reason): reason.prefix(1).uppercased() + reason.dropFirst()
        }
    }

    private var symbol: String {
        switch check {
        case .verified: "checkmark.seal.fill"
        case .failed: "xmark.seal.fill"
        case .notSigned: "seal"
        default: "seal"
        }
    }

    private var color: Color {
        switch check {
        case .verified: Palette.green
        case .failed: Palette.red
        default: Palette.amber
        }
    }
}

/// Opens a story: one of our articles in the reader (ArticleView), anything else at its source. Needs an
/// `ArticleRoute` destination in the stack (PortugalHomeView and PlacesHomeView register one).
struct StoryOpen<Content: View>: View {
    let link: String
    var onOpen: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let id = ArticleLinks.id(from: link) {
            NavigationLink(value: ArticleRoute(id)) { content() }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { onOpen?() })
        } else {
            Button {
                onOpen?()
                if let url = URL(string: link) { openURL(url) }
            } label: {
                content()
            }
            .buttonStyle(.plain)
        }
    }
}
