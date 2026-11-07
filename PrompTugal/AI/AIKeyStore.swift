import Foundation
import Observation
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

    init(service: String = "news.promptugal.reader.ai") {
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

/// The user's OpenRouter key (contracts §9): entered once, kept in the Keychain, read only to make a request,
/// sent only to openrouter.ai. The UI and the debug panel see `hasKey` and a masked hint, never the value.
@MainActor @Observable
final class AIKeyStore {
    static let shared = AIKeyStore()
    static let account = "openrouter.key"
    /// The vault file the key can be copied to (contracts §9).
    static let vaultPath = "apps/ai/openrouter.json"

    private(set) var hasKey = false
    /// e.g. "sk-or-…3f9a": the first six and last four characters, for "which key is this?". Never more.
    private(set) var hint: String?
    private(set) var lastError: String?
    private(set) var savedToVaultAt: Date?

    @ObservationIgnored private let store: SecretStore
    @ObservationIgnored private let defaults: UserDefaults

    init(store: SecretStore = KeychainSecretStore(), defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        hint = defaults.string(forKey: "ai.keyHint")
        if let saved = defaults.object(forKey: "ai.keySavedToVaultAt") as? Date { savedToVaultAt = saved }
        do {
            hasKey = try store.read(Self.account) != nil
        } catch {
            hasKey = false
            lastError = error.localizedDescription
        }
    }

    static func mask(_ key: String) -> String {
        guard key.count > 12 else { return "…" }
        return "\(key.prefix(6))…\(key.suffix(4))"
    }

    func save(_ raw: String) throws {
        let key = try OpenRouter.validated(key: raw)
        try store.write(key, account: Self.account)
        hasKey = true
        hint = Self.mask(key)
        defaults.set(hint, forKey: "ai.keyHint")
        lastError = nil
    }

    /// The key, for building one request. Callers must not keep it.
    func key() throws -> String {
        guard let key = try store.read(Self.account) else {
            hasKey = false
            throw OpenRouter.RequestError.noKey
        }
        return key
    }

    func forget() {
        do {
            try store.delete(Self.account)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        hasKey = false
        hint = nil
        defaults.removeObject(forKey: "ai.keyHint")
    }

    // MARK: Checking the key

    /// What OpenRouter says about the key (`GET /api/v1/key`): usage and limit in dollars. Never the key itself.
    struct KeyInfo: Equatable, Sendable {
        let label: String?
        let usage: Double?
        let limit: Double?
        let freeTier: Bool?

        var summary: String {
            var parts: [String] = ["The key works"]
            if let usage { parts.append(String(format: "used $%.2f", usage)) }
            parts.append(limit.map { String(format: "limit $%.2f", $0) } ?? "no limit set")
            if freeTier == true { parts.append("free tier") }
            return parts.joined(separator: ", ") + "."
        }

        static func parse(_ data: Data) -> KeyInfo? {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let info = object["data"] as? [String: Any] else { return nil }
            return KeyInfo(label: info["label"] as? String, usage: (info["usage"] as? NSNumber)?.doubleValue,
                           limit: (info["limit"] as? NSNumber)?.doubleValue, freeTier: info["is_free_tier"] as? Bool)
        }
    }

    static let keyInfoURL = URL(string: "https://openrouter.ai/api/v1/key")!

    func check(http: HTTPClient = .shared) async throws -> KeyInfo {
        var request = URLRequest(url: Self.keyInfoURL, timeoutInterval: 20)
        request.setValue("Bearer \(try key())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await http.data(for: request, label: "ai.key.check")
        guard (200..<300).contains(response.statusCode) else {
            throw OpenRouter.ServerError(status: response.statusCode, detail: OpenRouter.errorMessage(in: data))
        }
        guard let info = KeyInfo.parse(data) else { throw URLError(.cannotParseResponse) }
        return info
    }

    // MARK: Vault copy (apps/ai/openrouter.json)

    struct VaultFile: Codable, Equatable {
        var v = 1
        var provider = "openrouter"
        var key: String
        var model: String?
        var savedAt: String
        var device: String?
    }

    static func vaultDocument(key: String, model: String?, at date: Date = .now, device: String? = nil) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let file = VaultFile(key: try OpenRouter.validated(key: key), model: model,
                             savedAt: ISO8601DateFormatter().string(from: date), device: device)
        return try encoder.encode(file)
    }

    static func key(fromVaultDocument data: Data) throws -> (key: String, model: String?) {
        let file = try JSONDecoder().decode(VaultFile.self, from: data)
        return (try OpenRouter.validated(key: file.key), file.model)
    }

    /// Copy the key into the open vault with write access, through the vault session (`CollabHooks.vault`).
    func saveToVault(model: String?) async throws {
        guard let vault = CollabHooks.vault, vault.canWrite else { throw CollabHooks.HookError.noWritableVault }
        let document = try Self.vaultDocument(key: key(), model: model)
        try await vault.write(Self.vaultPath, document, "OpenRouter key for Ask, from the app")
        savedToVaultAt = .now
        defaults.set(savedToVaultAt, forKey: "ai.keySavedToVaultAt")
    }

    /// Take the key from the vault (another device saved it), into this device's Keychain.
    @discardableResult
    func loadFromVault() async throws -> String? {
        guard let vault = CollabHooks.vault, vault.isOpen else { throw CollabHooks.HookError.noVault }
        guard let data = try await vault.read(Self.vaultPath) else { return nil }
        let (key, model) = try Self.key(fromVaultDocument: data)
        try save(key)
        return model
    }
}
