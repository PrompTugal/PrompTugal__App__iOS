import Foundation
import PTCore

/// What a download returned. `file` is a temporary file the caller owns (nil for a 304 or an error status).
public struct SyncDownload: Sendable {
    public let status: Int
    public let file: URL?
    public let etag: String?

    public init(status: Int, file: URL?, etag: String?) {
        self.status = status
        self.file = file
        self.etag = etag
    }
}

/// How bytes come from the site. Tests supply a fake; the app uses `URLSessionTransport`.
public protocol SyncTransport: Sendable {
    /// Downloads `url` into a new file inside `directory` (same volume as the store, so adopting it is a rename).
    func download(_ url: URL, ifNoneMatch: String?, into directory: URL) async throws -> SyncDownload
}

/// `URLSession` downloads, logged in Debug → Network like every other request. A file never sits in memory.
public struct URLSessionTransport: SyncTransport {
    private let session: URLSession
    private let log: HTTPLog

    public init(session: URLSession = HTTPClient.makeSession(), log: HTTPLog = .shared) {
        self.session = session
        self.log = log
    }

    public func download(_ url: URL, ifNoneMatch: String?, into directory: URL) async throws -> SyncDownload {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        if let ifNoneMatch { request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match") }
        let started = Date()
        let clock = ContinuousClock.now
        var record = HTTPRequestRecord(id: UUID(), startedAt: started, method: "GET", url: HTTPClient.redact(url),
                                       host: url.host() ?? "", label: "sync", status: nil, bytes: 0, durationMs: 0, error: nil)
        do {
            let (temporary, response) = try await session.download(for: request)
            guard let http = response as? HTTPURLResponse else {
                try? FileManager.default.removeItem(at: temporary)
                throw URLError(.badServerResponse)
            }
            record.status = http.statusCode
            var file: URL?
            if (200..<300).contains(http.statusCode) {
                let destination = directory.appendingPathComponent(UUID().uuidString + ".part")
                try FileManager.default.moveItem(at: temporary, to: destination)
                file = destination
                record.bytes = ((try? FileManager.default.attributesOfItem(atPath: destination.path)[.size]) as? NSNumber)?.intValue ?? 0
            } else {
                try? FileManager.default.removeItem(at: temporary)
            }
            record.durationMs = Self.milliseconds(since: clock)
            await log.append(record)
            return SyncDownload(status: http.statusCode, file: file, etag: http.value(forHTTPHeaderField: "ETag"))
        } catch {
            record.durationMs = Self.milliseconds(since: clock)
            record.error = (error as? URLError).map { "URLError \($0.code.rawValue)" } ?? String(describing: type(of: error))
            await log.append(record)
            throw error
        }
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = ContinuousClock.now - start
        return Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
    }
}
