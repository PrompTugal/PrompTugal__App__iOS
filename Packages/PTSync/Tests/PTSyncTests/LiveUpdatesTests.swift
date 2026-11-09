import Foundation
import PTCore
import Testing
@testable import PTSync

private func articlesBody() -> Data {
    Data("""
    <?xml version="1.0"?><rss version="2.0"><channel><title>T</title>
    <item><title>One</title><link>https://promptugal.news/articles/one.html</link><guid>one</guid><pubDate>Sat, 07 Nov 2026 09:00:00 GMT</pubDate></item>
    </channel></rss>
    """.utf8)
}

@Suite("PTSync: live updates for the public app")
struct LiveUpdatesTests {
    private let articles = LiveFeed(id: "a", title: "Articles", url: URL(string: "https://promptugal.news/feed.xml")!, format: .rss)

    @Test("Privacy: every feed address the public app follows is https on promptugal.news, and nothing else is allowed")
    func onlyPromptugalNews() {
        #expect(!LiveFeed.publicApp.isEmpty)
        for feed in LiveFeed.publicApp {
            #expect(feed.url.scheme == "https", "\(feed.id)")
            #expect(feed.url.host() == LiveFeed.publicHost, "\(feed.id)")
            #expect(feed.allowedHosts == [LiveFeed.publicHost], "\(feed.id)")
        }
        #expect(SyncSource.promptugalNews.base.host() == LiveFeed.publicHost)
        #expect(SyncSource.promptugalNews.allowedHosts == [LiveFeed.publicHost])
    }

    @Test("A feed on another host is refused without a request, even when someone adds it to the list")
    func otherHostRefused() async {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        let elsewhere = LiveFeed(id: "x", title: "X", url: URL(string: "https://tracker.example/feed.xml")!, format: .rss,
                                 allowedHosts: [LiveFeed.publicHost])
        site.serve(elsewhere.url, articlesBody())
        let live = LiveUpdates(store: FeedStore(directory: dir.url), feeds: [elsewhere], transport: site)
        let report = await live.refresh(force: true)
        #expect(report?.failures.keys.sorted() == ["x"])
        #expect(site.totalRequests == 0)
    }

    @Test("A refresh that is not forced waits for the interval; a forced one does not")
    func interval() async {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        site.serve(articles.url, articlesBody(), etag: "\"v1\"")
        let clock = FakeClock(1_000)
        let live = LiveUpdates(store: FeedStore(directory: dir.url), feeds: [articles], transport: site,
                               minimumInterval: 300, now: { clock.now() })
        let first = await live.refresh()
        #expect(first?.updated == ["a"] && site.totalRequests == 1)
        clock.advance(100)
        let tooSoon = await live.refresh()
        #expect(tooSoon == nil && site.totalRequests == 1, "too soon")
        let forced = await live.refresh(force: true)
        #expect(forced?.notModified == ["a"] && site.totalRequests == 2)
        clock.advance(299)
        let stillSoon = await live.refresh()
        #expect(stillSoon == nil, "the forced one counts as the last")
        clock.advance(2)
        let due = await live.refresh()
        #expect(due != nil && site.totalRequests == 3)
    }

    @Test("The background work says whether anything failed")
    func background() async {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        site.serve(articles.url, articlesBody())
        let live = LiveUpdates(store: FeedStore(directory: dir.url), feeds: [articles], transport: site)
        let worked = await live.backgroundWork()
        site.fail(articles.url)
        let failed = await live.backgroundWork()
        #expect(worked && !failed)
    }
}

extension FeedStoreTests {
    @Test("start() makes the kept items the app's LiveFeeds source, and the readers get stories from them")
    func startRegisters() async throws {
        let dir = TempDir()
        defer { dir.cleanup(); LiveFeeds.source = nil }
        let site = FakeFeeds()
        let feed = LiveFeed(id: LiveContent.articlesFeedID, title: "A", url: URL(string: "https://promptugal.news/feed.xml")!, format: .rss)
        site.serve(feed.url, articlesBody())
        let live = LiveUpdates(store: FeedStore(directory: dir.url), feeds: [feed], transport: site)
        #expect(LiveFeeds.source == nil)
        live.start()
        _ = await live.refresh(force: true)
        #expect(LiveContent.stories().map(\.id) == ["one"])
        #expect(LiveContent.stories().first?.url.absoluteString == "https://promptugal.news/articles/one.html")
    }
}
