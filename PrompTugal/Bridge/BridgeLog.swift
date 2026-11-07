import Foundation
import Observation

/// Every message across the bridge, newest first, for the Debug panel (contracts §8). Holds op names, hosts,
/// counts and outcomes, never page data or keys.
@MainActor @Observable
final class BridgeLog {
    struct Entry: Identifiable, Sendable, Hashable {
        enum Direction: String, Sendable { case pageToApp = "page → app", appToPage = "app → page", app = "app" }
        enum Outcome: String, Sendable { case ok, refused, failed }

        let id = UUID()
        let at: Date
        let host: String
        let direction: Direction
        let op: String
        let detail: String
        let outcome: Outcome
        let durationMs: Double?
    }

    static let capacity = 1_000
    private(set) var entries: [Entry] = []
    private(set) var counts: [String: Int] = [:]     // by op, since launch

    func record(host: String, _ direction: Entry.Direction, op: String, detail: String = "",
                outcome: Entry.Outcome = .ok, durationMs: Double? = nil) {
        entries.insert(Entry(at: .now, host: host, direction: direction, op: op, detail: detail,
                             outcome: outcome, durationMs: durationMs), at: 0)
        if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
        counts[op, default: 0] += 1
    }

    func clear() {
        entries.removeAll()
        counts.removeAll()
    }
}
