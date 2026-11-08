import Foundation

public struct FeedRefreshReport: Sendable, Equatable {
    /// Feeds whose items were fetched and kept.
    public var updated: [String] = []
    /// Feeds the site said had not changed.
    public var notModified: [String] = []
    /// Feed id → why it failed. The items kept from before stay.
    public var failures: [String: String] = [:]
    /// Items not seen before, over all feeds.
    public var newItems = 0
    public init() {}
}

/// Fetches the feeds, parses them as plain text and https links, and keeps the items in a `FeedStore`.
/// One feed failing never loses what is kept or stops the others. One refresh at a time; a second call joins it.
public actor FeedSyncer {
    private let store: FeedStore
    private let feeds: [LiveFeed]
    private let transport: SyncTransport
    private let now: @Sendable () -> Date
    private var running: Task<FeedRefreshReport, Never>?

    public init(store: FeedStore, feeds: [LiveFeed], transport: SyncTransport = URLSessionTransport(),
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.feeds = feeds
        self.transport = transport
        self.now = now
    }

    public func refresh() async -> FeedRefreshReport {
        if let running { return await running.value }
        let task = Task { await self.run() }
        running = task
        defer { running = nil }
        return await task.value
    }

    private func run() async -> FeedRefreshReport {
        var report = FeedRefreshReport()
        for feed in feeds {
            do {
                switch try await fetch(feed) {
                case .notModified:
                    report.notModified.append(feed.id)
                case .updated(let added):
                    report.updated.append(feed.id)
                    report.newItems += added
                }
            } catch is CancellationError {
                break
            } catch {
                report.failures[feed.id] = error.localizedDescription
            }
        }
        return report
    }

    private enum Outcome {
        case notModified
        case updated(added: Int)
    }

    private func fetch(_ feed: LiveFeed) async throws -> Outcome {
        guard feed.url.scheme == "https", let host = feed.url.host(), feed.allowedHosts.contains(host) else {
            throw FeedError.unsafeFeedURL
        }
        let response = try await transport.download(feed.url, ifNoneMatch: store.etag(for: feed.id), into: store.tempDirectory)
        defer { if let file = response.file { try? FileManager.default.removeItem(at: file) } }
        if response.status == 304 {
            try store.touch(feed: feed.id, at: now())
            return .notModified
        }
        guard (200..<300).contains(response.status), let file = response.file else { throw FeedError.badStatus(response.status) }
        let size = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber)?.intValue ?? 0
        guard size <= FeedLimits.maxBytes else { throw FeedError.tooLarge }
        let items = try FeedParser.parse(Data(contentsOf: file), feed: feed)
        let added = try store.update(feed: feed.id, fetched: items, etag: response.etag, limit: feed.limit, at: now())
        return .updated(added: added)
    }
}
