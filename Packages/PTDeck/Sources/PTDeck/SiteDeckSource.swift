import Foundation

public enum DeckSources {
    public static let siteBase = URL(string: "https://promptugal.news")!

    /// The default loader: published JSON when the site has it, else the site's pages, kept on disk for
    /// offline reading.
    public static func published(cache: DeckDiskCache = .standard(), fetch: @escaping DeckFetch = DeckFetchers.live) -> CachedDeckSource {
        CachedDeckSource(
            source: FallbackDeckSource(primary: HTTPDeckSource(fetch: fetch), secondary: SiteDeckSource(fetch: fetch)),
            cache: cache)
    }
}

/// Reads the investor decks from the pages the site publishes today, until it publishes deck JSON.
///
/// - The list comes from `investors/decks/index.html` (and `investors/<lang>/decks/index.html`).
/// - A deck's text comes from the page's Markdown twin (`.../index.md`, every `##` is a slide); its images
///   come from the page's `<section class="slide">` blocks, in the same order.
/// - The pages carry no speaker notes, so `notes` is nil.
public struct SiteDeckSource: DeckSource {
    public let base: URL
    public let fetch: DeckFetch

    public init(base: URL = DeckSources.siteBase, fetch: @escaping DeckFetch = DeckFetchers.live) {
        self.base = base
        self.fetch = fetch
    }

    static func indexPath(_ language: DeckLanguage) -> String {
        language == .en ? "investors/decks/index.html" : "investors/\(language.rawValue)/decks/index.html"
    }

    static func deckPath(_ id: String, _ language: DeckLanguage, file: String) -> String {
        language == .en ? "investors/decks/\(id)/\(file)" : "investors/decks/\(id)/\(language.rawValue)/\(file)"
    }

    public func catalog() async throws -> DeckCatalog {
        var byID: [String: DeckSummary] = [:]
        var order: [String] = []
        var failure: Error?
        for language in DeckLanguage.allCases {
            let location = base.appendingPathComponent(Self.indexPath(language))
            do {
                let html = String(decoding: try await fetch(location), as: UTF8.self)
                for entry in SiteDeckParser.listEntries(html: html) {
                    if byID[entry.id] == nil {
                        order.append(entry.id)
                        byID[entry.id] = DeckSummary(id: entry.id, number: entry.number, title: LocalizedText([:]),
                                                     summary: LocalizedText([:]), cover: nil, languages: [])
                    }
                    byID[entry.id]?.title.values[language.rawValue] = entry.title
                    byID[entry.id]?.summary.values[language.rawValue] = entry.summary
                    byID[entry.id]?.languages.append(language)
                    if language == .en || byID[entry.id]?.cover == nil {
                        byID[entry.id]?.cover = base.appendingPathComponent("board/team/investors/site/img/covers/\(entry.id).\(language.rawValue).jpg")
                    }
                }
            } catch {
                if error is CancellationError { throw error }
                // One missing language index must not hide the others; only fail when none loaded.
                failure = failure ?? error
            }
        }
        let decks = order.compactMap { byID[$0] }
        if decks.isEmpty { throw failure ?? DeckError.notFound("deck list") }
        return DeckCatalog(version: nil, decks: decks)
    }

    public func deck(id: String, language: DeckLanguage) async throws -> Deck {
        let markdown = base.appendingPathComponent(Self.deckPath(id, language, file: "index.md"))
        let page = base.appendingPathComponent(Self.deckPath(id, language, file: "index.html"))
        let text = String(decoding: try await fetch(markdown), as: UTF8.self)
        guard var parsed = SiteDeckParser.deck(markdown: text, id: id, language: language) else {
            throw DeckError.badData("\(id).\(language.rawValue)")
        }
        // Images are a bonus: a deck without them is still a deck.
        if let html = try? await fetch(page) {
            let images = SiteDeckParser.slideImages(html: String(decoding: html, as: UTF8.self), pageURL: page)
            if images.count == parsed.slides.count {
                parsed = Deck(id: parsed.id, language: parsed.language, title: parsed.title, summary: parsed.summary,
                              slides: zip(parsed.slides, images).map { slide, image in
                                  var s = slide
                                  s.image = image
                                  return s
                              }, version: parsed.version)
            }
        }
        return parsed
    }
}

/// Parsers for the site's pages. Pure functions, tested with fixtures.
public enum SiteDeckParser {
    public struct ListEntry: Equatable, Sendable {
        public var id: String
        public var number: String?
        public var title: String
        public var summary: String
    }

    /// `<p class="dc-n">1</p><h3><a href=".../decks/<id>/index.html">Title</a></h3><p>Summary</p>`
    public static func listEntries(html: String) -> [ListEntry] {
        let pattern = #"<p class="dc-n">([^<]*)</p>\s*<h3><a href="[^"]*/decks/([^/"]+)/index\.html">(.*?)</a></h3>\s*<p>(.*?)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).map { match in
            let number = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            return ListEntry(id: ns.substring(with: match.range(at: 2)),
                             number: number.isEmpty ? nil : number,
                             title: plain(ns.substring(with: match.range(at: 3))),
                             summary: plain(ns.substring(with: match.range(at: 4))))
        }
    }

    /// A deck page's Markdown twin: `# Title`, `> summary`, a `---` line, then one `##` per slide. A `###`
    /// line inside a slide becomes a bold line. The "Download the PDF" link line is dropped.
    public static func deck(markdown: String, id: String, language: DeckLanguage) -> Deck? {
        var title = ""
        var summary = ""
        var slides: [(title: String, lines: [String])] = []
        var started = false
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !started {
                if line.hasPrefix("# "), title.isEmpty { title = String(line.dropFirst(2)) }
                else if line.hasPrefix("> "), summary.isEmpty { summary = String(line.dropFirst(2)) }
                else if line == "---" { started = true }
                continue
            }
            if line.hasPrefix("## ") {
                slides.append((String(line.dropFirst(3)), []))
            } else if slides.isEmpty {
                continue
            } else if line.hasPrefix("### ") {
                slides[slides.count - 1].lines.append("**\(line.dropFirst(4))**")
            } else if line.hasPrefix("[Download the PDF]") || line.hasPrefix("[") && line.contains("](") && line.hasSuffix(".pdf)") {
                continue
            } else {
                slides[slides.count - 1].lines.append(line)
            }
        }
        guard !slides.isEmpty else { return nil }
        let built = slides.map { slide -> DeckSlide in
            let body = slide.lines.joined(separator: "\n")
                .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return DeckSlide(title: slide.title, body: body)
        }
        return Deck(id: id, language: language, title: title.isEmpty ? id : title, summary: summary, slides: built)
    }

    /// The first image of each `<section class="slide">`, resolved against the page, or nil. One entry per
    /// slide, in order.
    public static func slideImages(html: String, pageURL: URL) -> [URL?] {
        let parts = html.components(separatedBy: "<section class=\"slide")
        guard parts.count > 1 else { return [] }
        let regex = try? NSRegularExpression(pattern: #"<img[^>]*\ssrc="([^"]+)""#, options: [])
        return parts.dropFirst().map { part in
            let slide = part.components(separatedBy: "</section>").first ?? part
            let ns = slide as NSString
            guard let match = regex?.firstMatch(in: slide, range: NSRange(location: 0, length: ns.length)) else { return nil }
            return URL(string: ns.substring(with: match.range(at: 1)), relativeTo: pageURL)?.absoluteURL
        }
    }

    static func plain(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
