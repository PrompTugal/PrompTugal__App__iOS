import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SGitVault

/// Vault keys on this device, behind Face ID.
///
/// - Each key is a Keychain item (this device only, never synced) whose access control is
///   `.biometryCurrentSet`: it stops opening if Face ID enrolment changes.
/// - Where the Secure Enclave exists, the secret inside the item is also wrapped by a Secure Enclave
///   P-256 key (see `VaultKeyWrap`), so the bytes in the Keychain are useless off this chip.
/// - One Face ID unlock is reused for up to 60 seconds (`LAContext` reuse window).
/// - `inventory()` lists what is stored (vault id, kind, protection, date) without any secret and without a prompt.
@MainActor
final class VaultKeychain {
    static let shared = VaultKeychain()

    enum Protection: String, Codable, Sendable {
        case secureEnclaveAndFaceID = "Secure Enclave + Face ID"
        case faceID = "Face ID (current enrolment)"
        case userPresence = "Face ID or passcode"
        case deviceUnlocked = "device unlocked only (no biometry available)"
    }

    /// What is stored next to the secret, readable without Face ID. Never key material.
    struct Metadata: Codable, Sendable, Hashable {
        var vaultId: String
        var kind: VaultKey.Kind
        var label: String
        var role: String              // "reader", "master", "door", "imported"
        var protection: Protection
        var wrapped: Bool
        var createdAt: Date
    }

    /// The secret itself. Encoded only to be stored in the Keychain item.
    private struct Secret: Codable {
        var readKey: String
        var writeKey: String?
    }

    enum KeychainError: Error, CustomStringConvertible, LocalizedError {
        case status(OSStatus, String)
        case notFound
        case cancelled
        /// Neither Face ID nor a device passcode is available, so a key could not be protected (S3).
        case noProtection
        var description: String {
            switch self {
            case .status(let s, let what): "Keychain \(what) failed (\(s))"
            case .notFound: "No stored vault key"
            case .cancelled: "Face ID was cancelled"
            case .noProtection: "No Face ID and no device passcode: refusing to store a key without access control"
            }
        }
        var errorDescription: String? {
            switch self {
            case .status: String(localized: "The key could not be stored on this device. Try again.", bundle: .module)
            case .notFound: String(localized: "No vault key is stored on this device yet.", bundle: .module)
            case .cancelled: String(localized: "Face ID was cancelled.", bundle: .module)
            case .noProtection: String(localized: "Set a passcode on this device to keep vault keys on it. Keys are never stored without Face ID or a passcode.", bundle: .module)
            }
        }
    }

    private var context: LAContext?
    private var contextCreated: Date?

    /// A context reused for up to 60 seconds, so one Face ID opens several keys.
    func authenticationContext(reason: String) -> LAContext {
        if let context, let created = contextCreated, Date().timeIntervalSince(created) < VaultConfig.faceIDReuseSeconds {
            return context
        }
        let fresh = LAContext()
        fresh.touchIDAuthenticationAllowableReuseDuration = VaultConfig.faceIDReuseSeconds
        fresh.localizedReason = reason
        context = fresh
        contextCreated = Date()
        return fresh
    }

    /// Forget the reusable unlock (on lock, or when the app goes to the background).
    func invalidate() {
        context?.invalidate()
        context = nil
        contextCreated = nil
    }

    var biometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Ask for Face ID once; the same context then opens the Keychain and the Secure Enclave without a second prompt.
    func unlock(reason: String) async throws -> LAContext {
        let ctx = authenticationContext(reason: reason)
        let policy: LAPolicy = biometryAvailable ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        do {
            _ = try await ctx.evaluatePolicy(policy, localizedReason: reason)
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            invalidate()
            throw KeychainError.cancelled
        }
        return ctx
    }

    // MARK: Save

    func save(_ key: VaultKey, label: String, role: String) throws {
        let secret = Secret(readKey: key.readKey.withUnsafeBytes { Data($0).hexString },
                            writeKey: key.writeKey?.withUnsafeBytes { Data($0).hexString })
        var payload = try JSONEncoder().encode(secret)
        var wrapped = false
        if VaultKeyWrap.isAvailable, let sealed = try? VaultKeyWrap.shared.wrap(payload) {
            payload = sealed
            wrapped = true
        }
        // S3: only Face ID or the device passcode. Check first, so a refused save never deletes the old key.
        guard LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { throw KeychainError.noProtection }
        try? delete(vaultId: key.vaultId)
        var lastStatus: OSStatus = errSecSuccess
        for protection in [Protection.faceID, .userPresence] {
            var meta = Metadata(vaultId: key.vaultId, kind: key.kind, label: label, role: role,
                                protection: protection, wrapped: wrapped, createdAt: Date())
            if wrapped && protection == .faceID { meta.protection = .secureEnclaveAndFaceID }
            var query = baseQuery(vaultId: key.vaultId)
            query[kSecValueData as String] = payload
            query[kSecAttrLabel as String] = "PrompTugal vault \(key.vaultId)"
            query[kSecAttrGeneric as String] = try JSONEncoder().encode(meta)
            guard let access = accessControl(for: protection) else { continue }
            query[kSecAttrAccessControl as String] = access
            lastStatus = SecItemAdd(query as CFDictionary, nil)
            if lastStatus == errSecSuccess { return }
        }
        if lastStatus == errSecAuthFailed || lastStatus == errSecParam { throw KeychainError.noProtection }
        throw KeychainError.status(lastStatus, "save")
    }

    private func accessControl(for protection: Protection) -> SecAccessControl? {
        let flags: SecAccessControlCreateFlags
        switch protection {
        case .faceID, .secureEnclaveAndFaceID: flags = .biometryCurrentSet
        case .userPresence: flags = .userPresence
        case .deviceUnlocked: return nil
        }
        return SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, flags, nil)
    }

    private func baseQuery(vaultId: String? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: VaultConfig.keychainService,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let vaultId { query[kSecAttrAccount as String] = vaultId }
        return query
    }

    // MARK: Load

    /// All stored keys, after one Face ID (pass the context from `unlock`).
    func loadAll(context: LAContext) throws -> [(VaultKey, Metadata)] {
        try inventory().map { meta in (try load(vaultId: meta.vaultId, context: context), meta) }
    }

    func load(vaultId: String, context: LAContext) throws -> VaultKey {
        var query = baseQuery(vaultId: vaultId)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw KeychainError.notFound }
        if status == errSecUserCanceled { throw KeychainError.cancelled }
        guard status == errSecSuccess, let item = result as? [String: Any],
              var payload = item[kSecValueData as String] as? Data,
              let metaData = item[kSecAttrGeneric as String] as? Data,
              let meta = try? JSONDecoder().decode(Metadata.self, from: metaData) else {
            throw KeychainError.status(status, "read")
        }
        if meta.wrapped { payload = try VaultKeyWrap.shared.unwrap(payload, context: context) }
        let secret = try JSONDecoder().decode(Secret.self, from: payload)
        guard let read = Data(hexString: secret.readKey) else { throw KeychainError.status(errSecDecode, "decode") }
        return VaultKey(kind: meta.kind, vaultId: meta.vaultId, readKey: SymmetricKey(data: read),
                        writeKey: secret.writeKey.flatMap { Data(hexString: $0) }.map { SymmetricKey(data: $0) })
    }

    // MARK: Inventory

    /// How the stored keys are actually protected, in words, for the Vault screen (S3).
    func protectionSummary() -> String {
        let levels = Set(inventory().map(\.protection))
        if levels.isEmpty { return "Keys you import are kept on this device only, behind Face ID or your passcode, and never shown or logged." }
        if levels == [.secureEnclaveAndFaceID] { return "Your keys are on this device only, behind Face ID and wrapped by the Secure Enclave. They are never shown or logged." }
        if levels.isSubset(of: [.secureEnclaveAndFaceID, .faceID]) { return "Your keys are on this device only, behind Face ID. They are never shown or logged." }
        if levels.contains(.deviceUnlocked) { return "Some keys were stored before Face ID or a passcode was required and are protected only by the device being unlocked. Import them again to protect them." }
        return "Your keys are on this device only, behind Face ID or your passcode. They are never shown or logged."
    }

    /// What is stored, without secrets and without a Face ID prompt.
    func inventory() -> [Metadata] {
        var query = baseQuery()
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        let quiet = LAContext()
        quiet.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = quiet
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            (item[kSecAttrGeneric as String] as? Data).flatMap { try? JSONDecoder().decode(Metadata.self, from: $0) }
        }.sorted { $0.createdAt < $1.createdAt }
    }

    func delete(vaultId: String) throws {
        let status = SecItemDelete(baseQuery(vaultId: vaultId) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status, "delete") }
    }

    func deleteAll() {
        SecItemDelete(baseQuery() as CFDictionary)
        VaultKeyWrap.shared.reset()
        invalidate()
    }
}
