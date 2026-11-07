import CryptoKit
import Foundation
import Security
import Testing
@testable import PrompTugal

/// sgit.ai's published subscribe key (public, from /.well-known/sgit-subscribe.json, 7 Nov 2026). Its fingerprint,
/// recomputed with sgit's own method in Python, is sha256:d85b358000612e4e.
private let sgitSubscribePEM = """
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAvBRtJE9HGPt8GKDflXc2
EQe55+z2U0xDGrsy9jA8KkN2EKr6xCArq66X5mAODoPZTwucsNoLX50JDBJfQBsi
TQU6MTFh1O5BLt8mucBvX50X3UOP3fxy+2UJmeIMGGNafGErV2C1wzuQi09JC6IM
hz4IdHa896SkjyzTzLOmanCj3NiDvOBFKtMcU9idAPJ3fyZtRCkPaalSo6P1wFBg
EWibODVkIh/iwU4Wl7nRIe2hTC3YK5yDkzyaT7Yk5e+OHYyB05GZ5f9sfwsqQ998
hYpLerkefS3s6lu+wyt5B2wJUNJrIvL/zhsHxCK6b7L8mjskhlSerrXwL9Z3OK9h
o4XjjJQ8jc0FrvKa9MmcvFXclJPvz1S0BBadRCot0wVHE5XjyR0C7GeI0yQ1cEvM
rY1Qgcm+xm+urLU4jVbGDzy7oR5DP9n5GdCWa8ue8aUN0JRUWNVfbBQCwEjHSYZO
/qepomzCrqlLWwb0IlZ6wNksM5jgy86AG4TdFLFulD4lutcj9fuQsFkFT8mseYI6
f8llkPX+BvXiyR94w/erohTwSAoe2P4BCcP3QGuPCKv6UQ1aEovnm6lTCe2vNCEc
pW3L4vrQ4trcq0CbmXSbEYudFBRBklfhzJIHaGPUUJB8mESb46EMazLlEzpKuiHH
fL+QmLQ2vl609Kx+xmff0QkCAwEAAQ==
-----END PUBLIC KEY-----
"""

/// Not a real lane token: the right shape only.
private let dummyToken = String(repeating: "ab", count: 32)

private func makeKeyPair(bits: Int = 2048) throws -> SecKey {
    let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: bits]
    var error: Unmanaged<CFError>?
    return try #require(SecKeyCreateRandomKey(attributes as CFDictionary, &error))
}

private func pem(of privateKey: SecKey) throws -> String {
    let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
    let pkcs1 = try #require(SecKeyCopyExternalRepresentation(publicKey, nil) as Data?)
    return LaneCrypto.pem(spki: LaneCrypto.spki(fromPKCS1: pkcs1))
}

@Suite("Lanes: keys and envelope")
struct LaneCryptoTests {
    @Test("Fingerprint of sgit.ai's published key matches sgit's")
    func fingerprint() throws {
        let der = try LaneCrypto.der(fromPEM: sgitSubscribePEM)
        #expect(der.count == 550)
        #expect(LaneCrypto.fingerprint(spki: der) == "sha256:d85b358000612e4e")
        _ = try LaneCrypto.publicKey(pem: sgitSubscribePEM)
    }

    @Test("SPKI wrap and unwrap are inverse")
    func spkiRoundTrip() throws {
        let der = try LaneCrypto.der(fromPEM: sgitSubscribePEM)
        let pkcs1 = try LaneCrypto.pkcs1(fromSPKI: der)
        #expect(LaneCrypto.spki(fromPKCS1: pkcs1) == der)
    }

    @Test("Encrypt to a public key, decrypt with its private key")
    func roundTrip() throws {
        let privateKey = try makeKeyPair()
        let recipient = try LaneCrypto.publicKey(pem: pem(of: privateKey))
        let message = Data("Olá, newsroom: the 11:50 session moved to Stage 2.".utf8)
        let enc = try LaneCrypto.encrypt(message, to: recipient)
        let json = try #require(Data(base64Encoded: enc))
        let envelope = try JSONDecoder().decode(LaneCrypto.Envelope.self, from: json)
        #expect(envelope.v == 2)
        #expect(Data(base64Encoded: envelope.i)?.count == 12)
        #expect(Data(base64Encoded: envelope.c)?.count == message.count + 16)
        #expect(Data(base64Encoded: envelope.w)?.count == 256)
        #expect(String(decoding: json, as: UTF8.self).hasPrefix("{\"v\": 2, \"w\": \""))
        #expect(try LaneCrypto.decrypt(enc, with: privateKey) == message)

        // Lane payloads are encoded twice; decoding once gives the .enc text back.
        let payload = LaneCrypto.lanePayload(encText: enc)
        #expect(try LaneCrypto.encText(fromLaneContent: payload) == enc)
    }

    @Test("Negative controls: wrong key, flipped byte, not an envelope")
    func negatives() throws {
        let privateKey = try makeKeyPair()
        let other = try makeKeyPair()
        let enc = try LaneCrypto.encrypt(Data("secret".utf8), to: LaneCrypto.publicKey(pem: pem(of: privateKey)))
        #expect(throws: LaneCrypto.Failure.self) { try LaneCrypto.decrypt(enc, with: other) }

        let json = try #require(Data(base64Encoded: enc))
        var envelope = try JSONDecoder().decode(LaneCrypto.Envelope.self, from: json)
        var box = try #require(Data(base64Encoded: envelope.c))
        box[0] ^= 0x01
        envelope = LaneCrypto.Envelope(v: 2, w: envelope.w, i: envelope.i, c: box.base64EncodedString())
        let tampered = try JSONEncoder().encode(envelope).base64EncodedString()
        #expect(throws: LaneCrypto.Failure.decrypt("AES-GCM")) { try LaneCrypto.decrypt(tampered, with: privateKey) }

        #expect(throws: LaneCrypto.Failure.badEnvelope) { try LaneCrypto.decrypt("bm90IGpzb24=", with: privateKey) }
        #expect(throws: LaneCrypto.Failure.badPEM) { try LaneCrypto.der(fromPEM: "hello") }
    }

    @Test("Negative control: a non-RSA key is refused")
    func notRSA() throws {
        let p256 = P256.Signing.PrivateKey().publicKey.derRepresentation
        #expect(throws: LaneCrypto.Failure.notRSA) { try LaneCrypto.pkcs1(fromSPKI: p256) }
    }
}

@Suite("Lanes: addresses and messages")
struct LaneAddressTests {
    private func subscribeFile(token: String = dummyToken, fingerprint: String = "sha256:d85b358000612e4e") -> Data {
        let object: [String: Any] = [
            "schema": "sgit-subscribe/v1",
            "recipient": ["address": "subscribe@sgit.ai", "fingerprint": fingerprint, "encrypt": sgitSubscribePEM],
            "inbox": ["vault": "y9j3nc60", "endpoint": "https://dev.send.sgraph.ai", "encrypt_to": fingerprint,
                      "lane": ["name": "subscribe", "append_token": token, "use": "one .eml per request"]],
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    @Test("Reads sgit-subscribe/v1 and checks the key")
    func parsesSubscribe() throws {
        let address = try LaneAddress.parse(subscribeFile())
        #expect(address.vault == "y9j3nc60")
        #expect(address.token == dummyToken)
        #expect(address.name == "subscribe@sgit.ai")
        #expect(address.writeURL.absoluteString == "https://dev.send.sgraph.ai/api/vault/append/write/y9j3nc60")
        let again = try LaneAddress.parse(address.descriptor())
        #expect(again == address)
    }

    @Test("Negative controls: wrong fingerprint, bad tokens")
    func rejects() {
        #expect(throws: LaneCrypto.Failure.fingerprintMismatch) { try LaneAddress.parse(subscribeFile(fingerprint: "sha256:0000000000000000")) }
        #expect(throws: LaneAddress.Failure.badToken) { try LaneAddress.parse(subscribeFile(token: "tok_" + dummyToken)) }
        #expect(throws: LaneAddress.Failure.badToken) { try LaneAddress.parse(subscribeFile(token: dummyToken.uppercased())) }
        #expect(throws: LaneAddress.Failure.badToken) { try LaneAddress.parse(subscribeFile(token: "abc")) }
        #expect(throws: LaneAddress.Failure.notJSON) { try LaneAddress.parse(Data("nope".utf8)) }
    }

    @Test("The write request carries the token and payload in the body only")
    func writeRequest() throws {
        let address = try LaneAddress.parse(subscribeFile())
        let request = try LaneClient.writeRequest(to: address, payload: "cGF5bG9hZA==")
        #expect(request.httpMethod == "POST")
        #expect(!(request.url?.absoluteString.contains(dummyToken) ?? true))
        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["append_token": dummyToken, "payload": "cGF5bG9hZA=="])
        #expect(LanesLog.describe(address).contains("abab…abab"))
        #expect(!LanesLog.describe(address).contains(dummyToken))
    }

    @Test("Header fields cannot add headers")
    func headerInjection() {
        let message = LaneMessage(from: "Dinis <d@x>", to: "Newsroom", subject: "Hi\r\nBcc: evil@example.com",
                                  kind: "note", body: "Line 1\nLine 2")
        let eml = message.eml()
        let headers = eml.components(separatedBy: "\r\n\r\n")[0]
        #expect(!headers.contains("\r\nBcc:"))
        #expect(headers.contains("Subject: Hi Bcc: evil@example.com"))
        #expect(eml.hasSuffix("Line 1\nLine 2"))
        #expect(headers.contains("Content-Type: text/plain; charset=utf-8"))
    }

    @Test("List and fetch responses are read loosely; file ids give the time")
    func listing() throws {
        let list = Data(#"{"entries":[{"file_id":"1762486800000_aaaaaaaaaaaaaaaaaaaaaaaa.enc","inbox":"t","size":10},{"file_id":"1762486700000_bbbbbbbbbbbbbbbbbbbbbbbb.enc"}]}"#.utf8)
        let entries = try LaneClient.entries(fromList: list)
        #expect(entries.map(\.fileId).first?.hasPrefix("1762486700000") == true)
        #expect(entries.last?.sentAt == Date(timeIntervalSince1970: 1_762_486_800))
        let fetched = LaneClient.contents(fromFetch: Data(#"{"files":[{"file_id":"a.enc","content":"Zm9v"}]}"#.utf8))
        #expect(fetched == ["a.enc": "Zm9v"])
        #expect(LaneClient.contents(fromFetch: Data("[]".utf8)).isEmpty)
    }

    @Test("Newsroom notes use the newsroom's record shape")
    func newsroomNote() throws {
        let note = try LanesStore.newsroomNote(kind: "idea", text: String(repeating: "a", count: 2_500), title: "Wire",
                                               path: "/wire/", device: "ios-1234", id: "n1")
        #expect(note.path == "notes/n1.json")
        let object = try #require(try JSONSerialization.jsonObject(with: note.data) as? [String: Any])
        for field in ["id", "at", "kind", "path", "title", "n", "story", "text", "quote", "persona", "device", "sent_at"] {
            #expect(object.keys.contains(field), "missing \(field)")
        }
        #expect((object["text"] as? String)?.count == 2_000)
        #expect(object["n"] is NSNull)
    }
}
