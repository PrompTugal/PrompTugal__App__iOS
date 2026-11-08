import Foundation
import PTCore
import PTWeb

/// The schedule's state on this device: the picks, and the removals the app remembers so that a stale copy
/// elsewhere cannot bring a removed pick back.
///
/// The website keeps no removals: its merge (`fromVault` in schedule.js) is a plain union by id, keeping its own
/// copy of a pick. The app keeps the same union and adds two rules, so removals made anywhere survive a sync:
///
/// 1. **A removal wins only if it is later than the pick** (contracts §3). A removal is remembered for 30 days.
/// 2. **A source that dropped a pick since the last sync removed it.** For the web view, the app remembers which
///    ids the page held after the last sync (the baseline). An id in the baseline that the page no longer holds was
///    removed on the page, unless the app picked it again after that sync.
public struct ScheduleState: Codable, Equatable, Sendable {
    public init(picks: [String: Date] = [:], removed: [String: Date] = [:]) {
        self.picks = picks
        self.removed = removed
    }

    public var picks: [String: Date] = [:]
    public var removed: [String: Date] = [:]

    public var document: ScheduleDocument {
        ScheduleDocument(picks: picks
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value }
            .map { ScheduleDocument.WirePick(id: $0.key, at: $0.value) })
    }
}

/// What a source held after the last sync with it.
public struct ScheduleBaseline: Codable, Equatable, Sendable {
    public init(ids: Set<String>, at: Date) {
        self.ids = ids
        self.at = at
    }

    public var ids: Set<String>
    public var at: Date
}

public enum ScheduleMerge {
    public static let removalMemory: TimeInterval = 30 * 24 * 3600

    public struct Outcome: Equatable, Sendable {
        public init(state: ScheduleState, added: Set<String> = [], removed: Set<String> = []) {
            self.state = state
            self.added = added
            self.removed = removed
        }

        public var state: ScheduleState
        public var added: Set<String> = []
        public var removed: Set<String> = []
        public var changed: Bool { !added.isEmpty || !removed.isEmpty }
    }

    /// Merges a document from a page or a vault into the local state.
    /// - Parameters:
    ///   - baseline: what this source held after the last sync, or nil for a source with no memory (a vault copy).
    ///   - now: the time a removal detected on the source is stamped with.
    public static func merge(_ incoming: ScheduleDocument, into local: ScheduleState,
                      baseline: ScheduleBaseline? = nil, now: Date = .now) -> Outcome {
        var state = local
        var outcome = Outcome(state: local)
        let theirs = Dictionary(incoming.picks.map { ($0.id, $0.at) }, uniquingKeysWith: { min($0, $1) })

        for (id, pickedAt) in theirs {
            if state.picks[id] != nil { continue }                         // the union keeps our copy, as the website does
            if let removedAt = state.removed[id], removedAt >= pickedAt { continue }   // the removal is later: it wins
            state.picks[id] = pickedAt
            state.removed[id] = nil
            outcome.added.insert(id)
        }

        if let baseline {
            for id in baseline.ids where theirs[id] == nil {
                guard let pickedAt = state.picks[id] else { continue }
                if pickedAt > baseline.at { continue }                     // picked again here after the last sync
                state.picks[id] = nil
                state.removed[id] = max(now, pickedAt)
                outcome.removed.insert(id)
            }
        }

        outcome.state = pruned(state, now: now)
        return outcome
    }

    public static func toggle(_ id: String, in local: ScheduleState, now: Date = .now) -> ScheduleState {
        var state = local
        if let pickedAt = state.picks[id] {
            state.picks[id] = nil
            state.removed[id] = max(now, pickedAt)
        } else {
            state.picks[id] = now
            state.removed[id] = nil
        }
        return pruned(state, now: now)
    }

    public static func pruned(_ state: ScheduleState, now: Date) -> ScheduleState {
        var state = state
        state.removed = state.removed.filter { now.timeIntervalSince($0.value) < removalMemory }
        return state
    }
}
