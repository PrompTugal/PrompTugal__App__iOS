import Foundation

/// A small disk cache for deck data and slide images, so decks read offline. One file per key.
public struct DeckDiskCache: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/PTDeck` (not purgeable, unlike Caches, because the decks are for offline use).
    public static func standard() -> DeckDiskCache {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return DeckDiskCache(directory: base.appendingPathComponent("PTDeck", isDirectory: true))
    }

    func file(for key: String) -> URL {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? String($0) : "_" }.joined()
        return directory.appendingPathComponent(String(safe.prefix(180)))
    }

    public func store(_ data: Data, key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file(for: key), options: .atomic)
        } catch {
            // A full disk or a missing directory must not break reading. The next fetch tries again.
        }
    }

    public func load(key: String) -> Data? {
        try? Data(contentsOf: file(for: key))
    }

    public func has(key: String) -> Bool {
        FileManager.default.fileExists(atPath: file(for: key).path)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// Wraps a source: asks it first, keeps what it returns on disk, and answers from disk when it fails
/// (offline, server down). Throws the source's error only when the disk has nothing either.
public struct CachedDeckSource: DeckSource {
    public let source: any DeckSource
    public let cache: DeckDiskCache

    public init(source: any DeckSource, cache: DeckDiskCache) {
        self.source = source
        self.cache = cache
    }

    static let catalogKey = "catalog.json"
    static func deckKey(_ id: String, _ language: DeckLanguage) -> String { "deck.\(id).\(language.rawValue).json" }

    public func catalog() async throws -> DeckCatalog {
        do {
            let fresh = try await source.catalog()
            if let data = try? JSONEncoder().encode(fresh) { cache.store(data, key: Self.catalogKey) }
            return fresh
        } catch {
            if error is CancellationError { throw error }
            if let data = cache.load(key: Self.catalogKey), let cached = try? JSONDecoder().decode(DeckCatalog.self, from: data) {
                return cached
            }
            throw error
        }
    }

    public func deck(id: String, language: DeckLanguage) async throws -> Deck {
        let key = Self.deckKey(id, language)
        do {
            let fresh = try await source.deck(id: id, language: language)
            if let data = try? JSONEncoder().encode(fresh) { cache.store(data, key: key) }
            return fresh
        } catch {
            if error is CancellationError { throw error }
            if let data = cache.load(key: key), let cached = try? JSONDecoder().decode(Deck.self, from: data) {
                return cached
            }
            throw error
        }
    }

    /// Languages of a deck that are on disk, for showing "available offline".
    public func cachedLanguages(of id: String) -> [DeckLanguage] {
        DeckLanguage.allCases.filter { cache.has(key: Self.deckKey(id, $0)) }
    }
}
