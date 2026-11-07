import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Wraps vault key bytes with a Secure Enclave P-256 key that never leaves the chip.
///
///     wrap:    ephemeral P-256 key E;  K = HKDF-SHA256(ECDH(E, SE public), salt = E.pub, info "promptugal/vault-wrap/v1")
///              blob = "pvw1" + E.pub (65 bytes, x9.63) + AES-256-GCM(K, secret)
///     unwrap:  ECDH(SE private, E.pub) inside the Secure Enclave, after Face ID (`.biometryCurrentSet`)
///
/// Wrapping needs only the public key, so it never prompts. Unwrapping needs Face ID. If Face ID enrolment
/// changes, the Secure Enclave key stops working and the wrapped keys must be imported again (by passkey or paste).
/// The Secure Enclave key's handle (not the key) is kept in the Keychain, this device only.
final class VaultKeyWrap: @unchecked Sendable {
    static let shared = VaultKeyWrap()
    static var isAvailable: Bool { SecureEnclave.isAvailable }

    private static let magic = Data("pvw1".utf8)
    private static let info = Data("promptugal/vault-wrap/v1".utf8)
    private static let handleAccount = "secure-enclave-wrap-key"
    private let lock = NSLock()

    enum WrapError: Error { case unavailable, malformed, keychain(OSStatus) }

    private func handleQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: VaultConfig.keychainService + ".se",
         kSecAttrAccount as String: Self.handleAccount,
         kSecUseDataProtectionKeychain as String: true]
    }

    private func storedHandle() -> Data? {
        var query = handleQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    /// The public half, from the stored handle (no prompt), creating the key on first use.
    private func publicKey() throws -> P256.KeyAgreement.PublicKey {
        lock.lock(); defer { lock.unlock() }
        guard Self.isAvailable else { throw WrapError.unavailable }
        if let handle = storedHandle() {
            // Loading the handle does not use the private key, so no Face ID is needed here.
            return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: handle).publicKey
        }
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                           [.privateKeyUsage, .biometryCurrentSet], &error) else {
            throw WrapError.unavailable
        }
        let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access)
        var query = handleQuery()
        query[kSecValueData as String] = key.dataRepresentation
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw WrapError.keychain(status) }
        return key.publicKey
    }

    func wrap(_ secret: Data) throws -> Data {
        let recipient = try publicKey()
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipient)
        let ephemeralPublic = ephemeral.publicKey.x963Representation
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: ephemeralPublic,
                                                 sharedInfo: Self.info, outputByteCount: 32)
        guard let sealed = try AES.GCM.seal(secret, using: key).combined else { throw WrapError.malformed }
        return Self.magic + ephemeralPublic + sealed
    }

    /// Needs the Face ID context from `VaultKeychain.unlock`.
    func unwrap(_ blob: Data, context: LAContext) throws -> Data {
        guard blob.count > Self.magic.count + 65 + 28, blob.prefix(Self.magic.count) == Self.magic else {
            throw WrapError.malformed
        }
        guard let handle = storedHandle() else { throw WrapError.unavailable }
        let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: handle,
                                                                       authenticationContext: context)
        let body = blob.dropFirst(Self.magic.count)
        let ephemeralPublic = Data(body.prefix(65))
        let sealed = Data(body.dropFirst(65))
        let shared = try privateKey.sharedSecretFromKeyAgreement(
            with: P256.KeyAgreement.PublicKey(x963Representation: ephemeralPublic))
        let key = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: ephemeralPublic,
                                                 sharedInfo: Self.info, outputByteCount: 32)
        return try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
    }

    /// Delete the Secure Enclave key handle (every wrapped key becomes unreadable).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        SecItemDelete(handleQuery() as CFDictionary)
    }

    var exists: Bool { storedHandle() != nil }
}
