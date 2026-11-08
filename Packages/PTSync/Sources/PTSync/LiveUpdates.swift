import Foundation
import PTCore

extension LiveFeed {
    /// The only host the public app talks to for news.
    public static let publicHost = "promptugal.news"

    /// The feeds the public app follows: promptugal.news only. A test pins every address here to `publicHost` over https.
    public static let publicApp: [LiveFeed] = [.promptugalArticles, .promptugalNewsletter]
}

extension URLSessionTransport {
    /// A session that keeps nothing: no cookies, no cache on disk, no stored credentials. The feeds are public and are
    /// kept by `FeedStore`; the session adds no identifier of its own. Requests are still logged in Debug → Network.
    public static func ephemeral(log: HTTPLog = .shared) -> URLSessionTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": HTTPClient.userAgent]
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSessionTransport(session: URLSession(configuration: configuration), log: log)
    }
}

/// Live updates for the public app, in one place: the kept feed items, their refresh at launch and when the app comes to
/// the front, and the background refresh. It talks to promptugal.news only.
///
///     let live = LiveUpdates()                // in the app's init
///     live.start()                            // registers the kept items with PTCore's `LiveFeeds`
///     .task { await live.refresh() }          // at launch
///     .onChange(of: scenePhase) { if $0 == .active { Task { await live.refresh() } } }
///
/// The background task is registered once for the whole app (`SyncBackground`), so the app's closure runs this after
/// the content sync: `SyncBackground.register(taskIdentifier: id) { await sync...; return await live.backgroundWork() }`.
public final class LiveUpdates: @unchecked Sendable {
    public let store: FeedStore
    private let syncer: FeedSyncer
    private let now: @Sendable () -> Date
    private let minimumInterval: TimeInterval
    private let lock = NSLock()
    private var lastAttempt: Date?

    /// - Parameter minimumInterval: a refresh that is not forced is skipped when the last one started less than this
    ///   many seconds ago, so coming to the front often does not fetch each time.
    public init(store: FeedStore = FeedStore(), feeds: [LiveFeed] = LiveFeed.publicApp,
                transport: SyncTransport = URLSessionTransport.ephemeral(), minimumInterval: TimeInterval = 300,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        syncer = FeedSyncer(store: store, feeds: feeds, transport: transport, now: now)
        self.now = now
        self.minimumInterval = minimumInterval
    }

    /// Registers the kept items as the app's `LiveFeeds.source`. Call once at launch, before the first screen reads.
    public func start() {
        LiveFeeds.source = store
    }

    /// Fetches the feeds. Returns nil when it was skipped because the last refresh was recent and `force` is false.
    @discardableResult
    public func refresh(force: Bool = false) async -> FeedRefreshReport? {
        let date = now()
        let skip = lock.withLock { () -> Bool in
            if !force, let last = lastAttempt, date.timeIntervalSince(last) < minimumInterval { return true }
            lastAttempt = date
            return false
        }
        if skip { return nil }
        return await syncer.refresh()
    }

    /// For the background task: refreshes now and says whether it worked (nothing failed).
    public func backgroundWork() async -> Bool {
        guard let report = await refresh(force: true) else { return true }
        return report.failures.isEmpty
    }
}
