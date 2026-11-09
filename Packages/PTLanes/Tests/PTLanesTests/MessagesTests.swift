import CryptoKit
import Foundation
import Security
import Testing
@testable import PTLanes

// Team messaging v1 (WS-203): the formats, the envelope, the five opening rules, a known-answer vector made by the
// team site's reference (admin/tools/messages.mjs), and two stores talking through an in-memory post office.
// Every key here is made for the test, or is the vector's test-only key, and protects nothing.

private struct Person {
    let name: String
    let agree = P256.KeyAgreement.PrivateKey()
    let sign = P256.Signing.PrivateKey()
    var identity: MessageIdentity { .software(name: name, agreement: agree, signing: sign) }
    var entry: [String: Any] {
        ["person": name, "status": "active",
         "fingerprint": MessageCrypto.fingerprint(agree.publicKey), "signing_fingerprint": MessageCrypto.fingerprint(sign.publicKey),
         "encrypt": MessagingDevice.jwkDict(agree.publicKey.x963Representation), "sign": MessagingDevice.jwkDict(sign.publicKey.x963Representation)]
    }
}

private struct Agent {
    let name: String
    let rsa: SecKey
    let sign = P256.Signing.PrivateKey()
    init(name: String) throws {
        self.name = name
        var error: Unmanaged<CFError>?
        guard let k = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        rsa = k
    }
    var spki: Data { LaneCrypto.spki(fromPKCS1: SecKeyCopyExternalRepresentation(SecKeyCopyPublicKey(rsa)!, nil)! as Data) }
    var identity: MessageIdentity {
        let s = sign
        return MessageIdentity(name: name, fingerprint: LaneCrypto.fingerprint(spki: spki), signingFingerprint: MessageCrypto.fingerprint(s.publicKey),
                               agree: { _ in throw MessageCrypto.Refusal.cannotOpen("agents read RSA") },
                               sign: { try s.signature(for: $0).rawRepresentation }, rsa: rsa)
    }
    var entry: [String: Any] {
        ["id": "test-agent", "agent": name, "status": "active",
         "bundle": ["encrypt": LaneCrypto.pem(spki: spki), "sign": sign.publicKey.pemRepresentation,
                    "fingerprint": LaneCrypto.fingerprint(spki: spki), "signing_fingerprint": MessageCrypto.fingerprint(sign.publicKey)]]
    }
}

private func directory(people: [Person], agents: [Agent] = []) throws -> MessageDirectory {
    MessageDirectory(agents: try JSONSerialization.data(withJSONObject: ["keys": agents.map(\.entry)]),
                     people: try JSONSerialization.data(withJSONObject: ["keys": people.map(\.entry)]), devices: nil)
}

@Suite("Team messaging")
struct MessagesTests {
    @Test func chatRoundTripsThroughJSON() throws {
        let m = ChatMessage(thread: MessageThread.direct(["jose", "indi"]), from: "indi", to: ["jose"], text: "On my way")
        #expect(m.thread == "dm:indi+jose")
        let back = try TeamMessage.decode(try TeamMessage.chat(m).encoded())
        #expect(back == .chat(m))
    }

    @Test func emailCardHashesItsEML() throws {
        let e = EmailMessage(thread: "mail:t", from: "indi", to: ["vicky"], subject: "Tomorrow", text: "Three companies.")
        #expect(e.card.sha256 == MessageCrypto.sha256Hex(Data(e.eml.utf8)))
        #expect(e.body == "Three companies.")
        #expect(e.eml.contains("\r\nSubject: Tomorrow\r\n"))
    }

    @Test func unknownFormatAndKindAreRefused() {
        #expect(throws: (any Error).self) { try TeamMessage.decode(Data(#"{"format":"messaging-fs/9"}"#.utf8)) }
        let bad = #"{"format":"messaging-fs/1","id":"1","thread":"t","from":"a","to":["b"],"at":"x","kind":"virus","text":"","attachments":[]}"#
        #expect(throws: (any Error).self) { try TeamMessage.decode(Data(bad.utf8)) }
    }

    @Test func personToPersonOpensAndVerifies() throws {
        let indi = Person(name: "indi"), jose = Person(name: "jose")
        let dir = try directory(people: [indi, jose])
        let m = TeamMessage.chat(ChatMessage(thread: "dm:indi+jose", from: "indi", to: ["jose"], text: "Bring the charger"))
        let env = try MessageCrypto.seal(m, to: dir.readers(of: "jose") + dir.readers(of: "indi"), as: indi.identity)
        #expect(try MessageCrypto.open(env, as: jose.identity, signer: dir.signer) == m)
        #expect(try MessageCrypto.open(env, as: indi.identity, signer: dir.signer) == m)   // the sender's own copy
    }

    @Test func personToAgentAndBackUsesRSA() throws {
        let indi = Person(name: "indi"), agent = try Agent(name: "conductor@web-summit.indi")
        let dir = try directory(people: [indi], agents: [agent])
        #expect(dir.readers(of: agent.name).count == 1)
        let ask = TeamMessage.chat(ChatMessage(thread: "dm:x", from: "indi", to: [agent.name], text: "Add the reprint"))
        #expect(try MessageCrypto.open(try MessageCrypto.seal(ask, to: dir.readers(of: agent.name), as: indi.identity), as: agent.identity, signer: dir.signer) == ask)
        let reply = TeamMessage.email(EmailMessage(thread: "mail:x", from: agent.name, to: ["indi"], subject: "Added", text: "On the 12:00 agenda."))
        #expect(try MessageCrypto.open(try MessageCrypto.seal(reply, to: dir.readers(of: "indi"), as: agent.identity), as: indi.identity, signer: dir.signer) == reply)
    }

    @Test func everyRefusalHolds() throws {
        let indi = Person(name: "indi"), jose = Person(name: "jose"), stranger = Person(name: "stranger")
        let dir = try directory(people: [indi, jose])
        let m = TeamMessage.chat(ChatMessage(thread: "dm:indi+jose", from: "indi", to: ["jose"], text: "Hello"))
        let env = try MessageCrypto.seal(m, to: dir.readers(of: "jose"), as: indi.identity)

        var changed = env
        var ct = Data(base64Encoded: changed.ct)!
        ct[2] ^= 1
        changed.ct = ct.base64EncodedString()
        #expect(throws: MessageCrypto.Refusal.badSignature) { try MessageCrypto.open(changed, as: jose.identity, signer: dir.signer) }

        var fewer = env
        fewer.recipients.append(fewer.recipients[0])
        #expect(throws: MessageCrypto.Refusal.badSignature) { try MessageCrypto.open(fewer, as: jose.identity, signer: dir.signer) }

        let liar = TeamMessage.chat(ChatMessage(thread: "dm:indi+jose", from: "indi", to: ["jose"], text: "I am Indi"))
        let forged = try MessageCrypto.seal(liar, to: dir.readers(of: "jose"), as: jose.identity)
        #expect(throws: MessageCrypto.Refusal.fromIsNotSigner(from: "indi", signer: "jose")) { try MessageCrypto.open(forged, as: jose.identity, signer: dir.signer) }

        let unknown = try MessageCrypto.seal(m, to: dir.readers(of: "jose"), as: stranger.identity)
        #expect(throws: MessageCrypto.Refusal.unknownSigner(stranger.identity.signingFingerprint)) { try MessageCrypto.open(unknown, as: jose.identity, signer: dir.signer) }

        #expect(throws: MessageCrypto.Refusal.notSealedToMe) { try MessageCrypto.open(env, as: indi.identity, signer: dir.signer) }
    }

    /// Made by the team site's admin/tools/messages.mjs (Node): the same bytes must open here.
    @Test func opensTheReferenceVector() throws {
        struct Vector: Decodable { var reader_agree_d: String; var envelope: MessageEnvelope; var expect_text: String; var expect_id: String }
        let json = Data(knownAnswerVector.utf8)
        let v = try JSONDecoder().decode(Vector.self, from: json)
        let peopleJSON = try JSONSerialization.data(withJSONObject: (try JSONSerialization.jsonObject(with: json) as! [String: Any])["people"]!)
        let dir = MessageDirectory(agents: nil, people: peopleJSON, devices: nil)
        let agree = try P256.KeyAgreement.PrivateKey(rawRepresentation: MessageCrypto.unbase64url(v.reader_agree_d)!)
        let reader = MessageIdentity(name: "kat-reader", fingerprint: MessageCrypto.fingerprint(agree.publicKey), signingFingerprint: "",
                                     agree: { try agree.sharedSecretFromKeyAgreement(with: $0) }, sign: { _ in Data() })
        let m = try MessageCrypto.open(v.envelope, as: reader, signer: dir.signer)
        guard case .chat(let chat) = m else { Issue.record("not a chat"); return }
        #expect(chat.text == v.expect_text)
        #expect(chat.id == v.expect_id)
    }

    @MainActor
    @Test func twoStoresTalkThroughThePostOffice() async throws {
        let indi = Person(name: "indi"), jose = Person(name: "jose")
        let dir = try directory(people: [indi, jose])
        let office = MemoryPostOffice()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let a = MessageStore(me: "indi", transport: MemoryTransport(office: office, me: "indi"), folder: tmp.appendingPathComponent("a"),
                             identity: { indi.identity }, directory: dir)
        let b = MessageStore(me: "jose", transport: MemoryTransport(office: office, me: "jose"), folder: tmp.appendingPathComponent("b"),
                             identity: { jose.identity }, directory: dir)
        try await a.send(text: "Can you cover 15:00?", to: ["jose"])
        await b.poll()
        #expect(b.threads.count == 1)
        #expect(b.unreadTotal == 1)
        #expect(b.messages(in: "dm:indi+jose").first?.preview == "Can you cover 15:00?")
        b.markRead("dm:indi+jose")
        #expect(b.unreadTotal == 0)
        await b.poll()    // processed: nothing new
        #expect(b.messages(in: "dm:indi+jose").count == 1)
        // a store reloaded from disk keeps the message
        let again = MessageStore(me: "jose", transport: MemoryTransport(office: office, me: "jose"), folder: tmp.appendingPathComponent("b"),
                                 identity: { jose.identity }, directory: dir)
        #expect(again.messages(in: "dm:indi+jose").count == 1)
        try? FileManager.default.removeItem(at: tmp)
    }

    @MainActor
    @Test func notSwitchedOnSaysSo() async {
        let s = MessageStore(me: "indi", transport: NotSwitchedOnTransport(), folder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                             identity: { Person(name: "indi").identity })
        await s.poll()
        guard case .notSwitchedOn = s.status else { Issue.record("expected notSwitchedOn"); return }
        await #expect(throws: MessageTransportFailure.self) { try await s.send(text: "hi", to: ["jose"]) }
    }
}

/// Test-only keys, made once by admin/tools/messages.mjs for this vector. They protect nothing.
private let knownAnswerVector = #"""
{"about":"Test-only keys made once for this known-answer test. They protect nothing and are used nowhere else.","people":{"keys":[{"person":"kat-reader","status":"active","fingerprint":"sha256:fd4b7375a28501bc","signing_fingerprint":"sha256:c251ededfa577726","encrypt":{"kty":"EC","crv":"P-256","x":"G6ZAtXH31G7zY5ZVZN359HOIbp9hjaoF6ip6Nx4Awqc","y":"PppAlOK6BTPGr9jQHXU585ijbgCzer2prBUXq3ap_cs"},"sign":{"kty":"EC","crv":"P-256","x":"6TPAAI5rX4wd2T9uC_RPn_ags8zls5Tgn-z6hvK6RuY","y":"MwGJpupIqVup6dO8M2K3GkQsLsTAcBRVFEsiikl5pBs"}},{"person":"kat-sender","status":"active","fingerprint":"sha256:bbccbe1308c21553","signing_fingerprint":"sha256:24479848cef51ef2","encrypt":{"kty":"EC","crv":"P-256","x":"e1AMxacnR3eDGEuwe-VLv8Ivfi9hL7ZiyXJ75WNKfF8","y":"10x60VW230BYFykujpPwJmCR9Vg1PaUiQZbJyeGniPg"},"sign":{"kty":"EC","crv":"P-256","x":"dE36115-JjzwjwsNZ1Ymup2pslMeaAHQP17_tIAqhis","y":"WKeg8hZzTz7SpzaI2K8UQrXOS-ZEhilSsbXrYyIXRXc"}}]},"reader_agree_d":"rvRD4ZqEo_8Brh9AKfyYttEBBlDqjktZG7Vqt-D5tFY","envelope":{"v":"ws-msg-env-1","id":"718e4162-176f-4b8f-bd62-d0dca21f3635","thread":"dm:kat-reader+kat-sender","recipients":[{"to":"kat-reader","key":"sha256:fd4b7375a28501bc","env":{"v":"ws-ecies-1","epk":{"kty":"EC","crv":"P-256","x":"y2Rotqcf3NR4yB7fvREWsksC-dpQa5XShWS49vUARJU","y":"UrcQd4cjGIYmjhhhksYbDrvJC6uW_VqHahpIrbuKp0E"},"iv":"vsdF5Gt8NXnerW6v","ct":"B+rULB0Ryp2tjQMx0Oul2mnMr6F1D973jf5D+4hIydyI1nqUafdghYZyM7y1WvjzijKS6hjQd0Zt2tOEioSlQ4/yRHGXyw=="}}],"iv":"N7MSYmqGcW034yJv","ct":"+8A75KVQP2NLafUBgbOT12Mr+ncz4zo7JqWsxKc7wJ9PsDwXM5ec8FAntRU9soBiJWLlJKm/OvTQfnYe252DcwFrvFqsz8Vmm7X6+uvkMeaSjQaI7S9s2NZeOxieAPAv4f4BjPw8ot+CwuJlcIVA8ubaZ444BWiII1SwZjtZfydCaQnRqG0F/MakHJA8RAp97CIF928Frm1I7YX4/LJdegCrAHXyEmdK6WC46kTrVx3IRhbmdvB7CYUJXZbsYlw4abIPLJPv9Yk1gVViiWt2RHvZYr3qptelelc7LtIorSpWSqj5eHypKQFFSP/Viv/z5XR6aygCypfCj+19tQMFcL8iYGaiUWr1WIcg4gMTNSBdTzXwvPTJXzrUy3WCbGM=","by":"sha256:24479848cef51ef2","sig":"PUB1Pozcfi2IQCOsNVMsBvdW3b+WP4oplx1MwgC73RHaL5OejVPHJMuX9QadSVAeFZ5i++NW/YM80ImVjkNtlQ=="},"expect_text":"Known answer: the stand opens at 09:00.","expect_id":"718e4162-176f-4b8f-bd62-d0dca21f3635"}
"""#
