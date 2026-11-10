import PTCore
import PTWeb
import SwiftUI

// Native articles (news app redesign, at Indi's word, 10 November 2026: an article opens in the app, not as a web page
// that reloads). Every page on promptugal.news has a markdown twin generated from the same content (`x.html` -> `x.md`,
// `dir/` -> `dir/index.md`). The app reads the twin and draws it with SwiftUI. A page with no twin opens on the web.

/// One block of a twin, parsed without touching the network, so the tests can check it.
enum ArticleBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case quote(String)
    case image(alt: String, url: String)
    case rule
}

struct ParsedArticle: Equatable {
    var title: String
    var summary: String?
    var blocks: [ArticleBlock]
}

enum ArticleTwin {
    /// The twin of a page on promptugal.news, or nil for anything else.
    static func twinURL(for url: URL) -> URL? {
        guard url.scheme == "https", url.host() == FeedClient.site.host() else { return nil }
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.fragment = nil
        parts?.query = nil
        guard var path = parts?.path, !path.hasSuffix(".md") else { return nil }
        if path.hasSuffix(".html") {
            path = String(path.dropLast(5)) + ".md"
        } else if path.hasSuffix("/") {
            path += "index.md"
        } else {
            return nil
        }
        parts?.path = path
        return parts?.url
    }

    /// The twin's text as blocks. The header the site adds (title, summary, source line, rule) becomes the title and
    /// summary; the rest is the article.
    static func parse(_ text: String) -> ParsedArticle {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var title = ""
        var summary: String?
        // The header: "# Title", "> summary", "*Source: ...*", "---".
        if let i = lines.firstIndex(where: { $0.hasPrefix("# ") }), i < 3 {
            title = String(lines[i].dropFirst(2))
            if let rule = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }), rule < 12 {
                let head = lines[(i + 1)..<rule]
                summary = head.first(where: { $0.hasPrefix("> ") }).map { String($0.dropFirst(2)) }
                lines = Array(lines[(rule + 1)...])
            } else {
                lines.remove(at: i)
            }
        }
        var blocks: [ArticleBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var quote: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: " "))); quote = [] }
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("#") {
                flush()
                let level = line.prefix(while: { $0 == "#" }).count
                var text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                // "## Title {#anchor}": drop the anchor.
                if let brace = text.range(of: " {#") { text = String(text[..<brace.lowerBound]) }
                blocks.append(.heading(level: min(level, 4), text: text))
            } else if line == "---" || line == "***" {
                flush(); blocks.append(.rule)
            } else if line.hasPrefix("!["), let close = line.range(of: "]("), line.hasSuffix(")") {
                flush()
                let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<close.lowerBound])
                let src = String(line[close.upperBound..<line.index(before: line.endIndex)])
                blocks.append(.image(alt: alt, url: src))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !paragraph.isEmpty || !numbered.isEmpty || !quote.isEmpty { flush() }
                bullets.append(String(line.dropFirst(2)))
            } else if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty,
                      line[line.index(after: dot)...].hasPrefix(" ") {
                if !paragraph.isEmpty || !bullets.isEmpty || !quote.isEmpty { flush() }
                numbered.append(String(line[line.index(dot, offsetBy: 2)...]))
            } else if line.hasPrefix(">") {
                if !paragraph.isEmpty || !bullets.isEmpty || !numbered.isEmpty { flush() }
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix(":::") || line.hasPrefix("{.") {
                // The site's layout markers: not words.
                flush()
            } else {
                if !bullets.isEmpty || !numbered.isEmpty || !quote.isEmpty { flush() }
                paragraph.append(line)
            }
        }
        flush()
        return ParsedArticle(title: title, summary: summary, blocks: blocks)
    }
}

/// Loads and keeps twins for this run.
@MainActor @Observable
final class ArticleStore {
    static let shared = ArticleStore()
    private(set) var articles: [URL: ParsedArticle] = [:]
    private(set) var failed: Set<URL> = []

    func load(_ twin: URL) async {
        guard articles[twin] == nil else { return }
        failed.remove(twin)
        do {
            let (data, response) = try await URLSession.shared.data(from: twin)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let text = String(data: data, encoding: .utf8) else {
                throw URLError(.badServerResponse)
            }
            articles[twin] = ArticleTwin.parse(text)
        } catch {
            failed.insert(twin)
        }
    }
}

/// Opens a page natively when it has a twin, else on the web. Use it wherever the app opened `WebPage` for the site.
public struct SitePage: View {
    let url: URL
    let title: String

    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }

    public var body: some View {
        if ArticleTwin.twinURL(for: url) != nil {
            ArticleReader(url: url, title: title)
        } else {
            WebPage(url: url, title: title)
        }
    }
}

/// The article screen: the title, the summary, then the article, all native.
struct ArticleReader: View {
    let url: URL
    let title: String
    @State private var store = ArticleStore.shared
    @State private var linked: LinkedArticle?

    private var twin: URL? { ArticleTwin.twinURL(for: url) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let twin, let article = store.articles[twin] {
                    Text(article.title.isEmpty ? title : article.title)
                        .font(Typo.storyDisplay).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    if let summary = article.summary {
                        Text(summary).font(.title3).foregroundStyle(Palette.muted)
                    }
                    ArticleBody(blocks: article.blocks, base: url)
                } else if let twin, store.failed.contains(twin) {
                    StateView(phase: .failed(String(localized: "The article could not be loaded.", bundle: .module)), hasData: false,
                              title: String(localized: "the article", bundle: .module)) { Task { await store.load(twin) } }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, Space.xxl)
                }
                Link(destination: url) {
                    Label(String(localized: "Open on promptugal.news", bundle: .module), systemImage: "safari")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.top, Space.l)
            }
            .padding(Space.l)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { ShareLink(item: url) }
        }
        .task { if let twin { await store.load(twin) } }
        // A link to another page of the site opens natively too, over this one.
        .environment(\.openURL, OpenURLAction { target in
            if ArticleTwin.twinURL(for: target) != nil {
                linked = LinkedArticle(url: target)
                return .handled
            }
            return .systemAction
        })
        .sheet(item: $linked) { item in
            NavigationStack {
                ArticleReader(url: item.url, title: "PrompTugal.news")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Done", bundle: .module)) { linked = nil }
                        }
                    }
            }
        }
    }
}

private struct LinkedArticle: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// The blocks, drawn. Links inside the text are tappable; relative links resolve against the page.
struct ArticleBody: View {
    let blocks: [ArticleBlock]
    let base: URL

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(block)
            }
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: text, options: options, baseURL: base) {
            return Text(attributed)
        }
        return Text(verbatim: text)
    }

    @ViewBuilder private func view(_ block: ArticleBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(level <= 2 ? Typo.storyTitle : Typo.story)
                .foregroundStyle(Palette.ink)
                .padding(.top, level <= 2 ? Space.m : Space.s)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            inline(text).font(.body).foregroundStyle(Palette.ink).lineSpacing(3)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: Space.s) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Circle().fill(Palette.red).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                            .accessibilityHidden(true)
                        inline(item).font(.body).foregroundStyle(Palette.ink)
                    }
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: Space.s) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text("\(index + 1).").font(.body.weight(.semibold).monospacedDigit()).foregroundStyle(Palette.red)
                        inline(item).font(.body).foregroundStyle(Palette.ink)
                    }
                }
            }
        case .quote(let text):
            inline(text).font(.body.italic()).foregroundStyle(Palette.ink)
                .padding(Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.paper2, in: RoundedRectangle(cornerRadius: Space.radius - 8, style: .continuous))
        case .image(let alt, let src):
            if let url = URL(string: src, relativeTo: base)?.absoluteURL, url.scheme == "https" {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: Space.radius - 8).fill(Palette.paper2).frame(height: 160)
                }
                .clipShape(RoundedRectangle(cornerRadius: Space.radius - 8, style: .continuous))
                .accessibilityLabel(Text(alt))
            }
        case .rule:
            Divider()
        }
    }
}
