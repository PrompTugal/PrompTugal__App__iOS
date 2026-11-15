import Foundation
import Observation
import PTLanes
import PTLocal

/// The lanes this device sends to: the conductor's, and any town agent's. Pasted in the app; nothing is built in.
/// A lane link is public by design (a vault id, a write-only token, a public key), so it lives in UserDefaults.
@MainActor @Observable
public final class TalkLanes {
    public static let shared = TalkLanes()

    static let conductorKey = "talk.lane.conductor"
    static let agentsKey = "talk.lane.agents"
    private let defaults: UserDefaults

    public private(set) var conductorLink: String
    public private(set) var agentLinks: [String: String]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        conductorLink = defaults.string(forKey: Self.conductorKey) ?? ""
        agentLinks = (defaults.dictionary(forKey: Self.agentsKey) as? [String: String]) ?? [:]
    }

    public var conductor: SealedLane? { SealedLane.parse(conductorLink) }
    public func agent(_ town: String) -> SealedLane? { agentLinks[town].flatMap(SealedLane.parse) }

    /// Keeps the link only if it holds a valid `sgi1.` lane; an empty text forgets it. True when kept or forgotten.
    @discardableResult
    public func setConductor(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || SealedLane.parse(trimmed) != nil else { return false }
        conductorLink = trimmed
        defaults.set(trimmed, forKey: Self.conductorKey)
        return true
    }

    @discardableResult
    public func setAgent(_ town: String, link text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || SealedLane.parse(trimmed) != nil else { return false }
        if trimmed.isEmpty { agentLinks[town] = nil } else { agentLinks[town] = trimmed }
        defaults.set(agentLinks, forKey: Self.agentsKey)
        return true
    }

    public func forgetAll() {
        setConductor("")
        agentLinks = [:]
        defaults.removeObject(forKey: Self.agentsKey)
    }
}

/// What this device sent, and each town conversation, kept on this device only (Application Support, complete
/// file protection). Text only: pictures, videos and recordings are not kept after sending.
@MainActor @Observable
public final class TalkHistory {
    public static let shared = TalkHistory()

    public struct Record: Codable, Identifiable, Hashable, Sendable {
        public enum Status: String, Codable, Sendable { case sent, failed, kept }
        public var id: String
        public var purpose: TalkWire.Purpose
        public var town: String?
        public var text: String
        public var files: [String]
        public var status: Status
        public var at: Date
    }

    public struct Line: Codable, Identifiable, Hashable, Sendable {
        public enum Role: String, Codable, Sendable {
            /// What the owner wrote.
            case me
            /// Answered by Apple Intelligence on this device from the town's published data.
            case onDevice
            /// A note from the app (no lane yet, model unavailable).
            case note
        }
        public var id: UUID = UUID()
        public var role: Role
        public var text: String
        public var at: Date = .now
        /// For `me`: sealed to the agent's lane, kept here (no lane), or failed.
        public var delivery: Record.Status?
        /// For `onDevice`: which data it read ("live", "this device's copy", "built-in copy").
        public var source: String?
    }

    private struct Saved: Codable {
        var records: [Record] = []
        var conversations: [String: [Line]] = [:]
    }

    public private(set) var records: [Record] = []
    public private(set) var conversations: [String: [Line]] = [:]
    private let file: URL?

    public init(file: URL? = TalkHistory.defaultFile()) {
        self.file = file
        if let file, let data = try? Data(contentsOf: file), let saved = try? JSONDecoder.talk.decode(Saved.self, from: data) {
            records = saved.records
            conversations = saved.conversations
        }
    }

    public nonisolated static func defaultFile() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("talk", isDirectory: true).appendingPathComponent("history.json")
    }

    public func add(_ record: Record) {
        records.insert(record, at: 0)
        if records.count > 200 { records.removeLast(records.count - 200) }
        save()
    }

    public func records(_ purpose: TalkWire.Purpose) -> [Record] { records.filter { $0.purpose == purpose } }

    public func lines(_ town: String) -> [Line] { conversations[town] ?? [] }

    @discardableResult
    public func append(_ line: Line, to town: String) -> UUID {
        conversations[town, default: []].append(line)
        if let count = conversations[town]?.count, count > 300 { conversations[town]?.removeFirst(count - 300) }
        save()
        return line.id
    }

    public func update(_ id: UUID, in town: String, _ change: (inout Line) -> Void) {
        guard let index = conversations[town]?.firstIndex(where: { $0.id == id }) else { return }
        change(&conversations[town]![index])
        save()
    }

    public func clear() {
        records = []
        conversations = [:]
        save()
    }

    private func save() {
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder.talk.encode(Saved(records: records, conversations: conversations)) {
            try? data.write(to: file, options: [.atomic, .completeFileProtection])
        }
    }
}

extension JSONDecoder {
    static var talk: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var talk: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

/// A short "PrompTugal iOS 0.4.106 (512)" for the header's `app` field.
enum TalkApp {
    static var line: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "PrompTugal iOS \(version) (\(build))"
    }
}
