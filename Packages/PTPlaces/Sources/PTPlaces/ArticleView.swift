import PTCore
import SwiftUI

/// Loads one article's record, signature, twin, the keys and the provenance, and checks the signature.
@MainActor @Observable
final class ArticleReader {
    let id: String
    let record: RemoteFeed<ArticleRecord>
    let signature: RemoteFeed<ArticleSignature>
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
        signature = RemoteFeed(name: "article.\(id).sig", url: ArticleLinks.signature(id))
        record.freshFor = 600
        signature.freshFor = 600
    }

    func load(force: Bool = false) async {
        async let a: Void = record.load(force: force)
        async let b: Void = signature.load(force: force)
        async let c: Void = Self.keys.load(force: force)
        async let d: Void = Self.provenance.load(force: force)
        _ = await (a, b, c, d)
        await verify()
    }

    private func verify() async {
        guard let sig = signature.value else {
            check = .notChecked(String(localized: "the signature file did not load"))
            return
        }
        guard let keys = Self.keys.value else {
            check = .notChecked(String(localized: "the published keys did not load"))
            return
        }
        let twinURL = record.value.flatMap { URL(string: $0.twin) } ?? ArticleLinks.twin(id)
        do {
            var request = URLRequest(url: twinURL, timeoutInterval: 20)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await HTTPClient.shared.data(for: request, label: "article.twin")
            guard (200..<300).contains(response.statusCode), let text = String(data: data, encoding: .utf8) else {
                check = .notChecked(String(localized: "the signed text did not load"))
                return
            }
            let keyList = keys.keys
            check = await Task.detached(priority: .userInitiated) {
                ArticleSigning.check(twin: text, signature: sig, keys: keyList)
            }.value
        } catch {
            check = .notChecked(String(localized: "the signed text did not load"))
        }
    }
}

/// One of PrompTugal.news's own articles, read in the app: title, date, author, summary, every source as a link,
/// the full page, the signature checked on this phone, and how it was made.
public struct ArticleView: View {
    let id: String
    @State private var reader: ArticleReader
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.openURL) private var openURL

    public init(id: String) {
        self.id = id
        _reader = State(initialValue: ArticleReader(id: id))
    }

    private var wide: Bool { width == .regular }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                if let record = reader.record.value {
                    header(record)
                    fullPage(record)
                    sources(record)
                    SignaturePanel(check: reader.check)
                    made
                } else if reader.record.failed {
                    ContentUnavailableView {
                        Label(String(localized: "The article did not load"), systemImage: "wifi.exclamationmark")
                    } actions: {
                        Button(String(localized: "Open it on promptugal.news")) { openURL(ArticleLinks.page(id)) }
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
        .navigationTitle(String(localized: "Article"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ArticleLinks.page(id))
            }
        }
        .refreshable { await reader.load(force: true) }
        .task { await reader.load() }
        .accessibilityIdentifier("article.\(id)")
    }

    // MARK: Parts

    private func header(_ record: ArticleRecord) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Kicker(text: String(localized: "Our article"), color: Palette.red)
            Text(record.title)
                .font(.system(size: wide ? 40 : 28, weight: .black, design: .serif))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text([PlaceDates.short(record.date), record.author].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
            PlacesOriginLabel(origin: reader.record.origin(dataDate: nil))
            if !record.summary.isEmpty {
                Text(record.summary)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Palette.ink.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.s)
            }
        }
    }

    private func fullPage(_ record: ArticleRecord) -> some View {
        Button {
            openURL(URL(string: record.page) ?? ArticleLinks.page(id))
        } label: {
            Label(String(localized: "Read the full article on promptugal.news"), systemImage: "safari")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.red)
    }

    @ViewBuilder private func sources(_ record: ArticleRecord) -> some View {
        if !record.sources.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                SectionHead(title: String(localized: "Sources"),
                            subtitle: String(localized: "Every source the article cites, as published"), accent: Palette.red)
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
                SectionHead(title: String(localized: "How this was made"), accent: Palette.red)
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
                    Text(source.text)
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

    var body: some View {
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
        .padding(Space.l)
        .background(Palette.paper2, in: RoundedRectangle(cornerRadius: Space.radius))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("article.signature")
    }

    private var title: String {
        switch check {
        case .checking: String(localized: "Checking the signature on this phone")
        case .verified(let agent, _): String(localized: "Signed by \(agent), checked on this phone")
        case .failed: String(localized: "Signature does not match")
        case .notChecked: String(localized: "Signature not checked")
        }
    }

    private var detail: String? {
        switch check {
        case .checking: nil
        case .verified(_, let keyID): String(localized: "Key \(keyID), published in promptugal.news/board/keys.json")
        case .failed(let reason), .notChecked(let reason): reason.prefix(1).uppercased() + reason.dropFirst()
        }
    }

    private var symbol: String {
        switch check {
        case .verified: "checkmark.seal.fill"
        case .failed: "xmark.seal.fill"
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
