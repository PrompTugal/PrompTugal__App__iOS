import Foundation
import Testing
@testable import PTSync

/// A sender the test controls: it records what it was given and fails when told to.
final class FakeSender: OutboxSender, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [OutboxItem] = []
    private var transient: Int
    private var permanentKinds: Set<String>

    init(transientFailures: Int = 0, permanentKinds: Set<String> = []) {
        transient = transientFailures
        self.permanentKinds = permanentKinds
    }

    var sent: [OutboxItem] { lock.withLock { log } }
    func setTransientFailures(_ count: Int) { lock.withLock { transient = count } }

    func send(_ item: OutboxItem) async throws {
        try lock.withLock {
            if permanentKinds.contains(item.kind) { throw OutboxFailure.permanent("refused") }
            if transient > 0 {
                transient -= 1
                throw URLError(.notConnectedToInternet)
            }
            log.append(item)
        }
    }
}

@Suite("PTSync: outbox")
struct OutboxTests {
    private func payload(_ text: String) -> Data { Data(text.utf8) }

    @Test("Items are kept in order on disk, and a new outbox on the same folder sees them")
    func persistsInOrder() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let outbox = Outbox(directory: dir.url, sender: FakeSender())
        try await outbox.enqueue(kind: "lane.message", payload: payload("one"))
        try await outbox.enqueue(kind: "lane.message", payload: payload("two"))
        let reopened = Outbox(directory: dir.url, sender: FakeSender())
        let pending = await reopened.pending
        #expect(pending.map(\.payload) == [payload("one"), payload("two")])
    }

    @Test("The same key is the same write: queued once")
    func idempotentEnqueue() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let outbox = Outbox(directory: dir.url, sender: FakeSender())
        let first = try await outbox.enqueue(kind: "picks", payload: payload("p"), idempotencyKey: "k1")
        let again = try await outbox.enqueue(kind: "picks", payload: payload("p"), idempotencyKey: "k1")
        let other = try await outbox.enqueue(kind: "newsroom.note", payload: payload("p"), idempotencyKey: "k1")
        #expect(first.id == again.id)
        #expect(other.id != first.id, "the key is per kind")
        #expect(await outbox.pending.count == 2)
    }

    @Test("A full outbox says so instead of dropping writes")
    func capacity() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let outbox = Outbox(directory: dir.url, sender: FakeSender(), capacity: 2)
        try await outbox.enqueue(kind: "k", payload: payload("1"))
        try await outbox.enqueue(kind: "k", payload: payload("2"))
        await #expect(throws: OutboxError.full(2)) { try await outbox.enqueue(kind: "k", payload: payload("3")) }
    }

    @Test("Flush sends everything oldest first and empties the file")
    func flushSends() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let sender = FakeSender()
        let outbox = Outbox(directory: dir.url, sender: sender)
        try await outbox.enqueue(kind: "k", payload: payload("a"))
        try await outbox.enqueue(kind: "k", payload: payload("b"))
        let result = await outbox.flush()
        #expect(result.sent == 2 && result.remaining == 0 && !result.stopped)
        #expect(sender.sent.map(\.payload) == [payload("a"), payload("b")])
        let reopened = Outbox(directory: dir.url, sender: sender)
        #expect(await reopened.pending.isEmpty)
    }

    @Test("A failure stops the run, later items wait behind it, and the delay grows")
    func backoffAndOrder() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let clock = FakeClock(1_000)
        let sender = FakeSender(transientFailures: 2)
        let outbox = Outbox(directory: dir.url, sender: sender, backoff: [2, 10], now: { clock.now() })
        try await outbox.enqueue(kind: "k", payload: payload("first"))
        try await outbox.enqueue(kind: "k", payload: payload("second"))

        var result = await outbox.flush()
        #expect(result.stopped && result.sent == 0 && result.remaining == 2)
        var pending = await outbox.pending
        #expect(pending[0].attempts == 1 && pending[0].nextAttemptAt == Date(timeIntervalSince1970: 1_002))
        #expect(pending[0].lastError != nil)
        #expect(sender.sent.isEmpty, "the second item did not jump ahead")

        result = await outbox.flush()                      // not due yet
        #expect(result.stopped && result.sent == 0)

        clock.advance(3)                                   // due: fails again, now waits 10 s
        result = await outbox.flush()
        pending = await outbox.pending
        #expect(result.stopped && pending[0].attempts == 2 && pending[0].nextAttemptAt == Date(timeIntervalSince1970: 1_013))

        clock.advance(11)                                  // due, and the sender works now
        result = await outbox.flush()
        #expect(result.sent == 2 && result.remaining == 0 && !result.stopped)
        #expect(sender.sent.map(\.payload) == [payload("first"), payload("second")])
    }

    @Test("An item the server refuses for good is dropped and the next one goes")
    func permanentFailure() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let sender = FakeSender(permanentKinds: ["bad"])
        let outbox = Outbox(directory: dir.url, sender: sender)
        try await outbox.enqueue(kind: "bad", payload: payload("x"))
        try await outbox.enqueue(kind: "good", payload: payload("y"))
        let result = await outbox.flush()
        #expect(result.dropped == 1 && result.sent == 1 && result.remaining == 0)
        #expect(sender.sent.map(\.kind) == ["good"])
    }

    @Test("Items can be removed one at a time or all together")
    func removing() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let outbox = Outbox(directory: dir.url, sender: FakeSender())
        let one = try await outbox.enqueue(kind: "k", payload: payload("1"))
        try await outbox.enqueue(kind: "k", payload: payload("2"))
        try await outbox.remove(id: one.id)
        #expect(await outbox.pending.map(\.payload) == [payload("2")])
        try await outbox.removeAll()
        #expect(await outbox.pending.isEmpty)
    }
}
