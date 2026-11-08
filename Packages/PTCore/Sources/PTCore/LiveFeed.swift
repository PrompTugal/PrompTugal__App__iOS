import Foundation

// The seam between live news feeds (RSS, Atom, JSON) and the screens that show them (summit-app-store brief).
// PTSync fetches, parses and keeps the items on the device so they read offline; PTNews, the Now screen and the apps read
// through `LiveFeeds` and never import PTSync. The app registers the source once at launch.

/// One entry of a live feed, as plain text and https links: the title and summary carry no HTML.
public struct FeedItem: Codable, Hashable, Sendable, Identifiable {
    /// The feed's own id for it (guid, Atom id, JSON Feed id), or its link.
    public let id: String
    /// Which feed it came from (`promptugal.articles`).
    public let feed: String
    public let title: String
    /// Plain text, a few hundred characters at most. Empty when the feed gave none.
    public let summary: String
    /// The page for the entry. https only.
    public let url: URL?
    /// A picture for the entry. https only.
    public let imageURL: URL?
    public let published: Date?
    public let category: String?

    public init(id: String, feed: String, title: String, summary: String = "", url: URL? = nil, imageURL: URL? = nil,
                published: Date? = nil, category: String? = nil) {
        self.id = id
        self.feed = feed
        self.title = title
        self.summary = summary
        self.url = url
        self.imageURL = imageURL
        self.published = published
        self.category = category
    }
}

/// Read access to the kept feed items.
public protocol LiveFeedSource: Sendable {
    /// Newest first. `nil`: the items of every feed together.
    func items(in feed: String?) -> [FeedItem]
    /// When a feed was last fetched successfully (the latest of all feeds). Nil when none has been.
    var updatedAt: Date? { get }
    /// Counts up whenever the kept items change, so a reader can tell when to reload.
    var generation: Int { get }
}

/// The source the app registered. Nil until the app does (a reader then shows what it has, as before).
public enum LiveFeeds {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var value: (any LiveFeedSource)?
        func get() -> (any LiveFeedSource)? { lock.lock(); defer { lock.unlock() }; return value }
        func set(_ source: (any LiveFeedSource)?) { lock.lock(); defer { lock.unlock() }; value = source }
    }

    private static let box = Box()

    public static var source: (any LiveFeedSource)? {
        get { box.get() }
        set { box.set(newValue) }
    }
}
