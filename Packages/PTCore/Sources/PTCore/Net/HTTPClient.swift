import Foundation
import Observation

/// One request the app made, for Debug → Network (contracts §8).
///
/// The URL is redacted before it is stored: no user or password, no fragment,
/// and every query value replaced with "…". Headers and bodies are never kept.
public struct HTTPRequestRecord: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let startedAt: Date
    public let method: String
    /// Redacted, see `HTTPClient.redact(_:)`.
    public let url: String
    public let host: String
    /// Who asked, e.g. "feed.agenda". Free text, never a secret.
    public let label: String?
    public var status: Int?
    public var bytes: Int
    public var durationMs: Double
    public var error: String?

    public init(id: UUID, startedAt: Date, method: String, url: String, host: String, label: String?, status: Int? = nil, bytes: Int, durationMs: Double, error: String? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.method = method
        self.url = url
        self.host = host
        self.label = label
        self.status = status
        self.bytes = bytes
        self.durationMs = durationMs
        self.error = error
    }

    public var succeeded: Bool { error == nil && (status.map { (200..<300).contains($0) } ?? false) }
}

/// The request log behind Debug → Network. Newest first, capped.
@MainActor @Observable
public final class HTTPLog {
    public nonisolated static let shared = HTTPLog()

    public let capacity: Int
    public private(set) var records: [HTTPRequestRecord] = []
    /// Totals since launch (or since `clear()`), including records dropped by the cap.
    public private(set) var totalRequests = 0
    public private(set) var totalBytes = 0
    public private(set) var totalFailures = 0

    public nonisolated init(capacity: Int = 1_000) {
        self.capacity = capacity
    }

    public func append(_ record: HTTPRequestRecord) {
        records.insert(record, at: 0)
        if records.count > capacity { records.removeLast(records.count - capacity) }
        totalRequests += 1
        totalBytes += record.bytes
        if !record.succeeded { totalFailures += 1 }
    }

    public func clear() {
        records.removeAll()
        totalRequests = 0
        totalBytes = 0
        totalFailures = 0
    }
}

/// The one shared HTTP client. Every `URLSession` request the app makes goes
/// through here, so Debug → Network can show it. Features call `get`,
/// `decode` or `data(for:)`; the vault package keeps its own traffic log.
public final class HTTPClient: Sendable {
    public static let shared = HTTPClient()

    public let session: URLSession
    public let log: HTTPLog

    public init(session: URLSession = HTTPClient.makeSession(), log: HTTPLog = .shared) {
        self.session = session
        self.log = log
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: configuration)
    }

    public static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "PrompTugal/\(version) (\(build); iOS)"
    }()

    /// The largest body any call accepts unless it asks for more: 10 MB. The app's feeds are well under
    /// 1 MB; this stops a broken or hostile server from filling memory.
    public static let defaultMaxBytes = 10 * 1024 * 1024

    /// Thrown when a response body is larger than the call's `maxBytes`.
    public struct ResponseTooLarge: LocalizedError, Equatable {
        public let limit: Int

        public init(limit: Int) {
            self.limit = limit
        }
        public var errorDescription: String? { "The response was larger than \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file))." }
    }

    /// Sends a request, logs it, and returns the body and the HTTP response.
    /// Does not check the status code; `get` and `decode` do.
    /// Throws `ResponseTooLarge` as soon as the body passes `maxBytes` (or at once if the server's
    /// Content-Length already says so), without reading the rest.
    public func data(for request: URLRequest, label: String? = nil,
              maxBytes: Int = HTTPClient.defaultMaxBytes) async throws -> (Data, HTTPURLResponse) {
        let started = Date()
        let clock = ContinuousClock.now
        let url = request.url
        var record = HTTPRequestRecord(id: UUID(), startedAt: started, method: request.httpMethod ?? "GET",
                                       url: url.map(Self.redact) ?? "(no URL)", host: url?.host() ?? "",
                                       label: label, status: nil, bytes: 0, durationMs: 0, error: nil)
        var data = Data()
        let response: URLResponse
        do {
            let (bytes, head) = try await session.bytes(for: request)
            response = head
            if head.expectedContentLength > Int64(maxBytes) {
                bytes.task.cancel()
                throw ResponseTooLarge(limit: maxBytes)
            }
            if head.expectedContentLength > 0 { data.reserveCapacity(Int(head.expectedContentLength)) }
            for try await byte in bytes {
                guard data.count < maxBytes else {
                    bytes.task.cancel()
                    throw ResponseTooLarge(limit: maxBytes)
                }
                data.append(byte)
            }
        } catch {
            record.durationMs = Self.milliseconds(since: clock)
            record.error = Self.describe(error)
            await log.append(record)
            throw error
        }
        record.durationMs = Self.milliseconds(since: clock)
        record.bytes = data.count
        guard let http = response as? HTTPURLResponse else {
            record.error = "Not an HTTP response"
            await log.append(record)
            throw URLError(.badServerResponse)
        }
        record.status = http.statusCode
        await log.append(record)
        return (data, http)
    }

    /// GET a URL and return the body. Throws `URLError(.badServerResponse)` for a non-2xx status.
    public func get(_ url: URL, timeout: TimeInterval = 15, label: String? = nil,
             maxBytes: Int = HTTPClient.defaultMaxBytes) async throws -> Data {
        let (data, response) = try await data(for: URLRequest(url: url, timeoutInterval: timeout), label: label,
                                              maxBytes: maxBytes)
        guard (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    /// GET a URL and decode its JSON body.
    public func decode<Value: Decodable>(_ type: Value.Type, from url: URL, timeout: TimeInterval = 15,
                                  label: String? = nil, maxBytes: Int = HTTPClient.defaultMaxBytes,
                                  decoder: JSONDecoder = JSONDecoder()) async throws -> Value {
        try decoder.decode(type, from: await get(url, timeout: timeout, label: label, maxBytes: maxBytes))
    }

    /// A URL safe to show and log: no user, password or fragment, and query values replaced with "…".
    public static func redact(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return "(unparseable URL)" }
        parts.user = nil
        parts.password = nil
        parts.fragment = nil
        let names = parts.queryItems?.map(\.name) ?? []
        parts.query = nil
        guard let base = parts.string else { return "(unparseable URL)" }
        return names.isEmpty ? base : base + "?" + names.map { "\($0)=…" }.joined(separator: "&")
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
    }

    private static func describe(_ error: Error) -> String {
        if let error = error as? ResponseTooLarge { return "Too large (over \(error.limit) bytes)" }
        if let error = error as? URLError {
            return error.code == .cancelled ? "Cancelled" : "URLError \(error.code.rawValue)"
        }
        return String(describing: type(of: error))
    }
}
