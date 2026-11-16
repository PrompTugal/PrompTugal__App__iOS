import CryptoKit
import Foundation
import Security
import Testing
@testable import PTTalk
import PTLanes

private func makeKeyPair(bits: Int = 2048) throws -> SecKey {
    let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: bits]
    var error: Unmanaged<CFError>?
    return try #require(SecKeyCreateRandomKey(attributes as CFDictionary, &error))
}

/// A lane link for a fresh key pair (not a real lane: the right shape only).
private func makeLane() throws -> (lane: SealedLane, privateKey: SecKey, link: String) {
    let key = try makeKeyPair()
    let publicKey = try #require(SecKeyCopyPublicKey(key))
    let spki = try #require(SealedLane.spki(of: publicKey))
    let link = SealedLane.link(vault: "testvault", token: String(repeating: "ab", count: 24), spki: spki)
    return (try #require(SealedLane.parse(link)), key, link)
}

@Suite struct WireTests {
    @Test func partsSplitAtTheSizeAndJoinBack() {
        let data = Data((0..<10_001).map { UInt8($0 % 251) })
        let parts = TalkWire.parts(of: data, size: 1_000)
        #expect(parts.count == 11)
        #expect(parts.dropLast().allSatisfy { $0.count == 1_000 })
        #expect(parts.last?.count == 1)
        #expect(parts.reduce(Data(), +) == data)
        #expect(TalkWire.parts(of: Data(), size: 1_000).isEmpty)
        #expect(TalkWire.parts(of: data, size: 0).isEmpty)
        #expect(TalkWire.parts(of: Data(repeating: 1, count: 2_000), size: 1_000).count == 2)
    }

    @Test func partsOfASliceKeepTheirOwnIndices() {
        let whole = Data((0..<100).map { UInt8($0) })
        let slice = whole[10..<50]
        #expect(TalkWire.parts(of: slice, size: 7).reduce(Data(), +) == slice)
    }

    @Test func aMessageIsOneHeaderLineThenTheBytes() throws {
        let header = TalkWire.Header(kind: TalkWire.Kind.text.rawValue, note: "n1", part: 1, of: 1, name: "message.txt",
                                     size: 3, sha256: TalkWire.sha256Hex(Data("a\nb".utf8)), app: "test", sentAt: "2026-11-16T00:00:00Z")
        let message = try TalkWire.message(header: header, body: Data("a\nb".utf8))
        let text = String(decoding: message, as: UTF8.self)
        let firstLine = try #require(text.split(separator: "\n", maxSplits: 1).first)
        #expect(firstLine.hasPrefix("{\"app\":\"test\""))     // sorted keys, one line
        #expect(!firstLine.contains("\\/"))
        let (back, body) = try TalkWire.split(message)
        #expect(back == header)
        #expect(body == Data("a\nb".utf8))                      // newlines in the body survive
    }

    @Test func splitRefusesAMessageWithoutAHeader() {
        #expect(throws: TalkWire.Failure.noHeader) { try TalkWire.split(Data("no newline".utf8)) }
    }

    @Test func anItemIsMetaThenTextThenEachFileInParts() throws {
        let picture = Data((0..<2_500).map { UInt8($0 % 256) })
        let messages = try TalkWire.messages(item: "draft-loule-1", purpose: .draft, to: "conductor", town: "loule", townName: "Loulé",
                                             title: "Market", text: "  The market on Saturday  \n", attachments: [.init(kind: .image, name: "photo.jpg", data: picture)],
                                             app: "test", at: Date(timeIntervalSince1970: 0), partSize: 1_000)
        #expect(messages.count == 1 + 1 + 3)
        let headers = try messages.map { try TalkWire.split($0).header }
        #expect(headers.map(\.kind) == [TalkWire.Kind.meta, .text, .image, .image, .image].map(\.rawValue))
        #expect(headers.allSatisfy { $0.note == "draft-loule-1" && $0.sentAt == "1970-01-01T00:00:00Z" })
        #expect(headers[2...].map(\.part) == [1, 2, 3])
        #expect(headers[2...].allSatisfy { $0.of == 3 && $0.size == 2_500 && $0.sha256 == TalkWire.sha256Hex(picture) })

        let (meta, files) = try TalkWire.reassemble(messages.shuffled())
        let m = try #require(meta)
        #expect(m.schema == "promptugal-talk/v1")
        #expect(m.purpose == .draft && m.needsApproval)
        #expect(m.town == "loule" && m.townName == "Loulé" && m.title == "Market")
        #expect(m.text == "The market on Saturday")
        #expect(m.files.map(\.name) == ["message.txt", "photo.jpg"])
        #expect(m.files.map(\.parts) == [1, 3])
        #expect(files["photo.jpg"] == picture)
        #expect(files["message.txt"] == Data("The market on Saturday".utf8))
    }

    @Test func aConductorNoteNeedsNoApprovalAndMayBeTextOnly() throws {
        let messages = try TalkWire.messages(item: "c1", purpose: .conductor, to: "conductor", text: "Fix the header", app: "t")
        #expect(messages.count == 2)
        let meta = try #require(try TalkWire.reassemble(messages).meta)
        #expect(!meta.needsApproval)
        #expect(meta.town == nil)
    }

    @Test func nothingToSendIsRefused() {
        #expect(throws: TalkWire.Failure.empty) {
            try TalkWire.messages(item: "x", purpose: .conductor, to: "conductor", text: "  \n ", attachments: [.init(kind: .image, name: "a.jpg", data: Data())], app: "t")
        }
    }

    @Test func aMissingPartLeavesTheFileOut() throws {
        let data = Data(repeating: 7, count: 3_000)
        var messages = try TalkWire.messages(item: "x", purpose: .conductor, to: "conductor", text: "",
                                             attachments: [.init(kind: .video, name: "v.mp4", data: data)], app: "t", partSize: 1_000)
        messages.remove(at: 2)
        let (_, files) = try TalkWire.reassemble(messages)
        #expect(files["v.mp4"] == nil)
        #expect(files["meta.json"] != nil)
    }

    @Test func aRealSizedFileStaysUnderTheLaneLimitPerMessage() throws {
        let data = Data(repeating: 1, count: 5_000_000)
        let messages = try TalkWire.messages(item: "x", purpose: .draft, to: "conductor", text: "big", attachments: [.init(kind: .video, name: "v.mp4", data: data)], app: "t")
        #expect(messages.count == 1 + 1 + 3)
        // Sealed and encoded twice is about 1.8 times the message; the lane refuses a payload over 5 MB.
        #expect(messages.allSatisfy { Double($0.count) * 1.8 < 5_000_000 })
    }

    @Test func namesAreSafeForAFolder() {
        #expect(TalkWire.safeName("../../etc/passwd") == "-..-etc-passwd")
        #expect(TalkWire.safeName(".hidden") == "hidden")
        #expect(TalkWire.safeName("Loulé photo.jpg") == "Loul--photo.jpg")
        #expect(TalkWire.safeName("") == "file")
        #expect(TalkWire.Attachment(kind: .image, name: "a/b.jpg", data: Data()).name == "a-b.jpg")
        let id = TalkWire.itemId(purpose: .draft, town: "vila-do-bispo", at: Date(timeIntervalSince1970: 0))
        #expect(id.hasPrefix("draft-vila-do-bispo-19700101-000000-"))
        #expect(TalkWire.safeName(id) == id)
    }

    @Test func kindsAreFiledByConductorPy() {
        // conductor.py drain files kinds that start with voicedebrief/ or sgit/; anything else is dropped.
        #expect(TalkWire.Kind.allCases.allSatisfy { $0.rawValue.hasPrefix("sgit/") })
    }
}

@Suite struct SealTests {
    @Test func aLinkParsesAndAMessageSealsAndOpens() throws {
        let (lane, key, link) = try makeLane()
        #expect(lane.vault == "testvault")
        #expect(lane.fingerprint.hasPrefix("sha256:"))
        #expect(SealedLane.parse("see https://example/send.html#\(link) please") == lane)
        #expect(SealedLane.parse("sgi1.nope") == nil)

        let message = try TalkWire.messages(item: "c1", purpose: .conductor, to: "conductor", text: "hello", app: "t")[1]
        let payload = try lane.seal(message)
        #expect(try SealedLane.open(payload: payload, with: key) == message)

        let request = try lane.writeRequest(payload: payload)
        #expect(request.url?.absoluteString == "https://dev.send.sgraph.ai/api/vault/append/write/testvault")
        #expect(request.httpMethod == "POST")
        let httpBody = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: httpBody) as? [String: String])
        #expect(body["append_token"] == String(repeating: "ab", count: 24))
        #expect(body["payload"] == payload)
    }
}

/// Records what was written; refuses the writes whose index is in `failAt` (once each).
private final class FakeTransport: LaneTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var failAt: Set<Int>
    private(set) var written: [String] = []
    private var calls = 0
    init(failAt: Set<Int> = []) { self.failAt = failAt }
    func write(_ request: URLRequest) async throws -> Int {
        lock.lock(); defer { lock.unlock() }
        calls += 1
        if failAt.remove(calls) != nil { return 503 }
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String]
        written.append(body?["payload"] ?? "")
        return 200
    }
}

@Suite struct WriterTests {
    @Test func writesEveryMessageInOrder() async throws {
        let (lane, key, _) = try makeLane()
        let messages = (1...3).map { Data("m\($0)".utf8) }
        let transport = FakeTransport()
        try await LaneWriter(transport: transport).write(messages, to: lane) { _, _ in }
        #expect(try transport.written.map { try SealedLane.open(payload: $0, with: key) } == messages)
    }

    @Test func aRefusalSaysHowManyWereWrittenAndAResumeFinishes() async throws {
        let (lane, key, _) = try makeLane()
        let messages = (1...4).map { Data("m\($0)".utf8) }
        let transport = FakeTransport(failAt: [3])
        let writer = LaneWriter(transport: transport)
        var written = 0
        do {
            try await writer.write(messages, to: lane) { _, _ in }
            Issue.record("expected a refusal")
        } catch let stopped as LaneWriter.Stopped {
            written = stopped.written
            #expect(stopped.underlying as? TalkSendError == .refused(503))
        }
        #expect(written == 2)
        try await writer.write(messages, to: lane, from: written) { _, _ in }
        #expect(try transport.written.map { try SealedLane.open(payload: $0, with: key) } == messages)
    }

    @Test func retryWaitsAreThoseOfVoiceDebrief() {
        #expect(TalkRetry.wait(before: 2) == 10)
        #expect(TalkRetry.wait(before: 5) == 120)
        #expect(TalkRetry.wait(before: 6) == nil)
    }
}

@Suite @MainActor struct StoreTests {
    @Test func lanesKeepOnlyValidLinks() throws {
        let store = MemoryLinkStore()
        let lanes = TalkLanes(store: store)
        #expect(lanes.conductor == nil)
        #expect(!lanes.setConductor("not a link"))
        let (_, _, link) = try makeLane()
        #expect(lanes.setConductor("  \(link)\n"))
        #expect(lanes.conductor?.vault == "testvault")
        #expect(store.load() == link)
        #expect(TalkLanes(store: store).conductor?.vault == "testvault")
        lanes.forgetAll()
        #expect(lanes.conductor == nil && store.load() == nil)
    }

    @Test func historyPersists() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pttalk-\(UUID().uuidString).json")
        let history = TalkHistory(file: file)
        history.add(.init(id: "a", purpose: .conductor, town: nil, text: "hi", files: [], status: .sent, at: .now))
        history.add(.init(id: "b", purpose: .draft, town: "loule", text: "d", files: ["photo.jpg"], status: .failed, at: .now))
        let back = TalkHistory(file: file)
        #expect(back.records(.conductor).map(\.id) == ["a"])
        #expect(back.records(.draft).first?.status == .failed)
        back.clear()
        #expect(TalkHistory(file: file).records.isEmpty)
    }
}


@Suite struct SigningTests {
    @Test func everyMessageIsSignedAndVerifies() throws {
        let key = P256.Signing.PrivateKey()
        let signer = TalkWire.Signer(key: key)
        let messages = try TalkWire.messages(item: "draft-faro-1", purpose: .draft, to: "conductor", town: "faro", text: "A line",
                                             attachments: [.init(kind: .image, name: "photo.jpg", data: Data(repeating: 3, count: 2_500))],
                                             app: "t", partSize: 1_000, signer: signer)
        #expect(signer.fingerprint.hasPrefix("sha256:") && signer.fingerprint.count == 23)
        for message in messages {
            let (header, body) = try TalkWire.split(message)
            #expect(header.isSigned)
            #expect(TalkWire.verify(header: header, body: body) == .signed(by: signer.fingerprint))
        }
        #expect(try TalkWire.reassemble(messages).meta?.by == signer.fingerprint)
    }

    @Test func aChangedBodyOrHeaderFailsAndUnsignedIsUnsigned() throws {
        let signer = TalkWire.Signer(key: P256.Signing.PrivateKey())
        let messages = try TalkWire.messages(item: "c1", purpose: .conductor, to: "conductor", text: "Fix it", app: "t", signer: signer)
        let (header, body) = try TalkWire.split(messages[1])
        #expect(TalkWire.verify(header: header, body: Data("Fix nothing".utf8)) == .invalid)
        var moved = header
        moved.note = "c2"
        #expect(TalkWire.verify(header: moved, body: body) == .invalid)
        var otherKey = header
        otherKey.key = TalkWire.Signer(key: P256.Signing.PrivateKey()).publicKeyBase64
        #expect(TalkWire.verify(header: otherKey, body: body) == .invalid)

        let plain = try TalkWire.messages(item: "c1", purpose: .conductor, to: "conductor", text: "Fix it", app: "t")
        let (unsigned, unsignedBody) = try TalkWire.split(plain[1])
        #expect(!unsigned.isSigned)
        #expect(TalkWire.verify(header: unsigned, body: unsignedBody) == .unsigned)
        #expect(!String(decoding: plain[1], as: UTF8.self).contains("\"sig\""))
    }

    @Test func theSignatureIsRawRSOverSHA256OfTheSignedText() throws {
        let key = P256.Signing.PrivateKey()
        let messages = try TalkWire.messages(item: "c1", purpose: .conductor, to: "conductor", text: "x", app: "t",
                                             signer: TalkWire.Signer(key: key))
        let (header, body) = try TalkWire.split(messages[0])
        let sigText = try #require(header.sig)
        let sig = try #require(Data(base64Encoded: sigText))
        #expect(sig.count == 64)
        let text = String(decoding: header.signedText(body: body), as: UTF8.self)
        #expect(text.split(separator: "\n").count == 9)
        #expect(text.hasPrefix("sgit/talk/meta/v1\nc1\n1\n1\nmeta.json\n"))
        #expect(key.publicKey.isValidSignature(try P256.Signing.ECDSASignature(rawRepresentation: sig), for: header.signedText(body: body)))
    }
}

@Suite struct TransportTests {
    @Test func sendSignsSealsAndWritesThePayload() async throws {
        let (_, privateKey, link) = try makeLane()
        let fake = FakeTransport()
        let transport = TalkTransport(link: { link }, transport: fake, retry: false, app: "t")
        #expect(await transport.isConnected())
        let person = P256.Signing.PrivateKey()
        let payload = Data(#"{"kind":"promptugal/comment/v1","place":"loule","text":"Nice"}"#.utf8)
        try await transport.send(payload, signedBy: person)

        let messages = try fake.written.map { try SealedLane.open(payload: $0, with: privateKey) }
        #expect(messages.count == 2)
        let (meta, files) = try TalkWire.reassemble(messages)
        #expect(meta?.purpose == .comment && meta?.town == "loule")
        #expect(try messages.allSatisfy { try TalkWire.split($0).header.place == "loule" })
        #expect(meta?.by == TalkWire.fingerprint(of: person.publicKey))
        #expect(files["payload.json"] == payload)
        for message in messages {
            let (header, body) = try TalkWire.split(message)
            #expect(TalkWire.verify(header: header, body: body) == .signed(by: TalkWire.fingerprint(of: person.publicKey)))
        }
    }

    @Test func noLaneAndRepliesSayWhy() async throws {
        let transport = TalkTransport(link: { nil }, transport: FakeTransport(), retry: false, app: "t")
        #expect(!(await transport.isConnected()))
        await #expect(throws: TalkTransport.Failure.noLane) { try await transport.send(Data("{}".utf8), signedBy: P256.Signing.PrivateKey()) }
        await #expect(throws: TalkTransport.Failure.repliesNotAgreed) { _ = try await transport.replies(for: "dinis") }
    }

    @Test func aRefusalWithoutRetryThrowsTheLanesAnswer() async throws {
        let (_, _, link) = try makeLane()
        let transport = TalkTransport(link: { link }, transport: FakeTransport(failAt: [1]), retry: false, app: "t")
        await #expect(throws: TalkSendError.refused(503)) { try await transport.send(Data("{}".utf8), signedBy: P256.Signing.PrivateKey()) }
    }
}
