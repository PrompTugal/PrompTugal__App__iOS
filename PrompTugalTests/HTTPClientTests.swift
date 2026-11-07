import Foundation
import Testing
@testable import PrompTugal

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
