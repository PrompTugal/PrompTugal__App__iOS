// The one copy of the small secret-store types, shared by PTAsk (the OpenRouter key) and PTLanes (lane secrets).
import Foundation
import Security

/// Where one secret string lives. The Keychain in the app; memory in tests.
public protocol SecretStore: Sendable {
    func read(_ account: String) throws -> String?
    func write(_ value: String, account: String) throws
    func delete(_ account: String) throws
}

public enum SecretStoreError: Error, Equatable, LocalizedError {
    case keychain(OSStatus)
    case notText
    public var errorDescription: String? {
        switch self {
        case .keychain(let status): "Keychain error \(status)"
        case .notText: "The stored item is not text"
        }
    }
}

/// Generic-password items in the Keychain, this device only, readable after the first unlock
/// (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never synced to iCloud (contracts §9).
public struct KeychainSecretStore: SecretStore {
    public let service: String

    /// `service` names the Keychain service: each feature passes its own (for example "news.promptugal.reader.ai").
    public init(service: String) {
        self.service = service
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    public func read(_ account: String) throws -> String? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecretStoreError.keychain(status) }
        guard let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
            throw SecretStoreError.notText
        }
        return text
    }

    public func write(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query(account) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query(account)
            add.merge(update) { $1 }
            add[kSecAttrLabel as String] = "PrompTugal: \(account)"
            let added = SecItemAdd(add as CFDictionary, nil)
            guard added == errSecSuccess else { throw SecretStoreError.keychain(added) }
        } else if status != errSecSuccess {
            throw SecretStoreError.keychain(status)
        }
    }

    public func delete(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretStoreError.keychain(status) }
    }

    /// Whether an item exists, without reading its value.
    public func exists(_ account: String) -> Bool {
        var query = query(account)
        query[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

/// For tests and previews: nothing leaves memory.
public final class MemorySecretStore: SecretStore, @unchecked Sendable {
    private var items: [String: String] = [:]
    private let lock = NSLock()
    /// Counts reads, so tests can check the key is read only when a request is made.
    public private(set) var reads = 0

    public init(_ items: [String: String] = [:]) {
        self.items = items
    }

    public func read(_ account: String) throws -> String? {
        lock.withLock { reads += 1; return items[account] }
    }

    public func write(_ value: String, account: String) throws {
        lock.withLock { items[account] = value }
    }

    public func delete(_ account: String) throws {
        lock.withLock { _ = items.removeValue(forKey: account) }
    }
}
