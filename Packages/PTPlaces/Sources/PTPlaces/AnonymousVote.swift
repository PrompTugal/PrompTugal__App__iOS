import CryptoKit
import Foundation
import PTCore
import Security
import UIKit

// Thumbs up or down are anonymous (Dinis, 15 Nov, relayed by conductor@): an unsigned vote on the website's
// observability lane, the format of its assets/obs/obs.js (PTObs.vote): no person, no key, no device id beyond a
// random id that ends with the app run, no place lookup, no IP kept. Config from https://promptugal.news/assets/obs/obs.json
// (public on purpose: each append token can only write, the key can only encrypt).
// Sealed as the sgit hybrid envelope v2: AES-256-GCM for the text, its key wrapped with RSA-OAEP-SHA256;
// payload = base64(base64(JSON {v: 2, w, i, c})), POSTed as {append_token, payload} to
// <endpoint>/api/vault/append/write/<vault_id>; on 507 (a lane full) the next lane.

public struct ObsConfig: Decodable, Sendable {
    public var enabled: Bool
    public var endpoint: String
    public var vaultID: String
    public var siteLanes: [String]
    public var recipientPEM: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        enabled = c.lenient(Bool.self, "enabled") ?? false
        endpoint = c.string("endpoint") ?? ""
        vaultID = c.string("vault_id") ?? ""
        siteLanes = c.lenient([String: [String]].self, "lanes")?["site"] ?? []
        recipientPEM = c.lenient([String: String].self, "recipient")?["encrypt"] ?? ""
    }
}

public enum AnonymousVote {
    public static let configURL = URL(string: "https://promptugal.news/assets/obs/obs.json")!
    /// One random id per app run, like the website's per-tab id.
    static let runID = UUID().uuidString.lowercased().prefix(12)

    /// The event, the website's `common()` fields that make sense in the app, plus the vote.
    public static func event(vote: Int, on path: String, at date: Date = .now, version: String, screen: String) -> [String: Any] {
        [
            "v": 1, "src": "promptugal", "site": "ios.app.promptugal.news", "ver": version,
            "ts": String(ISO8601DateFormatter().string(from: date).prefix(16)) + "Z",
            "sid": String(runID), "path": path, "ref": "", "lang": Locale.preferredLanguages.first ?? "",
            "screen": screen, "tz": TimeZone.current.identifier,
            "type": "vote", "vote": vote > 0 ? 1 : -1, "voted_on": String(path.prefix(200)),
        ]
    }

    /// Sends one vote; false when the lane is off, full or unreachable. Never throws to the UI.
    @discardableResult
    public static func send(vote: Int, on path: String) async -> Bool {
        do {
            let (data, _) = try await HTTPClient.shared.data(for: URLRequest(url: configURL), label: "obs.config")
            let config = try JSONDecoder().decode(ObsConfig.self, from: data)
            guard config.enabled, !config.siteLanes.isEmpty, let url = URL(string: "\(config.endpoint)/api/vault/append/write/\(config.vaultID)") else { return false }
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            let screen = await MainActor.run { UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "phone" }
            let text = try JSONSerialization.data(withJSONObject: event(vote: vote, on: path, version: version, screen: screen), options: [.sortedKeys])
            let payload = try seal(text, toPEM: config.recipientPEM)
            let start = Int.random(in: 0..<config.siteLanes.count)
            for i in 0..<config.siteLanes.count {
                let token = config.siteLanes[(start + i) % config.siteLanes.count]
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["append_token": token, "payload": payload])
                let (_, response) = try await HTTPClient.shared.data(for: request, label: "obs.vote")
                if response.statusCode != 507 { return (200..<300).contains(response.statusCode) }
            }
        } catch {}
        return false
    }

    /// The sgit hybrid envelope v2, as the lane takes it: base64(base64(JSON {v: 2, w, i, c})).
    public static func seal(_ plain: Data, toPEM pem: String) throws -> String {
        let key = try rsaPublicKey(pem: pem)
        let aes = SymmetricKey(size: .bits256)
        let box = try AES.GCM.seal(plain, using: aes)
        let raw = aes.withUnsafeBytes { Data($0) }
        var error: Unmanaged<CFError>?
        guard let wrapped = SecKeyCreateEncryptedData(key, .rsaEncryptionOAEPSHA256, raw as CFData, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        let envelope: [String: Any] = ["v": 2, "w": wrapped.base64EncodedString(), "i": Data(box.nonce).base64EncodedString(),
                                       "c": (box.ciphertext + box.tag).base64EncodedString()]
        let json = try JSONSerialization.data(withJSONObject: envelope)
        return Data(json.base64EncodedString().utf8).base64EncodedString()
    }

    /// An RSA public key from a PEM SubjectPublicKeyInfo (iOS wants the inner PKCS#1 key, so the SPKI wrapper is cut off).
    static func rsaPublicKey(pem: String) throws -> SecKey {
        let body = pem.components(separatedBy: "\n").filter { !$0.hasPrefix("-----") }.joined()
        guard let der = Data(base64Encoded: body) else { throw PersonKey.Failure.unreadable }
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
        for candidate in [pkcs1(fromSPKI: der), der].compactMap({ $0 }) {
            if let key = SecKeyCreateWithData(candidate as CFData, attributes as CFDictionary, nil) { return key }
        }
        throw PersonKey.Failure.unreadable
    }

    /// SEQUENCE { SEQUENCE algorithm, BIT STRING { 0x00, RSAPublicKey } } → RSAPublicKey.
    static func pkcs1(fromSPKI der: Data) -> Data? {
        let bytes = [UInt8](der)
        var i = 0
        func length() -> Int? {
            guard i < bytes.count else { return nil }
            let first = Int(bytes[i]); i += 1
            if first < 0x80 { return first }
            let count = first & 0x7F
            guard count > 0, count <= 4, i + count <= bytes.count else { return nil }
            var value = 0
            for _ in 0..<count { value = (value << 8) | Int(bytes[i]); i += 1 }
            return value
        }
        guard bytes.first == 0x30 else { return nil }
        i = 1
        guard length() != nil, i < bytes.count, bytes[i] == 0x30 else { return nil }
        i += 1
        guard let algorithm = length() else { return nil }
        i += algorithm
        guard i < bytes.count, bytes[i] == 0x03 else { return nil }
        i += 1
        guard let bits = length(), i < bytes.count, bytes[i] == 0x00, i + bits <= bytes.count else { return nil }
        return Data(bytes[(i + 1)..<(i + bits)])
    }
}
