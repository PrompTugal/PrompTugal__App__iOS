import Foundation
import Observation

/// Every request the design screens make, for the Network debug panel.
///
/// Contract §8 puts the app-wide log in the platform session's `HTTPClient`
/// (`PrompTugal/App/HTTPClient.swift`). Until it lands, the feeds here log
/// into this one; when it lands, the Network panel shows both.
@MainActor @Observable
final class RequestLog {
    static let shared = RequestLog()

    struct Entry: Identifiable, Sendable {
        enum Outcome: Sendable, Equatable { case ok, cached, failed(String) }

        let id = UUID()
        let at: Date
        let method: String
        let url: URL
        let status: Int?
        let bytes: Int
        let durationMs: Double
        let outcome: Outcome
        let source: String

        var host: String { url.host ?? "" }
        var isFailure: Bool { if case .failed = outcome { true } else { false } }
    }

    private(set) var entries: [Entry] = []
    let cap = 2_000

    func record(_ entry: Entry) {
        entries.insert(entry, at: 0)
        if entries.count > cap { entries.removeLast(entries.count - cap) }
    }

    func clear() { entries.removeAll() }

    var totalBytes: Int { entries.reduce(0) { $0 + $1.bytes } }
}
