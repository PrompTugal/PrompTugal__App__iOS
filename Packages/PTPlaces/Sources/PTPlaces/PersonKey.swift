import CryptoKit
import Foundation
import Security

// Sign-in with the PrompTugal.news person key (website newsroom/tools/person-key.mjs, assets/login/keyring.js):
// a conductor issues two P-256 keys to a person (ECDH: things sealed to the person; ECDSA: what the person sends is
// signed) and hands the private halves over as https://promptugal.news/login/#key=<base64url JSON>, shown as a QR code.
//   packed = { "v": 1, "p": person, "f": fingerprint, "e": [d, x, y], "s": [d, x, y] }   (JWK base64url fields)
// The public halves are in https://promptugal.news/board/person-keys.json; the app proves the key against it.
// The private halves stay in this device's Keychain, never in a file, never sent anywhere.

public struct PersonKey: Sendable, Equatable {
    public let person: String
    public let fingerprint: String
    public let signingFingerprint: String
    /// The packed form, kept in the Keychain.
    let packed: String
    let encryptD: Data, encryptX: String, encryptY: String
    let signD: Data, signX: String, signY: String

    public enum Failure: Error, Equatable {
        case noKeyInLink, unreadable, wrongFingerprint, notInRegister, replaced
    }

    /// From a sign-in link, its #key= fragment, or the bare packed text (a pasted QR).
    public init(link: String) throws {
        let text = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let packed: String
        if let range = text.range(of: "key=") {
            packed = String(text[range.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        } else if text.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }), text.count > 40 {
            packed = text
        } else {
            throw Failure.noKeyInLink
        }
        guard let json = Base64URL.decode(packed),
              let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let person = object["p"] as? String, let fingerprint = object["f"] as? String,
              let e = object["e"] as? [String], e.count == 3, let s = object["s"] as? [String], s.count == 3,
              let ed = Base64URL.decode(e[0]), let sd = Base64URL.decode(s[0]) else { throw Failure.unreadable }
        guard (try? P256.KeyAgreement.PrivateKey(rawRepresentation: ed)) != nil,
              (try? P256.Signing.PrivateKey(rawRepresentation: sd)) != nil else { throw Failure.unreadable }
        guard Self.fingerprint(x: e[1], y: e[2]) == fingerprint else { throw Failure.wrongFingerprint }
        self.person = person
        self.fingerprint = fingerprint
        self.signingFingerprint = Self.fingerprint(x: s[1], y: s[2])
        self.packed = packed
        encryptD = ed; encryptX = e[1]; encryptY = e[2]
        signD = sd; signX = s[1]; signY = s[2]
    }

    /// "sha256:" + the first 16 hex of SHA-256("P-256:<x>:<y>"), as person-key.mjs computes it.
    public static func fingerprint(x: String, y: String) -> String {
        let digest = SHA256.hash(data: Data("P-256:\(x):\(y)".utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined().prefix(16)
    }

    /// Checks the key against the public register: an active entry for this person with the same public halves.
    public func prove(against register: PersonKeyRegister) throws {
        let mine = register.keys.filter { $0.person == person && $0.fingerprint == fingerprint }
        guard let entry = mine.first else { throw Failure.notInRegister }
        guard entry.encryptX == encryptX, entry.signX == signX else { throw Failure.wrongFingerprint }
        guard entry.status == "active" else { throw Failure.replaced }
    }

    // MARK: Using it

    /// The signing key itself, for a transport that signs its envelope (PTTalk's TalkTransport.send).
    public func signingKey() throws -> P256.Signing.PrivateKey {
        try P256.Signing.PrivateKey(rawRepresentation: signD)
    }

    /// ECDSA P-256 over SHA-256, the raw r||s form (WebCrypto and person-key.mjs verify use ieee-p1363), base64.
    public func sign(_ text: String) throws -> String {
        let key = try P256.Signing.PrivateKey(rawRepresentation: signD)
        return try key.signature(for: Data(text.utf8)).rawRepresentation.base64EncodedString()
    }

    /// Opens a ws-ecies-1 envelope sealed to this person (a reply from the conductor).
    public func open(_ envelope: SealedEnvelope) throws -> Data {
        guard envelope.v == "ws-ecies-1" else { throw Failure.unreadable }
        guard envelope.key == fingerprint else { throw Failure.wrongFingerprint }
        let key = try P256.KeyAgreement.PrivateKey(rawRepresentation: encryptD)
        return try WSECIES.open(envelope, with: key)
    }
}

/// {v, to, key, by, at, epk: {kty, crv, x, y}, iv, ct} (ct = ciphertext then the 16-byte tag, base64).
public struct SealedEnvelope: Codable, Sendable, Equatable {
    public var v: String
    public var to: String
    public var key: String
    public var by: String?
    public var at: String?
    public var epk: JWK
    public var iv: String
    public var ct: String

    public struct JWK: Codable, Sendable, Equatable {
        public var kty: String
        public var crv: String
        public var x: String
        public var y: String
    }
}

/// ws-ecies-1: an ephemeral P-256 key, ECDH, HKDF-SHA256 (empty salt, info "ws-ecies-1") to AES-256-GCM.
public enum WSECIES {
    static let info = Data("ws-ecies-1".utf8)

    static func symmetricKey(_ secret: SharedSecret) -> SymmetricKey {
        secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: info, outputByteCount: 32)
    }

    public static func open(_ envelope: SealedEnvelope, with key: P256.KeyAgreement.PrivateKey) throws -> Data {
        guard let x = Base64URL.decode(envelope.epk.x), let y = Base64URL.decode(envelope.epk.y),
              let iv = Data(base64Encoded: envelope.iv), let ct = Data(base64Encoded: envelope.ct), ct.count >= 16 else {
            throw PersonKey.Failure.unreadable
        }
        let epk = try P256.KeyAgreement.PublicKey(rawRepresentation: x + y)
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: ct.dropLast(16), tag: ct.suffix(16))
        return try AES.GCM.open(box, using: symmetricKey(try key.sharedSecretFromKeyAgreement(with: epk)))
    }

    /// Seals to a person's public encrypt key, as person-key.mjs seal does (used by the tests).
    public static func seal(_ plain: Data, to recipient: P256.KeyAgreement.PublicKey, person: String, fingerprint: String) throws -> SealedEnvelope {
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let key = symmetricKey(try ephemeral.sharedSecretFromKeyAgreement(with: recipient))
        let box = try AES.GCM.seal(plain, using: key)
        let raw = ephemeral.publicKey.rawRepresentation
        return SealedEnvelope(v: "ws-ecies-1", to: person, key: fingerprint, by: nil, at: nil,
                              epk: .init(kty: "EC", crv: "P-256", x: Base64URL.encode(raw.prefix(32)), y: Base64URL.encode(raw.suffix(32))),
                              iv: Data(box.nonce).base64EncodedString(), ct: (box.ciphertext + box.tag).base64EncodedString())
    }
}

/// https://promptugal.news/board/person-keys.json: public halves only.
public struct PersonKeyRegister: Decodable, Sendable, Equatable {
    public var keys: [Entry]

    public struct Entry: Decodable, Sendable, Equatable {
        public var person: String
        public var fingerprint: String
        public var status: String
        public var encryptX: String
        public var signX: String

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: AnyKey.self)
            person = c.string("person") ?? ""
            fingerprint = c.string("fingerprint") ?? ""
            status = c.string("status") ?? ""
            encryptX = c.lenient([String: String].self, "encrypt")?["x"] ?? ""
            signX = c.lenient([String: String].self, "sign")?["x"] ?? ""
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        keys = c.lenientArray("keys")
    }
}

public enum Base64URL {
    public static func decode(_ text: String) -> Data? {
        var s = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    public static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// The person key in the Keychain: this device only, after first unlock, never synced.
public enum PersonKeychain {
    static let service = "news.promptugal.person-key"

    public static func save(_ key: PersonKey) throws {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.person,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(key.packed.utf8),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    public static func load() -> PersonKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
              let packed = String(data: data, encoding: .utf8) else { return nil }
        return try? PersonKey(link: packed)
    }

    public static func delete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }
}
