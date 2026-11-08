// PTLanes keeps its own copy of the small secret-store types: PTAsk and PTLanes both need them and neither may
// depend on the other. Move them down into PTCore later (platform's call) and delete both copies.
import Foundation
import Security

/// Where one secret string lives. The Keychain in the app; memory in tests.
protocol SecretStore: Sendable {
    func read(_ account: String) throws -> String?
    func write(_ value: String, account: String) throws
    func delete(_ account: String) throws
}

enum SecretStoreError: Error, Equatable, LocalizedError {
    case keychain(OSStatus)
    case notText
    var errorDescription: String? {
        switch self {
        case .keychain(let status): "Keychain error \(status)"
        case .notText: "The stored item is not text"
        }
    }
}

/// Generic-password items in the Keychain, this device only, readable after the first unlock
/// (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never synced to iCloud (contracts §9).
struct KeychainSecretStore: SecretStore {
    let service: String

    init(service: String = "news.promptugal.reader.lanes") {
        self.service = service
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }

    func read(_ account: String) throws -> String? {
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

    func write(_ value: String, account: String) throws {
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

    func delete(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretStoreError.keychain(status) }
    }

    /// Whether an item exists, without reading its value.
    func exists(_ account: String) -> Bool {
        var query = query(account)
        query[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

/// For tests and previews: nothing leaves memory.
final class MemorySecretStore: SecretStore, @unchecked Sendable {
    private var items: [String: String] = [:]
    private let lock = NSLock()
    /// Counts reads, so tests can check the key is read only when a request is made.
    private(set) var reads = 0

    init(_ items: [String: String] = [:]) {
        self.items = items
    }

    func read(_ account: String) throws -> String? {
        lock.withLock { reads += 1; return items[account] }
    }

    func write(_ value: String, account: String) throws {
        lock.withLock { items[account] = value }
    }

    func delete(_ account: String) throws {
        lock.withLock { _ = items.removeValue(forKey: account) }
    }
}
