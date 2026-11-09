import CryptoKit
import Foundation
import Security

/// This device's messaging keys (WS-203): two P-256 keys, one to agree content keys (ws-ecies-1) and one to sign.
/// On a device they live in the Secure Enclave and never leave it; the Keychain keeps only the enclave's opaque
/// handle (dataRepresentation), for this device only. On the simulator, which has no enclave, software keys are kept
/// in the Keychain the same way. Signing needs no Face ID: it happens on every message.
public enum MessagingDevice {
    static let service = "news.promptugal.team.messaging"
    static let agreeAccount = "device-agree-v1"
    static let signAccount = "device-sign-v1"

    public enum Failure: Error, LocalizedError {
        case keychain(OSStatus)
        public var errorDescription: String? {
            switch self { case .keychain(let s): "The key could not be kept on this device (\(s))." }
        }
    }

    /// This device's identity for `person`, making the keys on first use.
    public static func identity(person: String) throws -> MessageIdentity {
        if SecureEnclave.isAvailable {
            let agree = try loadOrMake(agreeAccount) { try SecureEnclave.P256.KeyAgreement.PrivateKey() } restore: {
                try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: $0)
            } data: { $0.dataRepresentation }
            let sign = try loadOrMake(signAccount) { try SecureEnclave.P256.Signing.PrivateKey() } restore: {
                try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: $0)
            } data: { $0.dataRepresentation }
            return MessageIdentity(name: person,
                                   fingerprint: MessageCrypto.fingerprint(agree.publicKey),
                                   signingFingerprint: MessageCrypto.fingerprint(sign.publicKey),
                                   agree: { try agree.sharedSecretFromKeyAgreement(with: $0) },
                                   sign: { try sign.signature(for: $0).rawRepresentation })
        }
        let agree = try loadOrMake(agreeAccount) { P256.KeyAgreement.PrivateKey() } restore: {
            try P256.KeyAgreement.PrivateKey(rawRepresentation: $0)
        } data: { $0.rawRepresentation }
        let sign = try loadOrMake(signAccount) { P256.Signing.PrivateKey() } restore: {
            try P256.Signing.PrivateKey(rawRepresentation: $0)
        } data: { $0.rawRepresentation }
        return .software(name: person, agreement: agree, signing: sign)
    }

    /// The public halves, as the entry for data/messaging/device-keys.json on the team site.
    public static func publicEntry(person: String, device: String) throws -> String {
        let (agreePub, signPub) = try publicKeys()
        let entry: [String: Any] = [
            "person": person, "device": device, "status": "active", "added_at": MessageTime.now(),
            "fingerprint": MessageCrypto.fingerprint(agreePub), "signing_fingerprint": MessageCrypto.fingerprint(signPub),
            "encrypt": jwkDict(agreePub.x963Representation), "sign": jwkDict(signPub.x963Representation),
        ]
        let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }

    static func publicKeys() throws -> (P256.KeyAgreement.PublicKey, P256.Signing.PublicKey) {
        if SecureEnclave.isAvailable {
            let a = try loadOrMake(agreeAccount) { try SecureEnclave.P256.KeyAgreement.PrivateKey() } restore: {
                try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: $0)
            } data: { $0.dataRepresentation }
            let s = try loadOrMake(signAccount) { try SecureEnclave.P256.Signing.PrivateKey() } restore: {
                try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: $0)
            } data: { $0.dataRepresentation }
            return (a.publicKey, s.publicKey)
        }
        let a = try loadOrMake(agreeAccount) { P256.KeyAgreement.PrivateKey() } restore: { try P256.KeyAgreement.PrivateKey(rawRepresentation: $0) } data: { $0.rawRepresentation }
        let s = try loadOrMake(signAccount) { P256.Signing.PrivateKey() } restore: { try P256.Signing.PrivateKey(rawRepresentation: $0) } data: { $0.rawRepresentation }
        return (a.publicKey, s.publicKey)
    }

    static func jwkDict(_ x963: Data) -> [String: String] {
        let j = JWK(x963: x963)
        return ["kty": j.kty, "crv": j.crv, "x": j.x, "y": j.y]
    }

    /// Forgets this device's messaging keys (a new identity next time). For Settings, after a warning.
    public static func forget() {
        for account in [agreeAccount, signAccount] {
            SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account] as CFDictionary)
        }
    }

    // MARK: Keychain

    static func loadOrMake<K>(_ account: String, make: () throws -> K, restore: (Data) throws -> K, data: (K) -> Data) throws -> K {
        if let stored = read(account), let key = try? restore(stored) { return key }
        let key = try make()
        try write(account, data(key))
        return key
    }

    static func read(_ account: String) -> Data? {
        var out: CFTypeRef?
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
                                  kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    static func write(_ account: String, _ value: Data) throws {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData] = value
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.keychain(status) }
    }
}
