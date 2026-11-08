import PTCore
import PTWeb
import SwiftUI

/// The news in every form: the feed, the newsletter editions (read natively from their
/// plain-text email), the stories in progress, and the graph. Each has its web twin.
public struct NewsHomeView: View {
    @Environment(NewsFeeds.self) private var data
    @Environment(\.newsSource) private var source
    @SceneStorage("news.form") private var form: Form = .feed

    private var store: any NewsSource { source ?? EmptyNewsSource.shared }

    public init() {}

    enum Form: String, CaseIterable, Identifiable {
        case feed = "Feed", editions = "Editions", stories = "Stories"
        var id: Self { self }
    }

    public var body: some View {
        Page(maxWidth: 900) {
            ScreenHeader(kicker: "PrompTugal.news", title: "The news",
                         summary: "Independent coverage from Lisbon, in every form: the feed, the editions, the stories being made, and the graph.")
            Picker("Form", selection: $form) {
                ForEach(Form.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch form {
            case .feed: feed
            case .editions: editions
            case .stories: stories
            }
            NavigationLink { GraphExplorerView() } label: {
                Card {
                    HStack(spacing: Space.m) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.title).foregroundStyle(Palette.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The graph").font(Typo.headline).foregroundStyle(Palette.ink)
                            Text("Every company, event, person and source, and how they connect. Drawn natively.")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        KindBadge(kind: .native)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("News")
        .refreshable {
            await store.refresh()
            await data.refresh(force: true)
        }
        .task {
            await store.refresh()
            await data.newsletter.load()
            await data.board.load()
        }
        .webTwin(twinURL, title: form.rawValue)
    }

    private var twinURL: URL {
        switch form {
        case .feed: FeedClient.articleIndex
        case .editions: FeedClient.site.appendingPathComponent("newsletter/")
        case .stories: FeedClient.site.appendingPathComponent("newsroom/stories/")
        }
    }

    // MARK: Feed

    @ViewBuilder private var feed: some View {
        FreshnessLabel(updated: store.newsUpdated, failed: store.newsUnavailable)
        if store.news.isEmpty {
            StateView(phase: store.newsUnavailable ? .failed("The feed could not be reached.") : .loading,
                      hasData: false, title: "news") { Task { await store.refresh() } }
        }
        if let lead = store.news.first {
            NavigationLink { WebPage(url: lead.url, title: "Story") } label: {
                Card(padding: Space.xl) {
                    if !lead.category.isEmpty { Kicker(lead.category) }
                    Text(lead.title).font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(Palette.ink)
                    if !lead.summary.isEmpty { Text(lead.summary).font(.body).foregroundStyle(Palette.muted) }
                    if let published = lead.published {
                        Text(published, format: .dateTime.weekday(.wide).day().month(.wide)).font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Space.m)], spacing: Space.m) {
            ForEach(store.news.dropFirst()) { story in
                NavigationLink { WebPage(url: story.url, title: "Story") } label: {
                    Card {
                        if !story.category.isEmpty { Kicker(story.category) }
                        Text(story.title).font(Typo.headline).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                        if !story.summary.isEmpty {
                            Text(story.summary).font(.footnote).foregroundStyle(Palette.muted).lineLimit(3)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Editions

    @ViewBuilder private var editions: some View {
        let list = data.newsletter.value?.editions ?? []
        FreshnessLabel(updated: data.newsletter.updated, failed: data.newsletter.failed)
        if list.isEmpty {
            StateView(phase: data.newsletter.phase, hasData: false, title: "newsletter") {
                Task { await data.newsletter.load(force: true) }
            }
        }
        ForEach(list) { edition in
            NavigationLink { EditionReader(edition: edition) } label: {
                Card {
                    HStack {
                        Kicker(edition.edition ?? "edition", color: edition.edition == "evening" ? Palette.blue : Palette.red)
                        Spacer()
                        if edition.authored == false {
                            Text("assembled from data").font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    Text(edition.title ?? "Edition").font(Typo.title).foregroundStyle(Palette.ink)
                    if let summary = edition.summary { Text(summary).font(.subheadline).foregroundStyle(Palette.muted) }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Stories

    @ViewBuilder private var stories: some View {
        if let board = data.board.value {
            let columns = board.columns ?? []
            ForEach(columns) { column in
                let items = (board.stories ?? []).filter { $0.column == column.id }
                if !items.isEmpty {
                    TitledCard(column.name ?? column.id, kicker: "\(items.count) stories") {
                        ForEach(items) { story in
                            if let url = story.url {
                                NavigationLink { WebPage(url: url, title: "Story") } label: {
                                    NewsRow(title: story.title ?? story.id, detail: story.next, symbol: "doc.text",
                                            tint: Palette.stable(column.id))
                                }
                                .buttonStyle(.plain)
                            } else {
                                NewsRow(title: story.title ?? story.id, detail: story.next, symbol: "doc.text")
                            }
                        }
                    }
                }
            }
        } else {
            StateView(phase: data.board.phase, hasData: false, title: "stories") { Task { await data.board.load(force: true) } }
        }
    }
}

/// A newsletter edition, read natively from its plain-text email: headings, bullets and links.
struct EditionReader: View {
    let edition: Wire.Edition
    @State private var blocks: [TextBlock] = []
    @State private var failed = false

    var body: some View {
        Page(maxWidth: Space.readable) {
            Kicker(edition.edition ?? "Edition")
            Text(edition.title ?? "").font(Typo.display)
            if failed {
                GapNote(title: "This edition could not be loaded", text: "Open it on the web with the button at the top.")
            } else if blocks.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(blocks) { block in
                switch block.kind {
                case .heading:
                    Text(block.text).font(Typo.title).padding(.top, Space.s).accessibilityAddTraits(.isHeader)
                case .bullet:
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Circle().fill(Palette.red).frame(width: 5, height: 5).accessibilityHidden(true)
                        Text(block.attributed).font(.body)
                    }
                case .paragraph:
                    Text(block.attributed).font(.body)
                }
            }
        }
        .navigationTitle("Edition")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .webTwin(edition.pageURL ?? FeedClient.site, title: "Edition")
    }

    private func load() async {
        guard blocks.isEmpty, let url = edition.emailURL else { failed = edition.emailURL == nil; return }
        do {
            let data = try await HTTPClient.shared.get(url, label: "news.edition")
            blocks = TextBlock.parse(String(decoding: data, as: UTF8.self))
        } catch {
            failed = true
        }
    }
}

/// One block of a plain-text edition.
struct TextBlock: Identifiable, Sendable {
    enum Kind: Sendable { case heading, bullet, paragraph }
    let id: Int
    let kind: Kind
    let text: String

    /// "Name (https://…)" becomes a link on "Name".
    var attributed: AttributedString {
        let markdown = text.replacingOccurrences(of: #"([^()\n]+?) \((https://[^)\s]+)\)"#, with: "[$1]($2)",
                                                 options: .regularExpression)
        return (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    static func parse(_ text: String) -> [TextBlock] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [TextBlock] = []
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty {
                blocks.append(TextBlock(id: blocks.count, kind: .paragraph, text: paragraph.joined(separator: " ")))
                paragraph = []
            }
        }
        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            let next = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : ""
            if !line.isEmpty, !next.isEmpty, next.allSatisfy({ $0 == "=" || $0 == "-" }) {
                flush()
                // The edition's own title (underlined with =) is shown above, so skip it.
                if !next.hasPrefix("=") { blocks.append(TextBlock(id: blocks.count, kind: .heading, text: line)) }
                index += 2
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                blocks.append(TextBlock(id: blocks.count, kind: .bullet, text: String(line.dropFirst(2))))
            } else if line.isEmpty {
                flush()
            } else {
                paragraph.append(line)
            }
            index += 1
        }
        flush()
        return blocks
    }
}

#Preview("Edition text") {
    let sample = """
    Morning edition
    ===============
    What is on today.

    If you are there
    ----------------
    - 09:30 Registration (https://promptugal.news/events/registration/) · Airport
    """
    return Page { ForEach(TextBlock.parse(sample)) { Text($0.attributed) } }
}
