import CommonCrypto
import Foundation
import Observation
import Security

/// Owner-only: everything in PTTalk is hidden until this device is unlocked with a passphrase the owner sets on
/// first use. Messages to agents can carry instructions, so a stranger with the phone must not be able to send them
/// (prompt injection). The passphrase itself is never stored: the Keychain holds a random salt and a PBKDF2-SHA256
/// hash, on this device only. Unlocking lasts until the app goes to the background or the owner locks it.
@MainActor @Observable
public final class OwnerLock {
    public static let shared = OwnerLock()

    public private(set) var isSet: Bool
    public private(set) var isUnlocked = false
    public private(set) var failures = 0
    public private(set) var waitUntil: Date?

    nonisolated static let service = "news.promptugal.reader.talk.owner"
    nonisolated static let account = "passphrase"
    nonisolated static let rounds: UInt32 = 210_000
    public nonisolated static let minimumLength = 8

    private let store: OwnerSecretStore

    public init(store: OwnerSecretStore = KeychainOwnerStore()) {
        self.store = store
        isSet = store.load() != nil
    }

    public enum Failure: Error, Equatable, LocalizedError {
        case tooShort, mismatch, wrong, wait(Int), keychain(Int32)
        public var errorDescription: String? {
            switch self {
            case .tooShort: "Use at least \(OwnerLock.minimumLength) characters."
            case .mismatch: "The two passphrases are not the same."
            case .wrong: "That is not the passphrase."
            case .wait(let seconds): "Too many tries. Wait \(seconds) seconds."
            case .keychain(let status): "The Keychain refused it (\(status))."
            }
        }
    }

    /// First use: sets the passphrase and unlocks.
    public func set(_ passphrase: String, confirm: String) throws {
        guard passphrase.count >= Self.minimumLength else { throw Failure.tooShort }
        guard passphrase == confirm else { throw Failure.mismatch }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw Failure.keychain(status) }
        let record = Self.record(salt: salt, hash: Self.derive(passphrase, salt: salt, rounds: Self.rounds), rounds: Self.rounds)
        let saved = store.save(record)
        guard saved == errSecSuccess else { throw Failure.keychain(saved) }
        isSet = true
        isUnlocked = true
        failures = 0
    }

    public func unlock(_ passphrase: String, now: Date = .now) throws {
        if let waitUntil, waitUntil > now { throw Failure.wait(Int(waitUntil.timeIntervalSince(now).rounded(.up))) }
        guard let record = store.load(), let parsed = Self.parse(record) else { isSet = false; throw Failure.wrong }
        let hash = Self.derive(passphrase, salt: parsed.salt, rounds: parsed.rounds)
        guard Self.constantTimeEqual(hash, parsed.hash) else {
            failures += 1
            if failures >= 5 { waitUntil = now.addingTimeInterval(Double(min(300, 30 * (failures - 4)))) }
            throw Failure.wrong
        }
        failures = 0
        waitUntil = nil
        isUnlocked = true
    }

    public func lock() { isUnlocked = false }

    /// Forgets the passphrase (after unlocking with it). The lanes and history are cleared by the caller.
    public func reset() {
        store.delete()
        isSet = false
        isUnlocked = false
    }

    // MARK: The stored record: "pbkdf2-sha256$<rounds>$<salt b64>$<hash b64>"

    nonisolated static func record(salt: Data, hash: Data, rounds: UInt32) -> String {
        "pbkdf2-sha256$\(rounds)$\(salt.base64EncodedString())$\(hash.base64EncodedString())"
    }

    nonisolated static func parse(_ record: String) -> (rounds: UInt32, salt: Data, hash: Data)? {
        let parts = record.split(separator: "$").map(String.init)
        guard parts.count == 4, parts[0] == "pbkdf2-sha256", let rounds = UInt32(parts[1]), rounds >= 1_000,
              let salt = Data(base64Encoded: parts[2]), let hash = Data(base64Encoded: parts[3]), hash.count == 32 else { return nil }
        return (rounds, salt, hash)
    }

    nonisolated static func derive(_ passphrase: String, salt: Data, rounds: UInt32) -> Data {
        let password = passphrase.precomposedStringWithCanonicalMapping
        let length = 32
        var out = [UInt8](repeating: 0, count: length)
        let saltBytes = [UInt8](salt)
        _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, password.utf8.count,
                                 saltBytes, saltBytes.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds, &out, length)
        return Data(out)
    }

    nonisolated static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

/// Where the passphrase record lives. The Keychain in the app; memory in tests.
public protocol OwnerSecretStore: Sendable {
    func load() -> String?
    func save(_ record: String) -> OSStatus
    func delete()
}

public struct KeychainOwnerStore: OwnerSecretStore {
    public init() {}

    private var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: OwnerLock.service,
         kSecAttrAccount as String: OwnerLock.account]
    }

    public func load() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ record: String) -> OSStatus {
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = Data(record.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil)
    }

    public func delete() { SecItemDelete(base as CFDictionary) }
}

public final class MemoryOwnerStore: OwnerSecretStore, @unchecked Sendable {
    private var record: String?
    private let lock = NSLock()
    public init() {}
    public func load() -> String? { lock.lock(); defer { lock.unlock() }; return record }
    public func save(_ record: String) -> OSStatus { lock.lock(); self.record = record; lock.unlock(); return errSecSuccess }
    public func delete() { lock.lock(); record = nil; lock.unlock() }
}
