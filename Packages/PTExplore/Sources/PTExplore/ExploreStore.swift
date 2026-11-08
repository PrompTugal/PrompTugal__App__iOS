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

    /// Search across Talks, Speakers, Companies and Places, grouped, at most `limit` per group.
    public func grouped(limit: Int = 30) -> [(kind: ExploreKind, items: [ExploreItem])] {
        guard let index else { return [] }
        return ExploreKind.browsable.compactMap { kind in
            let hits = ExploreSearch.search(index, query: query, kind: kind)
            return hits.isEmpty ? nil : (kind, Array(hits.prefix(limit)))
        }
    }

    public var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// People, companies and places A to Z, grouped by first letter (accents folded; digits and symbols under "#").
    public static func letterSections(_ items: [ExploreItem]) -> [(letter: String, items: [ExploreItem])] {
        func letter(_ item: ExploreItem) -> String {
            guard let first = ExploreSearch.normalise(item.title).first(where: { !$0.isWhitespace }), first.isLetter else { return "#" }
            return String(first).uppercased()
        }
        let sorted = items.sorted { ExploreSearch.normalise($0.title) < ExploreSearch.normalise($1.title) }
        var groups: [(letter: String, items: [ExploreItem])] = []
        for item in sorted {
            let l = letter(item)
            if let i = groups.firstIndex(where: { $0.letter == l }) { groups[i].items.append(item) }
            else { groups.append((l, [item])) }
        }
        return groups.sorted { a, b in a.letter == "#" ? false : (b.letter == "#" ? true : a.letter < b.letter) }
    }

    public var results: [ExploreItem] {
        guard let index else { return [] }
        return ExploreSearch.search(index, query: query, kind: kind)
    }
}
