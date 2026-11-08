import Foundation

/// Reads published deck JSON over HTTPS:
///
///     <base>/api/v1/decks/index.json        → DeckCatalog
///     <base>/api/v1/decks/<id>.<lang>.json  → Deck
///
/// Relative image and cover paths in the data are resolved against the file's own URL. The site does not
/// publish this format yet; until it does, `SiteDeckSource` reads the pages (see `DeckSources.published`).
public struct HTTPDeckSource: DeckSource {
    public let base: URL
    public let fetch: DeckFetch

    public init(base: URL = DeckSources.siteBase, fetch: @escaping DeckFetch = DeckFetchers.live) {
        self.base = base
        self.fetch = fetch
    }

    func url(_ path: String) -> URL { base.appendingPathComponent(path) }

    public func catalog() async throws -> DeckCatalog {
        let location = url("api/v1/decks/index.json")
        var catalog = try decode(DeckCatalog.self, try await fetch(location), what: "index.json")
        catalog.decks = catalog.decks.map { summary in
            var s = summary
            s.cover = summary.cover.flatMap { Self.resolve($0, against: location) }
            return s
        }
        return catalog
    }

    public func deck(id: String, language: DeckLanguage) async throws -> Deck {
        let location = url("api/v1/decks/\(id).\(language.rawValue).json")
        var deck = try decode(Deck.self, try await fetch(location), what: "\(id).\(language.rawValue).json")
        deck = Deck(id: deck.id, language: deck.language, title: deck.title, summary: deck.summary,
                    slides: deck.slides.map { slide in
                        var s = slide
                        s.image = slide.image.flatMap { Self.resolve($0, against: location) }
                        return s
                    }, version: deck.version)
        return deck
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data, what: String) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) } catch { throw DeckError.badData(what) }
    }

    /// `URL(string:)` keeps a relative path relative. Make it absolute against the file it came from.
    static func resolve(_ url: URL, against base: URL) -> URL? {
        url.scheme == nil ? URL(string: url.relativeString, relativeTo: base)?.absoluteURL : url
    }
}
