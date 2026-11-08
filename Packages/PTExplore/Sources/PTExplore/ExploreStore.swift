import Foundation
import Observation

/// What the Explore screens read.
@MainActor @Observable
public final class ExploreStore {
    public enum Phase: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    public let source: any ExploreSource
    public private(set) var index: ExploreIndex?
    public private(set) var phase: Phase = .idle
    public var query = ""
    public var kind: ExploreKind = .event

    public init(source: any ExploreSource = PublishedExploreSource()) {
        self.source = source
    }

    public func load() async {
        if index == nil { phase = .loading }
        do {
            index = try await source.index()
            phase = .loaded
        } catch is CancellationError {
        } catch {
            phase = index == nil ? .failed(error.localizedDescription) : .loaded
        }
    }

    public var results: [ExploreItem] {
        guard let index else { return [] }
        return ExploreSearch.search(index, query: query, kind: kind)
    }
}
