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
    /// The kinds the screen offers (segments and search groups). The app can leave Talks out.
    public var kinds: [ExploreKind] = ExploreKind.browsable

    public init(source: any ExploreSource = PublishedExploreSource()) {
        self.source = source
    }

    /// The newsroom's Explore: stories, companies, places and the library, from the newsroom's own sites.
    public static func newsroom(source: any ExploreSource = NewsroomExploreSource()) -> ExploreStore {
        let store = ExploreStore(source: source)
        store.kinds = ExploreKind.newsroom
        store.kind = .article
        return store
    }

    /// The Lisbon summit 2026 index (the people, organisations and companies in promptugal.news's search index),
    /// kept behind one row now that the summit is over.
    public static func summit(source: any ExploreSource = PublishedExploreSource()) -> ExploreStore {
        let store = ExploreStore(source: source)
        store.kinds = [.person, .organisation, .company]
        store.kind = .person
        return store
    }

    public func load() async {
        if index == nil { phase = .loading }
        do {
            index = try await source.index()
            phase = .loaded
            if !shownKinds.contains(kind), let first = shownKinds.first { kind = first }
        } catch is CancellationError {
        } catch {
            phase = index == nil ? .failed(error.localizedDescription) : .loaded
        }
    }

    /// Where the entries came from: live, this device's copy or the built-in copy.
    public var origin: ExploreOrigin? { index?.origin }

    /// The kinds that have entries (all of `kinds` until the index is read): no empty segment.
    public var shownKinds: [ExploreKind] {
        guard let index else { return kinds }
        let present = Set(index.items.map(\.kind))
        let shown = kinds.filter { present.contains($0) }
        return shown.isEmpty ? kinds : shown
    }

    /// Search across the shown kinds, grouped, at most `limit` per group.
    public func grouped(limit: Int = 30) -> [(kind: ExploreKind, items: [ExploreItem])] {
        guard let index else { return [] }
        return shownKinds.compactMap { kind in
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
