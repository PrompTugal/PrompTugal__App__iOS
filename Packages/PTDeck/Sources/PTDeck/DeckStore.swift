import Foundation
import Observation

/// What the deck screens read. Holds the catalog, the language choice and the loaded decks.
@MainActor @Observable
public final class DeckStore {
    public enum Phase: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    public let source: any DeckSource
    public let imageCache: DeckDiskCache
    public let fetch: DeckFetch

    public private(set) var catalog: DeckCatalog?
    public private(set) var phase: Phase = .idle
    /// The language the person chose. Decks without it fall back (English first).
    public var language: DeckLanguage

    public init(source: any DeckSource = DeckSources.published(),
                language: DeckLanguage = .deviceDefault(),
                imageCache: DeckDiskCache = .standard(),
                fetch: @escaping DeckFetch = DeckFetchers.live) {
        self.source = source
        self.language = language
        self.imageCache = imageCache
        self.fetch = fetch
    }

    public func loadCatalog() async {
        if catalog == nil { phase = .loading }
        do {
            catalog = try await source.catalog()
            phase = .loaded
        } catch is CancellationError {
            // Leave the phase as it was.
        } catch {
            phase = catalog == nil ? .failed(error.localizedDescription) : .loaded
        }
    }

    /// The deck in the chosen language, or the closest one the deck has.
    public func loadDeck(_ summary: DeckSummary) async throws -> Deck {
        try await source.deck(id: summary.id, preferring: language, available: summary.languages)
    }
}
