import Foundation
import Observation

/// One request the app made, for Debug → Network (contracts §8).
///
/// The URL is redacted before it is stored: no user or password, no fragment,
/// and every query value replaced with "…". Headers and bodies are never kept.
struct HTTPRequestRecord: Identifiable, Sendable, Hashable {
    let id: UUID
    let startedAt: Date
    let method: String
    /// Redacted, see `HTTPClient.redact(_:)`.
    let url: String
    let host: String
    /// Who asked, e.g. "feed.agenda". Free text, never a secret.
    let label: String?
    var status: Int?
    var bytes: Int
    var durationMs: Double
    var error: String?

    var succeeded: Bool { error == nil && (status.map { (200..<300).contains($0) } ?? false) }
}

/// The request log behind Debug → Network. Newest first, capped.
@MainActor @Observable
final class HTTPLog {
    nonisolated static let shared = HTTPLog()

    let capacity: Int
    private(set) var records: [HTTPRequestRecord] = []
    /// Totals since launch (or since `clear()`), including records dropped by the cap.
    private(set) var totalRequests = 0
    private(set) var totalBytes = 0
    private(set) var totalFailures = 0

    nonisolated init(capacity: Int = 1_000) {
        self.capacity = capacity
    }

    func append(_ record: HTTPRequestRecord) {
        records.insert(record, at: 0)
        if records.count > capacity { records.removeLast(records.count - capacity) }
        totalRequests += 1
        totalBytes += record.bytes
        if !record.succeeded { totalFailures += 1 }
    }

    func clear() {
        records.removeAll()
        totalRequests = 0
        totalBytes = 0
        totalFailures = 0
    }
}

/// The one shared HTTP client. Every `URLSession` request the app makes goes
/// through here, so Debug → Network can show it. Features call `get`,
/// `decode` or `data(for:)`; the vault package keeps its own traffic log.
final class HTTPClient: Sendable {
    static let shared = HTTPClient()

    let session: URLSession
    let log: HTTPLog

    init(session: URLSession = HTTPClient.makeSession(), log: HTTPLog = .shared) {
        self.session = session
        self.log = log
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: configuration)
    }

    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "PrompTugal/\(version) (\(build); iOS)"
    }()

    /// The largest body any call accepts unless it asks for more: 10 MB. The app's feeds are well under
    /// 1 MB; this stops a broken or hostile server from filling memory.
    static let defaultMaxBytes = 10 * 1024 * 1024

    /// Thrown when a response body is larger than the call's `maxBytes`.
    struct ResponseTooLarge: LocalizedError, Equatable {
        let limit: Int
        var errorDescription: String? { "The response was larger than \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file))." }
    }

    /// Sends a request, logs it, and returns the body and the HTTP response.
    /// Does not check the status code; `get` and `decode` do.
    /// Throws `ResponseTooLarge` as soon as the body passes `maxBytes` (or at once if the server's
    /// Content-Length already says so), without reading the rest.
    func data(for request: URLRequest, label: String? = nil,
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
    func get(_ url: URL, timeout: TimeInterval = 15, label: String? = nil,
             maxBytes: Int = HTTPClient.defaultMaxBytes) async throws -> Data {
        let (data, response) = try await data(for: URLRequest(url: url, timeoutInterval: timeout), label: label,
                                              maxBytes: maxBytes)
        guard (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    /// GET a URL and decode its JSON body.
    func decode<Value: Decodable>(_ type: Value.Type, from url: URL, timeout: TimeInterval = 15,
                                  label: String? = nil, maxBytes: Int = HTTPClient.defaultMaxBytes,
                                  decoder: JSONDecoder = JSONDecoder()) async throws -> Value {
        try decoder.decode(type, from: await get(url, timeout: timeout, label: label, maxBytes: maxBytes))
    }

    /// A URL safe to show and log: no user, password or fragment, and query values replaced with "…".
    static func redact(_ url: URL) -> String {
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
