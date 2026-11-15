import Foundation
import Observation
import PTLanes

/// The lane this device sends to: the conductor's. Pasted in the app; nothing is built in.
/// A lane link is public by design (a vault id, a write-only token, a public key), so it lives in UserDefaults.
@MainActor @Observable
public final class TalkLanes {
    public static let shared = TalkLanes()

    static let conductorKey = "talk.lane.conductor"
    private let defaults: UserDefaults

    public private(set) var conductorLink: String

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        conductorLink = defaults.string(forKey: Self.conductorKey) ?? ""
    }

    public var conductor: SealedLane? { SealedLane.parse(conductorLink) }

    /// Keeps the link only if it holds a valid `sgi1.` lane; an empty text forgets it. True when kept or forgotten.
    @discardableResult
    public func setConductor(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || SealedLane.parse(trimmed) != nil else { return false }
        conductorLink = trimmed
        defaults.set(trimmed, forKey: Self.conductorKey)
        return true
    }

    public func forgetAll() { setConductor("") }
}

/// What this device sent, kept on this device only (Application Support, complete
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

    private struct Saved: Codable {
        var records: [Record] = []
    }

    public private(set) var records: [Record] = []
    private let file: URL?

    public init(file: URL? = TalkHistory.defaultFile()) {
        self.file = file
        if let file, let data = try? Data(contentsOf: file), let saved = try? JSONDecoder.talk.decode(Saved.self, from: data) {
            records = saved.records
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

    public func clear() {
        records = []
        save()
    }

    private func save() {
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder.talk.encode(Saved(records: records)) {
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
public enum TalkApp {
    public static var line: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "PrompTugal iOS \(version) (\(build))"
    }
}
