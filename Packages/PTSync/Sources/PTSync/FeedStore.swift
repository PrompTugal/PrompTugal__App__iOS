import Foundation
import PTCore

/// The feed items kept on this device, so the news reads offline. One small JSON file, replaced atomically.
/// Implements PTCore's `LiveFeedSource`; the app registers it with `LiveFeeds.source` at launch.
public final class FeedStore: LiveFeedSource, @unchecked Sendable {
    struct FeedState: Codable, Equatable {
        var items: [FeedItem] = []
        var updatedAt: Date?
        var etag: String?
    }

    private struct Stored: Codable {
        var feeds: [String: FeedState] = [:]
        var generation = 0
    }

    let directory: URL
    let tempDirectory: URL
    private let file: URL
    private let lock = NSLock()
    private var stored = Stored()

    public init(directory: URL? = nil) {
        let root = directory ?? URL.applicationSupportDirectory.appendingPathComponent("PTSync/feeds", isDirectory: true)
        self.directory = root
        tempDirectory = root.appendingPathComponent("tmp", isDirectory: true)
        file = root.appendingPathComponent("feeds.json")
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        for folder in [root, tempDirectory] {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: attributes)
        }
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true        // it can be fetched again
        var mutableRoot = root
        try? mutableRoot.setResourceValues(excluded)
        for name in (try? FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)) ?? [] {
            try? FileManager.default.removeItem(at: tempDirectory.appendingPathComponent(name))
        }
        if let data = try? Data(contentsOf: file) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            stored = (try? decoder.decode(Stored.self, from: data)) ?? Stored()
        }
    }

    // MARK: LiveFeedSource

    /// Newest first (undated items last, then by title).
    public func items(in feed: String?) -> [FeedItem] {
        let all = lock.withLock { () -> [FeedItem] in
            if let feed { return stored.feeds[feed]?.items ?? [] }
            return stored.feeds.values.flatMap(\.items)
        }
        return Self.newestFirst(all)
    }

    public var updatedAt: Date? { lock.withLock { stored.feeds.values.compactMap(\.updatedAt).max() } }

    public var generation: Int { lock.withLock { stored.generation } }

    /// When one feed was last fetched successfully.
    public func updatedAt(feed: String) -> Date? { lock.withLock { stored.feeds[feed]?.updatedAt } }

    // MARK: Writing (the syncer)

    func etag(for feed: String) -> String? { lock.withLock { stored.feeds[feed]?.etag } }

    /// Merges fetched items into a feed: the fetched ones replace kept ones with the same id, older kept items stay (so
    /// the news still has them offline after the site's feed has moved on), newest `limit` kept. Returns how many are new.
    @discardableResult
    func update(feed: String, fetched: [FeedItem], etag: String?, limit: Int, at date: Date) throws -> Int {
        let (snapshot, added) = lock.withLock { () -> (Stored, Int) in
            let old = stored.feeds[feed]?.items ?? []
            let known = Set(old.map(\.id))
            let added = fetched.filter { !known.contains($0.id) }.count
            let merged = Self.merge(old: old, fetched: fetched, limit: limit)
            if merged != old { stored.generation += 1 }
            stored.feeds[feed] = FeedState(items: merged, updatedAt: date, etag: etag)
            return (stored, added)
        }
        try write(snapshot)
        return added
    }

    /// The site said nothing changed: remember when we looked.
    func touch(feed: String, at date: Date) throws {
        let snapshot: Stored? = lock.withLock {
            guard var state = stored.feeds[feed] else { return nil }
            state.updatedAt = date
            stored.feeds[feed] = state
            return stored
        }
        if let snapshot { try write(snapshot) }
    }

    static func merge(old: [FeedItem], fetched: [FeedItem], limit: Int) -> [FeedItem] {
        var byID: [String: FeedItem] = [:]
        for item in old { byID[item.id] = item }
        for item in fetched { byID[item.id] = item }
        return Array(newestFirst(Array(byID.values)).prefix(max(1, limit)))
    }

    static func newestFirst(_ items: [FeedItem]) -> [FeedItem] {
        items.sorted { lhs, rhs in
            switch (lhs.published, rhs.published) {
            case let (a?, b?): return a != b ? a > b : lhs.id < rhs.id
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.title != rhs.title ? lhs.title < rhs.title : lhs.id < rhs.id
            }
        }
    }

    private func write(_ snapshot: Stored) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: file, options: .atomic)
    }
}
