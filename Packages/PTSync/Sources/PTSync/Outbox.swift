import Foundation

/// A write that has to reach a server (a message, a note to the newsroom, a pick, a check-in), kept on disk until it does.
public struct OutboxItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    /// What it is, so the sender knows where it goes: `"lane.message"`, `"newsroom.note"`, `"picks"`.
    public let kind: String
    /// The same key means the same write: enqueuing it again while it is pending does nothing, and a sender can pass it
    /// to the server so a retry after a lost answer is safe (lanes are append-only).
    public let idempotencyKey: String
    public let payload: Data
    public let createdAt: Date
    public var attempts: Int
    public var lastError: String?
    public var nextAttemptAt: Date?
}

/// Sends one item. Throw `OutboxFailure.permanent` for an item that can never succeed (the server refused it): it is dropped.
/// Any other error means "try again later".
public protocol OutboxSender: Sendable {
    func send(_ item: OutboxItem) async throws
}

public enum OutboxFailure: Error, Equatable {
    case permanent(String)
}

public enum OutboxError: Error, LocalizedError, Equatable {
    case full(Int)
    public var errorDescription: String? {
        switch self {
        case .full(let capacity): "The outbox is full (\(capacity) waiting). Connect to send them first."
        }
    }
}

public struct OutboxFlushResult: Sendable, Equatable {
    public var sent = 0
    public var dropped = 0
    public var remaining = 0
    /// A transient failure stopped the run; the rest waits for the next flush.
    public var stopped = false
    public init() {}
}

/// Queued writes, kept in order in one file. Flush on launch, when the app becomes active and when the network returns
/// (`SystemNetworkPath.onBecameReachable`). A failed item waits with a growing delay; later items do not jump ahead of it.
public actor Outbox {
    private let file: URL
    private let sender: OutboxSender
    private let now: @Sendable () -> Date
    private let capacity: Int
    private let backoff: [TimeInterval]
    private var items: [OutboxItem] = []
    private var flushing = false

    public init(directory: URL, sender: OutboxSender, capacity: Int = 500,
                backoff: [TimeInterval] = [2, 10, 30, 120, 600], now: @escaping @Sendable () -> Date = { Date() }) {
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: attributes)
        file = directory.appendingPathComponent("outbox.json")
        self.sender = sender
        self.capacity = capacity
        self.backoff = backoff.isEmpty ? [10] : backoff
        self.now = now
        if let data = try? Data(contentsOf: file) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = (try? decoder.decode([OutboxItem].self, from: data)) ?? []
        }
    }

    public var pending: [OutboxItem] { items }

    /// Adds a write. Returns the queued item, or the one already queued under the same key.
    @discardableResult
    public func enqueue(kind: String, payload: Data, idempotencyKey: String? = nil) throws -> OutboxItem {
        let key = idempotencyKey ?? UUID().uuidString
        if let existing = items.first(where: { $0.idempotencyKey == key && $0.kind == kind }) { return existing }
        guard items.count < capacity else { throw OutboxError.full(capacity) }
        let item = OutboxItem(id: UUID(), kind: kind, idempotencyKey: key, payload: payload, createdAt: now(),
                              attempts: 0, lastError: nil, nextAttemptAt: nil)
        items.append(item)
        try save()
        return item
    }

    /// Sends what is due, oldest first. Stops at the first transient failure.
    @discardableResult
    public func flush() async -> OutboxFlushResult {
        var result = OutboxFlushResult()
        guard !flushing else { result.remaining = items.count; return result }
        flushing = true
        defer { flushing = false }
        while let item = items.first {
            if let next = item.nextAttemptAt, next > now() { result.stopped = true; break }
            do {
                try await sender.send(item)
                items.removeAll { $0.id == item.id }
                result.sent += 1
            } catch OutboxFailure.permanent {
                items.removeAll { $0.id == item.id }
                result.dropped += 1
            } catch {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].attempts += 1
                    items[index].lastError = (error as? URLError).map { "URLError \($0.code.rawValue)" } ?? String(describing: type(of: error))
                    let step = min(items[index].attempts - 1, backoff.count - 1)
                    items[index].nextAttemptAt = now().addingTimeInterval(backoff[step])
                }
                result.stopped = true
                try? save()
                break
            }
            try? save()
        }
        result.remaining = items.count
        return result
    }

    public func remove(id: UUID) throws {
        items.removeAll { $0.id == id }
        try save()
    }

    public func removeAll() throws {
        items.removeAll()
        try save()
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(items).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
