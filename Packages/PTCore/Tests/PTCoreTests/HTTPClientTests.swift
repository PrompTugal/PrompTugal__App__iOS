import Foundation
import Testing
@testable import PTCore

@Suite("HTTP client")
struct HTTPClientTests {
    @Test("Redaction drops credentials, fragments and query values")
    func redacts() throws {
        let url = try #require(URL(string: "https://me:secret@example.com/a/b?key=abc123&page=2#frag"))
        let redacted = HTTPClient.redact(url)
        #expect(redacted == "https://example.com/a/b?key=…&page=…")
        #expect(!redacted.contains("secret"))
        #expect(!redacted.contains("abc123"))
    }

    @Test("A URL without a query is unchanged")
    func plainURL() throws {
        let url = try #require(URL(string: "https://promptugal.news/api/v1/live/agenda.json"))
        #expect(HTTPClient.redact(url) == url.absoluteString)
    }

    @MainActor @Test("The log keeps the newest records, up to its capacity, and counts all of them")
    func logCap() {
        let log = HTTPLog(capacity: 3)
        for index in 0..<5 {
            log.append(HTTPRequestRecord(id: UUID(), startedAt: .now, method: "GET", url: "https://x/\(index)",
                                         host: "x", label: nil, status: index == 4 ? 500 : 200, bytes: 10,
                                         durationMs: 1, error: nil))
        }
        #expect(log.records.map(\.url) == ["https://x/4", "https://x/3", "https://x/2"])
        #expect(log.totalRequests == 5)
        #expect(log.totalBytes == 50)
        #expect(log.totalFailures == 1)
        log.clear()
        #expect(log.records.isEmpty && log.totalRequests == 0)
    }
}

/// Serves a fixed body for any request, so the size cap can be tested without the network.
final class StubBodyProtocol: URLProtocol, @unchecked Sendable {
    // Read-only after setup in each test; the suite below runs serially.
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var sendsLength = true

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var headers = ["Content-Type": "application/octet-stream"]
        if Self.sendsLength { headers["Content-Length"] = String(Self.body.count) }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // In pieces, like a real connection.
        var offset = 0
        while offset < Self.body.count {
            let end = min(offset + 4096, Self.body.count)
            client?.urlProtocol(self, didLoad: Self.body.subdata(in: offset..<end))
            offset = end
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite("HTTP client: response size cap", .serialized)
struct HTTPClientSizeCapTests {
    private func client() -> (HTTPClient, HTTPLog) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubBodyProtocol.self]
        let log = HTTPLog()
        return (HTTPClient(session: URLSession(configuration: configuration), log: log), log)
    }
    private let url = URL(string: "https://promptugal.news/api/v1/test.json")!

    @Test("The default cap is 10 MB")
    func defaultCap() {
        #expect(HTTPClient.defaultMaxBytes == 10 * 1024 * 1024)
    }

    @Test("A body within the cap is returned whole")
    func withinCap() async throws {
        StubBodyProtocol.body = Data(repeating: 7, count: 20_000)
        StubBodyProtocol.sendsLength = true
        let (http, log) = client()
        let data = try await http.get(url, maxBytes: 20_000)
        #expect(data == StubBodyProtocol.body)
        let record = try #require(await log.records.first)
        #expect(record.bytes == 20_000 && record.error == nil)
    }

    @Test("A Content-Length over the cap is refused before reading")
    func declaredTooLarge() async throws {
        StubBodyProtocol.body = Data(repeating: 1, count: 50_000)
        StubBodyProtocol.sendsLength = true
        let (http, log) = client()
        await #expect(throws: HTTPClient.ResponseTooLarge(limit: 10_000)) {
            _ = try await http.get(url, maxBytes: 10_000)
        }
        let record = try #require(await log.records.first)
        #expect(record.error?.hasPrefix("Too large") == true)
    }

    @Test("A body without Content-Length stops at the cap")
    func streamedTooLarge() async throws {
        StubBodyProtocol.body = Data(repeating: 2, count: 50_000)
        StubBodyProtocol.sendsLength = false
        let (http, _) = client()
        await #expect(throws: HTTPClient.ResponseTooLarge(limit: 10_000)) {
            _ = try await http.get(url, maxBytes: 10_000)
        }
    }
}
