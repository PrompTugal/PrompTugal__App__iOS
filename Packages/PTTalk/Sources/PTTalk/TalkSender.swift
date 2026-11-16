import Foundation
import Network
import Observation
import PTLanes

// Ported from VoiceDebrief `Engine/PictureSender.swift`, `DeveloperLane.send` and `NetworkWatch.swift` (Apache 2.0,
// github.com/VoiceDebrief/VoiceDebrief__App__iOS): five tries, waits of 10 s, 30 s, 1 min and 2 min, at once when
// the network comes back or on "Try now". Unlike VoiceDebrief, a retry carries on from the part that failed.

/// Writes one sealed payload to a lane and returns the HTTP status. A seam so tests need no network.
public protocol LaneTransport: Sendable {
    func write(_ request: URLRequest) async throws -> Int
}

public struct URLSessionLaneTransport: LaneTransport {
    public init() {}
    public func write(_ request: URLRequest) async throws -> Int {
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}

public enum TalkSendError: Error, Equatable, LocalizedError {
    case refused(Int)
    case tooLarge
    public var errorDescription: String? {
        switch self {
        case .refused(404): "The lane refused it (404): the link may be out of date."
        case .refused(507): "The lane is full (507): the receiver has not drained it."
        case .refused(let status): "The lane refused it (status \(status))."
        case .tooLarge: "The lane refused it as too large."
        }
    }
}

public enum TalkRetry {
    public static let attempts = 5
    public static let waits: [TimeInterval] = [10, 30, 60, 120]
    /// The wait before try `next` (2...attempts), or nil when there are no more tries.
    public static func wait(before next: Int) -> TimeInterval? {
        let index = next - 2
        return waits.indices.contains(index) ? waits[index] : nil
    }
}

/// Seals each message to the lane's key and appends it, in order, starting at `from`. Calls `onProgress` with the
/// number written so far. Throws on the first refusal; the error says how many were written before it.
public struct LaneWriter: Sendable {
    public struct Stopped: Error {
        public let written: Int
        public let underlying: Error
    }

    public let transport: LaneTransport
    public init(transport: LaneTransport = URLSessionLaneTransport()) { self.transport = transport }

    public func write(_ messages: [Data], to lane: SealedLane, from start: Int = 0,
                      onProgress: @escaping @Sendable (Int, Int) -> Void) async throws {
        var index = start
        do {
            while index < messages.count {
                let request = try lane.writeRequest(payload: try lane.seal(messages[index]))
                let status = try await transport.write(request)
                if status == 413 { throw TalkSendError.tooLarge }
                guard (200..<300).contains(status) else { throw TalkSendError.refused(status) }
                index += 1
                onProgress(index, messages.count)
            }
        } catch {
            throw Stopped(written: index, underlying: error)
        }
    }
}

/// Whether the device is online, and when it last came back.
@MainActor @Observable
public final class TalkNetwork {
    public static let shared = TalkNetwork()
    public private(set) var online = true
    public private(set) var backOnlineAt: Date?
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let now = path.status == .satisfied
            Task { @MainActor in
                let shared = TalkNetwork.shared
                if now && !shared.online { shared.backOnlineAt = .now }
                shared.online = now
            }
        }
        monitor.start(queue: DispatchQueue(label: "pt.talk.network"))
    }
}

/// One item on its way: its messages, written to a lane with retries, progress and a sent state.
@MainActor @Observable
public final class TalkSender {
    public enum State: Equatable {
        case idle
        case sending(Int, Int)
        case retrying(attempt: Int, of: Int, next: Date)
        case sent(Date)
        case failed(String)

        public var isBusy: Bool {
            switch self {
            case .sending, .retrying: true
            default: false
            }
        }
    }

    public private(set) var state: State = .idle
    private let writer: LaneWriter
    private var tryNowAsked = false

    public init(writer: LaneWriter = LaneWriter()) { self.writer = writer }

    /// Sends every message; true when all were written.
    @discardableResult
    public func send(_ messages: [Data], to lane: SealedLane) async -> Bool {
        guard !messages.isEmpty else { return false }
        var written = 0
        var attempt = 1
        while true {
            state = .sending(written, messages.count)
            do {
                try await writer.write(messages, to: lane, from: written) { done, total in
                    Task { @MainActor [weak self] in
                        guard let self, case .sending = self.state else { return }
                        self.state = .sending(done, total)
                    }
                }
                state = .sent(.now)
                return true
            } catch let stopped as LaneWriter.Stopped {
                written = stopped.written
                guard let wait = TalkRetry.wait(before: attempt + 1) else {
                    var why = stopped.underlying.localizedDescription
                    if why.hasSuffix(".") { why.removeLast() }
                    state = .failed("not sent after \(attempt) tries (\(why))")
                    return false
                }
                let failedAt = Date()
                state = .retrying(attempt: attempt + 1, of: TalkRetry.attempts, next: failedAt.addingTimeInterval(wait))
                let net = TalkNetwork.shared
                while Date() < failedAt.addingTimeInterval(wait) {
                    if let back = net.backOnlineAt, back > failedAt, net.online { break }
                    if tryNowAsked { tryNowAsked = false; break }
                    try? await Task.sleep(for: .seconds(1))
                }
                attempt += 1
            } catch {
                state = .failed(error.localizedDescription)
                return false
            }
        }
    }

    public func tryNow() { tryNowAsked = true }
    public func reset() { state = .idle }
}
