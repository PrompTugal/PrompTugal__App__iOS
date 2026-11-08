import Foundation
import Observation
import PTCore

/// Every lane operation, for Debug: what was sent where, sizes, the server's answer. Never a token in full,
/// never a key, never the message text (only its size and subject).
public struct LaneEvent: Identifiable, Sendable, Hashable {
    enum Kind: String, Sendable { case encrypt, write, list, fetch, decrypt, markProcessed, vaultNote, error }
    public let id: UUID
    let at: Date
    let kind: Kind
    /// e.g. "Newsroom tips · vault y9j3nc60 · token 0158…bb75"
    let lane: String
    let bytes: Int
    let durationMs: Double
    let status: Int?
    let detail: String
}

@MainActor @Observable
public final class LanesLog {
    public static let shared = LanesLog()
    let capacity: Int
    public private(set) var events: [LaneEvent] = []

    init(capacity: Int = 500) { self.capacity = capacity }

    func add(_ kind: LaneEvent.Kind, lane: String, bytes: Int = 0, ms: Double = 0, status: Int? = nil, detail: String) {
        events.insert(LaneEvent(id: UUID(), at: .now, kind: kind, lane: lane, bytes: bytes, durationMs: ms,
                                status: status, detail: detail), at: 0)
        if events.count > capacity { events.removeLast(events.count - capacity) }
    }

    func clear() { events.removeAll() }

    /// "0158…bb75": enough to tell lanes apart.
    nonisolated static func shortToken(_ token: String) -> String {
        token.count > 8 ? "\(token.prefix(4))…\(token.suffix(4))" : "…"
    }

    nonisolated static func describe(_ address: LaneAddress) -> String {
        "\(address.name) · vault \(address.vault) · token \(shortToken(address.token))"
    }
}
