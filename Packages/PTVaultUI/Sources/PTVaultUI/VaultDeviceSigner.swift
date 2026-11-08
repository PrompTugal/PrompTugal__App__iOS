import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SGitVault

/// This device's commit-signing key: a Secure Enclave P-256 key that never leaves the chip.
/// Each device writes to its own branch (`device-<name>`) and signs with its own key, as sgit gives
/// every writer its own branch and key. The public key goes to `bare/keys/<keyId>` on the first push.
/// Signing needs Face ID (or the device passcode where there is no biometry).
struct VaultDeviceSigner: VaultCommitSigner, @unchecked Sendable {
    let keyId: String
    let publicKeyPEM: String
    private let handle: Data
    private let context: LAContext?

    func sign(_ data: Data) throws -> Data {
        if SecureEnclave.isAvailable {
            let key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: handle, authenticationContext: context)
            return try key.signature(for: data).rawRepresentation
        }
        let key = try P256.Signing.PrivateKey(rawRepresentation: handle)
        return try key.signature(for: data).rawRepresentation
    }

    private struct Stored: Codable {
        let keyId: String
        let handle: Data
        let secureEnclave: Bool
    }

    private static let account = "device-commit-signing-key"

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: VaultConfig.keychainService + ".signing",
         kSecAttrAccount as String: account,
         kSecUseDataProtectionKeychain as String: true]
    }

    /// This device's signer, created on first use. Pass the context from `VaultKeychain.unlock` so
    /// one Face ID covers unlocking and signing.
    static func load(context: LAContext?) throws -> VaultDeviceSigner {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            return try make(stored, context: context)
        }
        let stored: Stored
        if SecureEnclave.isAvailable {
            var error: Unmanaged<CFError>?
            let flags: SecAccessControlCreateFlags = LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
                ? [.privateKeyUsage, .biometryCurrentSet] : [.privateKeyUsage, .userPresence]
            guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                               flags, &error) else {
                throw VaultKeychain.KeychainError.status(errSecParam, "signing key access control")
            }
            let key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access, authenticationContext: context)
            stored = Stored(keyId: VaultCommitBuilder.newKeyId(), handle: key.dataRepresentation, secureEnclave: true)
        } else {
            // Simulator: a software key, kept in the Keychain on this device only.
            stored = Stored(keyId: VaultCommitBuilder.newKeyId(), handle: P256.Signing.PrivateKey().rawRepresentation,
                            secureEnclave: false)
        }
        var add = query()
        add[kSecValueData as String] = try JSONEncoder().encode(stored)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultKeychain.KeychainError.status(status, "save signing key") }
        return try make(stored, context: context)
    }

    private static func make(_ stored: Stored, context: LAContext?) throws -> VaultDeviceSigner {
        let pem: String
        if stored.secureEnclave {
            pem = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: stored.handle).publicKey.pemRepresentation
        } else {
            pem = try P256.Signing.PrivateKey(rawRepresentation: stored.handle).publicKey.pemRepresentation
        }
        return VaultDeviceSigner(keyId: stored.keyId, publicKeyPEM: pem, handle: stored.handle, context: context)
    }

    /// For the key inventory: the key id (public), and where the key lives. Never the key.
    static func inventory() -> (keyId: String, secureEnclave: Bool)? {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return nil }
        return (stored.keyId, stored.secureEnclave)
    }

    static func delete() { SecItemDelete(query() as CFDictionary) }
}
