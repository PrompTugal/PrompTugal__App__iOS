import Foundation
import Observation
import PTCore

/// Every message across the bridge, newest first, for the Debug panel (contracts §8). Holds op names, hosts,
/// counts and outcomes, never page data or keys.
@MainActor @Observable
public final class BridgeLog {
    public init(entries: [Entry] = [], counts: [String: Int] = [:]) {
        self.entries = entries
        self.counts = counts
    }

    public struct Entry: Identifiable, Sendable, Hashable {
        public init(at: Date, host: String, direction: Direction, op: String, detail: String, outcome: Outcome, durationMs: Double?) {
            self.at = at
            self.host = host
            self.direction = direction
            self.op = op
            self.detail = detail
            self.outcome = outcome
            self.durationMs = durationMs
        }

        public enum Direction: String, Sendable { case pageToApp = "page → app", appToPage = "app → page", app = "app" }
        public enum Outcome: String, Sendable { case ok, refused, failed }

        public let id = UUID()
        public let at: Date
        public let host: String
        public let direction: Direction
        public let op: String
        public let detail: String
        public let outcome: Outcome
        public let durationMs: Double?
    }

    public static let capacity = 1_000
    public private(set) var entries: [Entry] = []
    public private(set) var counts: [String: Int] = [:]     // by op, since launch

    public func record(host: String, _ direction: Entry.Direction, op: String, detail: String = "",
                outcome: Entry.Outcome = .ok, durationMs: Double? = nil) {
        entries.insert(Entry(at: .now, host: host, direction: direction, op: op, detail: detail,
                             outcome: outcome, durationMs: durationMs), at: 0)
        if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
        counts[op, default: 0] += 1
    }

    public func clear() {
        entries.removeAll()
        counts.removeAll()
    }
}
