import Foundation
import PTCore

/// Where decks come from. Injected, so the app can plug in its own loader (PTSync later) and tests can use
/// a fake. Implementations throw when they cannot answer.
public protocol DeckSource: Sendable {
    func catalog() async throws -> DeckCatalog
    func deck(id: String, language: DeckLanguage) async throws -> Deck
}

public enum DeckError: Error, Equatable, LocalizedError {
    case notFound(String)
    case badData(String)
    case noLanguage(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let what): "Not found: \(what)."
        case .badData(let what): "The deck data could not be read: \(what)."
        case .noLanguage(let id): "The deck \(id) has no languages."
        }
    }
}

public extension DeckSource {
    /// Loads a deck in the preferred language and falls back (English, then the others) when that language
    /// is missing or fails. Returns the deck it got; `deck.language` says which language that was.
    func deck(id: String, preferring language: DeckLanguage, available: [DeckLanguage]) async throws -> Deck {
        let order = DeckLanguage.chain(language, available: available)
        guard !order.isEmpty else { throw DeckError.noLanguage(id) }
        var firstError: Error?
        for candidate in order {
            do { return try await deck(id: id, language: candidate) } catch {
                if error is CancellationError { throw error }
                firstError = firstError ?? error
            }
        }
        throw firstError ?? DeckError.notFound(id)
    }
}

/// Tries `primary`, and `secondary` when the primary fails. Used to prefer published deck JSON and fall back
/// to the site's pages.
public struct FallbackDeckSource: DeckSource {
    public let primary: any DeckSource
    public let secondary: any DeckSource

    public init(primary: any DeckSource, secondary: any DeckSource) {
        self.primary = primary
        self.secondary = secondary
    }

    public func catalog() async throws -> DeckCatalog {
        do { return try await primary.catalog() } catch {
            if error is CancellationError { throw error }
            return try await secondary.catalog()
        }
    }

    public func deck(id: String, language: DeckLanguage) async throws -> Deck {
        do { return try await primary.deck(id: id, language: language) } catch {
            if error is CancellationError { throw error }
            return try await secondary.deck(id: id, language: language)
        }
    }
}

/// Fetches bytes from a URL. The default goes through PTCore's `HTTPClient`, so Debug → Network sees it.
public typealias DeckFetch = @Sendable (URL) async throws -> Data

public enum DeckFetchers {
    public static let live: DeckFetch = { url in
        try await HTTPClient.shared.get(url, timeout: 20, label: "decks", maxBytes: 4 * 1024 * 1024)
    }
}
