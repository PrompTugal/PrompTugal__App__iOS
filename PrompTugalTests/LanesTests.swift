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

@Suite("Lanes: the website's inbox formats")
struct NewsroomInboxTests {
    private func spki(of privateKey: SecKey) throws -> Data {
        let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
        let pkcs1 = try #require(SecKeyCopyExternalRepresentation(publicKey, nil) as Data?)
        return LaneCrypto.spki(fromPKCS1: pkcs1)
    }

    private func pkcs8(of privateKey: SecKey) throws -> Data {
        let pkcs1 = try #require(SecKeyCopyExternalRepresentation(privateKey, nil) as Data?)
        let algorithm: [UInt8] = [0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00]
        let body = [0x02, 0x01, 0x00] + algorithm + DERReader.encode(tag: 0x04, Array(pkcs1))
        return Data(DERReader.encode(tag: 0x30, body))
    }

    @Test("An sgi1 link is a lane to a newsroom inbox, inside a URL or alone")
    func link() throws {
        let key = try makeKeyPair()
        let der = try spki(of: key)
        let b64url = der.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let code = "sgi1.abcd1234.\(dummyToken).\(b64url)"
        let address = try #require(LaneAddress.parseInboxLink("https://newsroom.sgit.ai/vault/send.html#\(code)"))
        #expect(address.vault == "abcd1234" && address.token == dummyToken)
        #expect(address.isNewsroomInbox)
        #expect(address.fingerprint == LaneCrypto.fingerprint(spki: der))
        #expect(try LaneAddress.parse(Data(code.utf8)).isNewsroomInbox)
        // Negative controls: an upper-case token, a truncated key.
        #expect(LaneAddress.parseInboxLink("sgi1.abcd1234.\(dummyToken.uppercased()).\(b64url)") == nil)
        #expect(LaneAddress.parseInboxLink("sgi1.abcd1234.\(dummyToken).\(b64url.prefix(150))") == nil)
    }

    @Test("A website inbox record opens with its PKCS#8 key, and decrypts what was sealed to it")
    func record() throws {
        let key = try makeKeyPair()
        let object: [String: Any] = ["v": 1, "vault": "abcd1234", "endpoint": "https://dev.send.sgraph.ai", "token": dummyToken,
                                     "enum_key": "e" + String(repeating: "0", count: 63),
                                     "public": try spki(of: key).base64EncodedString(), "private": try pkcs8(of: key).base64EncodedString()]
        let (address, enumKey, privateKey) = try LanesStore.inboxRecord(JSONSerialization.data(withJSONObject: object))
        #expect(address.vault == "abcd1234" && enumKey.count == 64)
        let note = LanesStore.newsroomNoteObject(kind: "idea", text: "Meet at Stage 2", title: nil, path: nil, device: "ios-1", id: "n1")
        let message = try LaneAddress.newsroomInboxMessage(note: note, to: address.fingerprint, device: "ios-1")
        let enc = try LaneCrypto.encrypt(message, to: LaneCrypto.publicKey(pem: address.publicKeyPEM))
        let plain = try LaneCrypto.decrypt(enc, with: privateKey)
        let decoded = try #require(try JSONSerialization.jsonObject(with: plain) as? [String: Any])
        #expect(decoded["kind"] as? String == "sgit-newsroom-inbox/v1")
        #expect(decoded["to"] as? String == address.fingerprint)
        let file = try #require(decoded["file"] as? [String: Any])
        #expect(file["v"] as? Int == 1)
        #expect((file["device"] as? [String: Any])?["id"] as? String == "ios-1")
        #expect(LanesStore.readable(plain).contains("• idea: Meet at Stage 2"))
        // Negative control: a record without its private key.
        var broken = object
        broken["private"] = nil
        #expect(throws: (any Error).self) { try LanesStore.inboxRecord(JSONSerialization.data(withJSONObject: broken)) }
    }
}

@Suite("Team notes through vaults")
struct TeamNoteTests {
    @Test("A note round-trips; source is not stored")
    func roundTrip() throws {
        var note = TeamNote.make(kind: "note", text: "Lunch at the FIL food court, 13:30", from: CollabIdentity(id: "dinis", name: "Dinis"), about: "ai-doom-or-boom")
        note.source = "me"
        let data = try note.encoded()
        #expect(!String(decoding: data, as: UTF8.self).contains("\"source\""))
        let back = try #require(TeamNote.decode(data, source: "abcd1234"))
        #expect(back.text == note.text && back.from == "dinis" && back.about == "ai-doom-or-boom")
        #expect(back.source == "abcd1234")
        #expect(back.date != nil)
    }

    @Test("Negative controls: other schemas, empty text and bad JSON are ignored")
    func rejects() {
        #expect(TeamNote.decode(Data(#"{"schema":"other/v1","id":"1","at":"x","kind":"n","text":"t","from":"a","from_name":"A"}"#.utf8), source: "x") == nil)
        #expect(TeamNote.decode(Data(#"{"schema":"promptugal-team-note/v1","id":"1","at":"x","kind":"n","text":"","from":"a","from_name":"A"}"#.utf8), source: "x") == nil)
        #expect(TeamNote.decode(Data("nope".utf8), source: "x") == nil)
    }

    @Test("Merge: newest first, one per id, capped")
    func merge() {
        func note(_ id: String, _ at: String) -> TeamNote {
            TeamNote(id: id, at: at, kind: "note", text: id, from: "a", fromName: "A")
        }
        let merged = TeamNote.merge([note("a", "2026-11-10T09:00:00.000Z"), note("b", "2026-11-10T10:00:00.000Z"),
                                     note("a", "2026-11-10T09:00:00.000Z")], limit: 5)
        #expect(merged.map(\.id) == ["b", "a"])
        #expect(TeamNote.merge((0..<10).map { note("\($0)", "2026-11-10T09:0\($0):00.000Z") }, limit: 3).count == 3)
    }
}
