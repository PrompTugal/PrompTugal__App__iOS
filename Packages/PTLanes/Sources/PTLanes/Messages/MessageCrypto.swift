import CryptoKit
import Foundation
import Security

// The envelope ws-msg-env-1 (WS-203), as the team site's admin/tools/messages.mjs makes it and
// people/indi/messaging/FORMATS.md specifies it:
//   ct  = AES-256-GCM (tag appended) of the message JSON under a fresh content key (CEK);
//   each reader's env seals {"cek": base64}: ws-ecies-1 to a P-256 key (people, devices),
//   sgit hybrid v2 to an agent's RSA key (LaneCrypto, the same code the lanes use);
//   sig = ECDSA P-256 / SHA-256, raw r||s, over the signed string, so neither the content
//   nor the list of readers can change.

public struct MessageEnvelope: Codable, Equatable, Sendable {
    public static let version = "ws-msg-env-1"
    public var v: String = MessageEnvelope.version
    public var id: String
    public var thread: String
    public var recipients: [Recipient]
    public var iv: String
    public var ct: String
    public var by: String
    public var sig: String

    public struct Recipient: Codable, Equatable, Sendable {
        public var to: String
        public var key: String
        public var env: KeyEnvelope
    }

    /// One reader's sealed content key: ws-ecies-1 (epk, iv, ct) or sgit-hybrid-2 (payload).
    public struct KeyEnvelope: Codable, Equatable, Sendable {
        public var v: String
        public var epk: JWK?
        public var iv: String?
        public var ct: String?
        public var payload: String?
    }

    /// The bytes the sender signs: one field per line, readers last, in envelope order.
    var signedString: String {
        ([MessageEnvelope.version, id, thread, iv, ct] + recipients.map { "\($0.to) \($0.key)" }).joined(separator: "\n")
    }
}

/// A P-256 public key as JSON Web Key (x and y base64url, no padding).
public struct JWK: Codable, Equatable, Hashable, Sendable {
    public var kty: String = "EC"
    public var crv: String = "P-256"
    public var x: String
    public var y: String

    public init(x963: Data) {
        // x963 is 0x04 || x (32) || y (32)
        let raw = x963.dropFirst()
        x = MessageCrypto.base64url(raw.prefix(32))
        y = MessageCrypto.base64url(raw.suffix(32))
    }

    public var x963: Data? {
        guard kty == "EC", crv == "P-256", let xs = MessageCrypto.unbase64url(x), let ys = MessageCrypto.unbase64url(y),
              xs.count == 32, ys.count == 32 else { return nil }
        return Data([0x04]) + xs + ys
    }
}

/// Someone a message can be sealed to: one key of one person, device or agent.
public struct MessageReader: Sendable {
    public enum Key: @unchecked Sendable { case p256(P256.KeyAgreement.PublicKey), rsa(SecKey) }
    public var to: String
    public var fingerprint: String
    public var key: Key
    public init(to: String, fingerprint: String, key: Key) { self.to = to; self.fingerprint = fingerprint; self.key = key }
}

/// This device (or a test identity): who it speaks for, and how it agrees keys and signs.
/// Closures, so the same code serves Secure Enclave keys and software keys (tests, the simulator).
public struct MessageIdentity: @unchecked Sendable {
    public var name: String
    public var fingerprint: String
    public var signingFingerprint: String
    public var agree: @Sendable (P256.KeyAgreement.PublicKey) throws -> SharedSecret
    public var sign: @Sendable (Data) throws -> Data
    /// An agent-style RSA private key, if this identity reads sgit-hybrid-2 (not used by devices).
    public var rsa: SecKey?

    public init(name: String, fingerprint: String, signingFingerprint: String,
                agree: @escaping @Sendable (P256.KeyAgreement.PublicKey) throws -> SharedSecret,
                sign: @escaping @Sendable (Data) throws -> Data, rsa: SecKey? = nil) {
        self.name = name; self.fingerprint = fingerprint; self.signingFingerprint = signingFingerprint
        self.agree = agree; self.sign = sign; self.rsa = rsa
    }

    /// Software P-256 keys: for tests and the simulator.
    public static func software(name: String, agreement: P256.KeyAgreement.PrivateKey, signing: P256.Signing.PrivateKey) -> MessageIdentity {
        MessageIdentity(name: name,
                        fingerprint: MessageCrypto.fingerprint(agreement.publicKey),
                        signingFingerprint: MessageCrypto.fingerprint(signing.publicKey),
                        agree: { try agreement.sharedSecretFromKeyAgreement(with: $0) },
                        sign: { try signing.signature(for: $0).rawRepresentation })
    }
}

/// Who a signing fingerprint speaks for, and the key to check it with.
public struct MessageSigner: Sendable {
    public var name: String
    public var key: P256.Signing.PublicKey
    public init(name: String, key: P256.Signing.PublicKey) { self.name = name; self.key = key }
}

public enum MessageCrypto {
    public enum Refusal: Error, Equatable, LocalizedError {
        case notAnEnvelope(String)
        case unknownSigner(String)
        case badSignature
        case notSealedToMe
        case cannotOpen(String)
        case fromIsNotSigner(from: String, signer: String)
        case outsideDiffersFromInside

        public var errorDescription: String? {
            switch self {
            case .notAnEnvelope(let v): "Not a team message (\(v))."
            case .unknownSigner(let fp): "Signed by \(fp), which is on no published key list."
            case .badSignature: "The signature does not match."
            case .notSealedToMe: "Not sealed to this device."
            case .cannotOpen(let why): "Could not be opened (\(why))."
            case .fromIsNotSigner(let from, let signer): "Says it is from \(from) but was signed by \(signer)."
            case .outsideDiffersFromInside: "Its id or thread outside does not match the message inside."
            }
        }
    }

    static let eciesInfo = Data("ws-ecies-1".utf8)

    // MARK: Seal

    public static func seal(_ message: TeamMessage, to readers: [MessageReader], as me: MessageIdentity) throws -> MessageEnvelope {
        let cek = SymmetricKey(size: .bits256)
        let box = try AES.GCM.seal(try message.encoded(), using: cek)
        let cekJSON = try jsonNoSlashes(["cek": cek.withUnsafeBytes { Data($0) }.base64EncodedString()])
        var env = MessageEnvelope(id: message.id, thread: message.thread,
                                  recipients: try readers.map { .init(to: $0.to, key: $0.fingerprint, env: try sealKey(cekJSON, to: $0.key)) },
                                  iv: Data(box.nonce).base64EncodedString(),
                                  ct: (box.ciphertext + box.tag).base64EncodedString(),
                                  by: me.signingFingerprint, sig: "")
        env.sig = try me.sign(Data(env.signedString.utf8)).base64EncodedString()
        return env
    }

    static func sealKey(_ plain: Data, to key: MessageReader.Key) throws -> MessageEnvelope.KeyEnvelope {
        switch key {
        case .rsa(let pub):
            return .init(v: "sgit-hybrid-2", payload: try LaneCrypto.encrypt(plain, to: pub))
        case .p256(let pub):
            let eph = P256.KeyAgreement.PrivateKey()
            let secret = try eph.sharedSecretFromKeyAgreement(with: pub)
            let box = try AES.GCM.seal(plain, using: eciesKey(secret))
            return .init(v: "ws-ecies-1", epk: JWK(x963: eph.publicKey.x963Representation),
                         iv: Data(box.nonce).base64EncodedString(), ct: (box.ciphertext + box.tag).base64EncodedString())
        }
    }

    static func eciesKey(_ secret: SharedSecret) -> SymmetricKey {
        secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: eciesInfo, outputByteCount: 32)
    }

    // MARK: Open: the five rules, in order. Any failure refuses the message.

    public static func open(_ env: MessageEnvelope, as me: MessageIdentity,
                            signer lookup: (String) -> MessageSigner?) throws -> TeamMessage {
        guard env.v == MessageEnvelope.version else { throw Refusal.notAnEnvelope(env.v) }
        // 1. the signer is on a published list
        guard let signer = lookup(env.by) else { throw Refusal.unknownSigner(env.by) }
        // 2. the signature checks
        guard let sigData = Data(base64Encoded: env.sig),
              let sig = try? P256.Signing.ECDSASignature(rawRepresentation: sigData),
              signer.key.isValidSignature(sig, for: Data(env.signedString.utf8)) else { throw Refusal.badSignature }
        // 3. it is sealed to this key, and opens
        guard let mine = env.recipients.first(where: { $0.key == me.fingerprint }) else { throw Refusal.notSealedToMe }
        let message: TeamMessage
        do {
            let cek = try openKey(mine.env, as: me)
            guard let iv = Data(base64Encoded: env.iv), let ct = Data(base64Encoded: env.ct) else { throw Refusal.cannotOpen("base64") }
            message = try TeamMessage.decode(try gcmOpen(ct, iv: iv, key: cek))
        } catch let r as Refusal {
            throw r
        } catch {
            throw Refusal.cannotOpen(String(describing: error))
        }
        // 4. the message is from whoever signed it
        guard message.from == signer.name else { throw Refusal.fromIsNotSigner(from: message.from, signer: signer.name) }
        // 5. the outside matches the inside
        guard message.id == env.id, message.thread == env.thread else { throw Refusal.outsideDiffersFromInside }
        return message
    }

    static func openKey(_ env: MessageEnvelope.KeyEnvelope, as me: MessageIdentity) throws -> SymmetricKey {
        let plain: Data
        switch env.v {
        case "ws-ecies-1":
            guard let x963 = env.epk?.x963, let ivS = env.iv, let ctS = env.ct,
                  let iv = Data(base64Encoded: ivS), let ct = Data(base64Encoded: ctS) else { throw Refusal.cannotOpen("ws-ecies-1 fields") }
            let epk = try P256.KeyAgreement.PublicKey(x963Representation: x963)
            plain = try gcmOpen(ct, iv: iv, key: eciesKey(try me.agree(epk)))
        case "sgit-hybrid-2":
            guard let payload = env.payload, let rsa = me.rsa else { throw Refusal.cannotOpen("no RSA key here") }
            plain = try LaneCrypto.decrypt(payload, with: rsa)
        default:
            throw Refusal.cannotOpen("key envelope \(env.v)")
        }
        struct CEK: Decodable { var cek: String }
        guard let raw = Data(base64Encoded: try JSONDecoder().decode(CEK.self, from: plain).cek), raw.count == 32 else {
            throw Refusal.cannotOpen("content key")
        }
        return SymmetricKey(data: raw)
    }

    static func gcmOpen(_ ctWithTag: Data, iv: Data, key: SymmetricKey) throws -> Data {
        guard ctWithTag.count >= 16 else { throw Refusal.cannotOpen("too short") }
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: ctWithTag.dropLast(16), tag: ctWithTag.suffix(16))
        return try AES.GCM.open(box, using: key)
    }

    // MARK: Helpers

    /// sha256: + 16 hex characters of SHA-256 over the DER SubjectPublicKeyInfo (sgit's compute_fingerprint).
    public static func fingerprint(_ key: P256.KeyAgreement.PublicKey) -> String { fingerprint(spki: key.derRepresentation) }
    public static func fingerprint(_ key: P256.Signing.PublicKey) -> String { fingerprint(spki: key.derRepresentation) }
    static func fingerprint(spki: Data) -> String { "sha256:" + String(sha256Hex(spki).prefix(16)) }

    public static func sha256Hex(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    static func base64url<D: DataProtocol>(_ d: D) -> String {
        Data(d).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func unbase64url(_ s: String) -> Data? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        return Data(base64Encoded: b)
    }

    static func jsonNoSlashes(_ dict: [String: String]) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(dict)
    }
}
