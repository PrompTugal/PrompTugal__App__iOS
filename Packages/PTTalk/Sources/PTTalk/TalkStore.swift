import Foundation
import Observation
import Security
import PTLanes

/// The lane this device sends to: the conductor's. Scanned (QR) or pasted in the app; nothing is built in. Kept in
/// the Keychain (this device only): a lane link is public by design, but whoever holds it can write to the lane.
@MainActor @Observable
public final class TalkLanes {
    public static let shared = TalkLanes()

    private let store: TalkLinkStore
    public private(set) var conductorLink: String

    public init(store: TalkLinkStore = KeychainLinkStore()) {
        self.store = store
        conductorLink = store.load() ?? ""
    }

    public var conductor: SealedLane? { SealedLane.parse(conductorLink) }

    /// Keeps the link only if it holds a valid `sgi1.` lane; an empty text forgets it. True when kept or forgotten.
    @discardableResult
    public func setConductor(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty || SealedLane.parse(trimmed) != nil else { return false }
        if trimmed.isEmpty { store.delete() } else { store.save(trimmed) }
        conductorLink = trimmed
        return true
    }

    public func forgetAll() { setConductor("") }
}

/// Where the lane link lives: the Keychain in the app, memory in tests.
public protocol TalkLinkStore: Sendable {
    func load() -> String?
    func save(_ link: String)
    func delete()
}

public struct KeychainLinkStore: TalkLinkStore {
    let service: String
    public init(service: String = "news.promptugal.reader.talk.lane") { self.service = service }

    private var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "conductor"]
    }

    public func load() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ link: String) {
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(link.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    public func delete() { SecItemDelete(base as CFDictionary) }
}

public final class MemoryLinkStore: TalkLinkStore, @unchecked Sendable {
    private var link: String?
    private let lock = NSLock()
    public init(_ link: String? = nil) { self.link = link }
    public func load() -> String? { lock.lock(); defer { lock.unlock() }; return link }
    public func save(_ link: String) { lock.lock(); self.link = link; lock.unlock() }
    public func delete() { lock.lock(); link = nil; lock.unlock() }
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
