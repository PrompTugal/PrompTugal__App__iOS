import Foundation
import PTCore
import Testing
@testable import PTSync

private let rssFeed = LiveFeed(id: "t.rss", title: "Test", url: URL(string: "https://feeds.test/feed.xml")!, format: .rss)

private func rss(_ items: String) -> Data {
    Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
    <channel><title>Test</title><link>https://feeds.test/</link><description>d</description>
    <image><url>https://feeds.test/i.png</url><title>Channel image title</title><link>https://feeds.test/</link></image>
    \(items)
    </channel></rss>
    """.utf8)
}

@Suite("PTSync: feed text and links")
struct FeedTextTests {
    @Test("HTML becomes plain text: tags and scripts go, entities decode, white space collapses")
    func plainText() {
        #expect(FeedText.plain("<p>Hello <b>world</b></p><p>Second</p>", limit: 100) == "Hello world Second")
        #expect(FeedText.plain("a<script>alert(1)</script>b<style>x{}</style>c", limit: 100) == "a b c")
        #expect(FeedText.plain("Fish &amp; chips &lt;3 &#233; &#x1F600; &nbsp;done", limit: 100) == "Fish & chips <3 é 😀 done")
        #expect(FeedText.plain("&lt;b&gt;bold&lt;/b&gt; text", limit: 100) == "bold text", "tags escaped twice are removed too")
        #expect(FeedText.plain("  line\n\n  break\t tab  ", limit: 100) == "line break tab")
        #expect(FeedText.plain("&notanentity; &#99999999; &", limit: 100) == "&notanentity; &#99999999; &")
    }

    @Test("A long text is cut at a word with an ellipsis")
    func cutting() {
        #expect(FeedText.plain("one two three four five", limit: 12) == "one two…")
        #expect(FeedText.plain("short", limit: 12) == "short")
        #expect(FeedText.plain(String(repeating: "x", count: 50), limit: 10) == String(repeating: "x", count: 10) + "…")
    }

    @Test("Only absolute https links without credentials are kept; relative ones resolve against the feed")
    func links() {
        let base = URL(string: "https://feeds.test/news/feed.xml")!
        #expect(FeedText.safeURL("https://example.test/a?b=1", base: base)?.absoluteString == "https://example.test/a?b=1")
        #expect(FeedText.safeURL("/articles/x.html", base: base)?.absoluteString == "https://feeds.test/articles/x.html")
        #expect(FeedText.safeURL("  https://example.test/a  ", base: base) != nil)
        for bad in ["http://example.test/a", "javascript:alert(1)", "data:text/html,hi", "file:///etc/passwd", "ftp://example.test/a",
                    "https://user:pw@example.test/a", "", "   ", "mailto:a@b.test", "https://" + String(repeating: "a", count: 2_100)] {
            #expect(FeedText.safeURL(bad, base: base) == nil, "\(bad.prefix(40))")
        }
    }

    @Test("Dates: RSS, Atom, JSON Feed and plain days")
    func dates() {
        let expected = Date(timeIntervalSince1970: 1_794_042_000)       // 2026-11-07 09:00:00 UTC
        #expect(FeedText.date("Sat, 07 Nov 2026 09:00:00 GMT") == expected)
        #expect(FeedText.date("Sat, 07 Nov 2026 09:00:00 +0000") == expected)
        #expect(FeedText.date("Sat, 7 Nov 2026 10:00:00 +0100") == expected)
        #expect(FeedText.date("2026-11-07T09:00:00Z") == expected)
        #expect(FeedText.date("2026-11-07T09:00:00.000Z") == expected)
        #expect(FeedText.date("2026-11-07T10:00:00+01:00") == expected)
        #expect(FeedText.date("2026-11-07") == Date(timeIntervalSince1970: 1_794_009_600))
        #expect(FeedText.date("yesterday") == nil && FeedText.date("") == nil)
    }
}

@Suite("PTSync: feed parsing")
struct FeedParserTests {
    @Test("RSS 2.0 as promptugal.news publishes it: title, link, guid, date, description, category, picture")
    func rssRealShape() throws {
        let data = rss("""
        <item><title>How many Brazilian startups came?</title><link>https://feeds.test/articles/brazil.html</link><guid isPermaLink="true">https://feeds.test/articles/brazil.html</guid><pubDate>Sat, 07 Nov 2026 09:00:00 GMT</pubDate><description>Brazil brought one of the two largest delegations.</description><category>Brazil</category><media:content url="https://feeds.test/assets/social-card.png" medium="image"/></item>
        <item><title><![CDATA[Two editions <i>a day</i>]]></title><link>https://feeds.test/articles/two.html</link><guid>two-editions</guid><pubDate>Sat, 07 Nov 2026 08:00:00 GMT</pubDate><description><![CDATA[<p>A daily <b>newsletter</b> starts.</p>]]></description></item>
        """)
        let items = try FeedParser.parse(data, feed: rssFeed)
        #expect(items.count == 2, "the channel's own image title is not an item")
        #expect(items[0].title == "How many Brazilian startups came?")
        #expect(items[0].id == "https://feeds.test/articles/brazil.html" && items[0].feed == "t.rss")
        #expect(items[0].url?.absoluteString == "https://feeds.test/articles/brazil.html")
        #expect(items[0].imageURL?.absoluteString == "https://feeds.test/assets/social-card.png")
        #expect(items[0].published == Date(timeIntervalSince1970: 1_794_042_000))
        #expect(items[0].category == "Brazil")
        #expect(items[0].summary == "Brazil brought one of the two largest delegations.")
        #expect(items[1].id == "two-editions")
        #expect(items[1].title == "Two editions a day")
        #expect(items[1].summary == "A daily newsletter starts.")
        #expect(items[1].imageURL == nil && items[1].category == nil)
    }

    @Test("Untrusted RSS: unsafe links and pictures dropped, markup stripped, an item without a title skipped")
    func rssSafety() throws {
        let data = rss("""
        <item><title>&lt;b&gt;Hi&lt;/b&gt; &amp;amp; you</title><link>http://insecure.test/a</link><guid>g1</guid><description>&lt;script&gt;alert(1)&lt;/script&gt;Clean text</description><media:content url="data:image/png;base64,AAAA" medium="image"/></item>
        <item><title>Pictures</title><link>javascript:alert(1)</link><guid>g2</guid><enclosure url="http://insecure.test/i.png" type="image/png"/></item>
        <item><title></title><link>https://feeds.test/untitled</link><guid>g3</guid></item>
        <item><link>https://feeds.test/no-title</link></item>
        <item><title>Link only</title><link>https://feeds.test/link-only</link></item>
        <item><title>Enclosure picture</title><guid>g5</guid><enclosure url="https://feeds.test/pic.jpg" type="image/jpeg"/></item>
        <item><title>Audio enclosure</title><guid>g6</guid><enclosure url="https://feeds.test/talk.mp3" type="audio/mpeg"/></item>
        """)
        let items = try FeedParser.parse(data, feed: rssFeed)
        #expect(items.map(\.id) == ["g1", "g2", "https://feeds.test/link-only", "g5", "g6"])
        #expect(items[0].title == "Hi & you" && items[0].summary == "Clean text")
        #expect(items[0].url == nil && items[0].imageURL == nil)
        #expect(items[1].url == nil && items[1].imageURL == nil)
        #expect(items[3].imageURL?.absoluteString == "https://feeds.test/pic.jpg")
        #expect(items[4].imageURL == nil, "an audio enclosure is not a picture")
    }

    @Test("An external entity is never read")
    func noExternalEntities() {
        let xml = """
        <?xml version="1.0"?><!DOCTYPE rss [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
        <rss version="2.0"><channel><item><title>&xxe;</title><guid>x</guid><description>&xxe;</description></item></channel></rss>
        """
        let items = (try? FeedParser.parse(Data(xml.utf8), feed: rssFeed)) ?? []
        #expect(!items.contains { $0.title.contains("root:") || $0.summary.contains("root:") })
    }

    @Test("Atom 1.0: alternate link, updated, summary or content")
    func atom() throws {
        let feed = LiveFeed(id: "t.atom", title: "Atom", url: URL(string: "https://feeds.test/atom.xml")!, format: .atom)
        let data = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"><title>Atom</title><id>urn:feed</id><link href="https://feeds.test/" rel="alternate"/>
        <entry><title>Road closed</title><id>urn:entry:1</id><link rel="self" href="https://feeds.test/self/1"/><link rel="alternate" href="https://feeds.test/notices/1"/><updated>2026-11-08T08:30:00Z</updated><summary>Rua Augusta is closed until noon.</summary></entry>
        <entry><title>Metro</title><id>urn:entry:2</id><link href="/notices/2"/><published>2026-11-08T07:00:00Z</published><updated>2026-11-08T09:00:00Z</updated><content type="html">&lt;p&gt;Blue line &lt;b&gt;delayed&lt;/b&gt;.&lt;/p&gt;</content></entry>
        </feed>
        """.utf8)
        let items = try FeedParser.parse(data, feed: feed)
        #expect(items.count == 2)
        #expect(items[0].url?.absoluteString == "https://feeds.test/notices/1", "the alternate link, not rel=self")
        #expect(items[0].published == FeedText.date("2026-11-08T08:30:00Z"))
        #expect(items[0].summary == "Rua Augusta is closed until noon.")
        #expect(items[1].url?.absoluteString == "https://feeds.test/notices/2")
        #expect(items[1].published == FeedText.date("2026-11-08T07:00:00Z"), "published wins over updated")
        #expect(items[1].summary == "Blue line delayed.")
    }

    @Test("JSON Feed 1.1, with a numeric id, a bad item and fields of the wrong type")
    func jsonFeed() throws {
        let feed = LiveFeed(id: "t.json", title: "J", url: URL(string: "https://feeds.test/feed.json")!, format: .jsonFeed)
        let data = Data("""
        {"version":"https://jsonfeed.org/version/1.1","title":"J","items":[
          {"id":"a","url":"https://feeds.test/a","title":"Alpha","content_text":"Plain body","image":"https://feeds.test/a.png","date_published":"2026-11-08T06:00:00Z","tags":["transport","x"]},
          {"id":42,"title":"Numeric id","content_html":"<p>Html body</p>","url":"https://feeds.test/n"},
          {"id":"c","title":7,"url":["x"]},
          "not an object",
          {"id":"d","title":"Typed wrong","date_published":12345,"tags":"nope"}
        ]}
        """.utf8)
        let items = try FeedParser.parse(data, feed: feed)
        #expect(items.map(\.id) == ["a", "42", "d"])
        #expect(items[0].summary == "Plain body" && items[0].category == "transport" && items[0].imageURL != nil)
        #expect(items[0].published == FeedText.date("2026-11-08T06:00:00Z"))
        #expect(items[1].summary == "Html body")
        #expect(items[2].published == nil && items[2].category == nil)
    }

    @Test("promptugal.news newsletter JSON: morning at 07:00 UTC, evening at 18:00 UTC")
    func newsletter() throws {
        let data = Data("""
        {"about":"x","editions":[
          {"date":"2026-11-08","edition":"morning","title":"Morning edition: Sunday 8 November","summary":"What is on today.","authored":false,"page":"https://promptugal.news/newsletter/2026-11-08-morning/","email":"https://promptugal.news/api/v1/newsletter/2026-11-08-morning.txt"},
          {"date":"2026-11-07","edition":"evening","title":"Evening edition: Saturday 7 November","summary":"Today in short.","page":"https://promptugal.news/newsletter/2026-11-07-evening/"}
        ]}
        """.utf8)
        let items = try FeedParser.parse(data, feed: .promptugalNewsletter)
        #expect(items.count == 2)
        #expect(items[0].id == "https://promptugal.news/newsletter/2026-11-08-morning/")
        #expect(items[0].published == FeedText.date("2026-11-08T07:00:00Z"))
        #expect(items[1].published == FeedText.date("2026-11-07T18:00:00Z"))
        #expect(items[0].category == "Newsletter" && items[0].url != nil)
    }

    @Test("Things that are not feeds, and feeds that are too big")
    func notFeeds() {
        #expect(throws: FeedError.notAFeed) { try FeedParser.parse(Data("<html><body>hi</body></html>".utf8), feed: rssFeed) }
        #expect(throws: FeedError.notAFeed) { try FeedParser.parse(Data(), feed: rssFeed) }
        #expect(throws: FeedError.notAFeed) { try FeedParser.parse(Data("{\"a\":1}".utf8), feed: rssFeed) }
        #expect(throws: FeedError.notAFeed) { try FeedParser.parse(Data("<rss".utf8), feed: rssFeed) }
        let jsonFeed = LiveFeed(id: "j", title: "J", url: URL(string: "https://feeds.test/f.json")!, format: .jsonFeed)
        #expect(throws: FeedError.notAFeed) { try FeedParser.parse(Data("<rss/>".utf8), feed: jsonFeed) }
        #expect(throws: FeedError.tooLarge) { try FeedParser.parse(Data(count: FeedLimits.maxBytes + 1), feed: rssFeed) }
    }

    @Test("At most 500 items are read")
    func itemCap() throws {
        let many = (0..<600).map { "<item><title>Item \($0)</title><guid>g\($0)</guid></item>" }.joined()
        let items = try FeedParser.parse(rss(many), feed: rssFeed)
        #expect(items.count == FeedLimits.maxItems)
    }

    @Test("A feed without an empty feed is still a feed: no items")
    func emptyChannel() throws {
        #expect(try FeedParser.parse(rss(""), feed: rssFeed).isEmpty)
    }

    @Test("The feed addresses promptugal.news publishes are https on its own host")
    func defaultFeeds() {
        for feed in [LiveFeed.promptugalArticles, .promptugalNewsletter] {
            #expect(feed.url.scheme == "https" && feed.allowedHosts == ["promptugal.news"])
        }
        #expect(LiveFeed(id: "x", title: "x", url: URL(string: "https://a.test/f")!, format: .rss, limit: 10_000).limit == 500)
    }
}

@Suite("PTSync: feed store")
struct FeedStoreTests {
    private func item(_ id: String, _ title: String = "T", feed: String = "f", at seconds: TimeInterval? = nil) -> FeedItem {
        FeedItem(id: id, feed: feed, title: title, published: seconds.map { Date(timeIntervalSince1970: $0) })
    }

    @Test("Newest first; undated items last")
    func ordering() {
        let sorted = FeedStore.newestFirst([item("old", at: 100), item("none-b", "B"), item("new", at: 300), item("none-a", "A"), item("mid", at: 200)])
        #expect(sorted.map(\.id) == ["new", "mid", "old", "none-a", "none-b"])
    }

    @Test("Merge: fetched items replace kept ones with the same id, older kept items stay, the newest are kept")
    func merging() {
        let old = [item("a", "A old", at: 100), item("b", "B", at: 200), item("c", "C", at: 50)]
        let fetched = [item("a", "A new", at: 100), item("d", "D", at: 300)]
        let merged = FeedStore.merge(old: old, fetched: fetched, limit: 10)
        #expect(merged.map(\.id) == ["d", "b", "a", "c"])
        #expect(merged.first { $0.id == "a" }?.title == "A new")
        #expect(FeedStore.merge(old: old, fetched: fetched, limit: 2).map(\.id) == ["d", "b"])
        #expect(FeedStore.merge(old: [], fetched: [], limit: 5).isEmpty)
    }

    @Test("Items are kept on disk: a new store on the same folder has them, with times and the ETag")
    func persistence() throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let store = FeedStore(directory: dir.url)
        #expect(store.updatedAt == nil && store.generation == 0 && store.items(in: nil).isEmpty)
        let added = try store.update(feed: "f", fetched: [item("a", at: 100), item("b", at: 200)], etag: "\"e1\"", limit: 10, at: Date(timeIntervalSince1970: 1_000))
        #expect(added == 2 && store.generation == 1)
        let reopened = FeedStore(directory: dir.url)
        #expect(reopened.items(in: "f").map(\.id) == ["b", "a"])
        #expect(reopened.updatedAt == Date(timeIntervalSince1970: 1_000) && reopened.updatedAt(feed: "f") == reopened.updatedAt)
        #expect(reopened.etag(for: "f") == "\"e1\"" && reopened.generation == 1)
        #expect(reopened.items(in: "other").isEmpty)
    }

    @Test("The generation changes only when the items do; touching moves the time only")
    func generation() throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let store = FeedStore(directory: dir.url)
        try store.update(feed: "f", fetched: [item("a", at: 1)], etag: nil, limit: 10, at: Date(timeIntervalSince1970: 10))
        try store.update(feed: "f", fetched: [item("a", at: 1)], etag: nil, limit: 10, at: Date(timeIntervalSince1970: 20))
        #expect(store.generation == 1, "same items again")
        try store.touch(feed: "f", at: Date(timeIntervalSince1970: 30))
        #expect(store.generation == 1 && store.updatedAt == Date(timeIntervalSince1970: 30))
        try store.update(feed: "f", fetched: [item("b", at: 2)], etag: nil, limit: 10, at: Date(timeIntervalSince1970: 40))
        #expect(store.generation == 2)
    }

    @Test("All feeds together, newest first; one feed on its own")
    func severalFeeds() throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let store = FeedStore(directory: dir.url)
        try store.update(feed: "x", fetched: [item("x1", feed: "x", at: 100), item("x2", feed: "x", at: 300)], etag: nil, limit: 10, at: .now)
        try store.update(feed: "y", fetched: [item("y1", feed: "y", at: 200)], etag: nil, limit: 10, at: .now)
        #expect(store.items(in: nil).map(\.id) == ["x2", "y1", "x1"])
        #expect(store.items(in: "y").map(\.id) == ["y1"])
    }

    @Test("It is a LiveFeedSource, and registers with PTCore's LiveFeeds")
    func registers() throws {
        let dir = TempDir()
        defer { dir.cleanup(); LiveFeeds.source = nil }
        let store = FeedStore(directory: dir.url)
        try store.update(feed: "f", fetched: [item("a", at: 1)], etag: nil, limit: 10, at: .now)
        LiveFeeds.source = store
        #expect(LiveFeeds.source?.items(in: "f").map(\.id) == ["a"])
        #expect(LiveFeeds.source?.generation == 1)
    }
}

/// Feeds by URL, with ETags and failures the test sets.
final class FakeFeeds: SyncTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var bodies: [URL: Data] = [:]
    private var etags: [URL: String] = [:]
    private var statuses: [URL: Int] = [:]
    private var failing: Set<URL> = []
    private var log: [URL] = []

    func serve(_ url: URL, _ body: Data, etag: String? = nil) {
        lock.withLock { bodies[url] = body; etags[url] = etag }
    }
    func status(_ url: URL, _ code: Int) { lock.withLock { statuses[url] = code } }
    func fail(_ url: URL) { lock.withLock { _ = failing.insert(url) } }
    func requests(_ url: URL) -> Int { lock.withLock { log.filter { $0 == url }.count } }
    var totalRequests: Int { lock.withLock { log.count } }

    func download(_ url: URL, ifNoneMatch: String?, into directory: URL) async throws -> SyncDownload {
        let outcome: (Int, Data?, String?) = try lock.withLock {
            log.append(url)
            if failing.contains(url) { throw URLError(.notConnectedToInternet) }
            if let code = statuses[url] { return (code, nil, nil) }
            guard let body = bodies[url] else { return (404, nil, nil) }
            let tag = etags[url]
            if let tag, tag == ifNoneMatch { return (304, nil, tag) }
            return (200, body, tag)
        }
        guard outcome.0 == 200, let body = outcome.1 else { return SyncDownload(status: outcome.0, file: nil, etag: outcome.2) }
        let file = directory.appendingPathComponent(UUID().uuidString + ".part")
        try body.write(to: file)
        return SyncDownload(status: 200, file: file, etag: outcome.2)
    }
}

@Suite("PTSync: feed syncer")
struct FeedSyncerTests {
    private let articles = LiveFeed(id: "a", title: "Articles", url: URL(string: "https://feeds.test/a.xml")!, format: .rss)
    private let notices = LiveFeed(id: "n", title: "Notices", url: URL(string: "https://notices.test/n.xml")!, format: .rss)

    private func items(_ ids: [(String, String)]) -> Data {
        rss(ids.map { "<item><title>\($0.1)</title><guid>\($0.0)</guid><pubDate>Sat, 07 Nov 2026 09:00:0\(Int($0.0.dropFirst()) ?? 0) GMT</pubDate></item>" }.joined())
    }

    @Test("A refresh keeps the items of every feed; a second one with the same ETag changes nothing but the time")
    func refreshAndNotModified() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        site.serve(articles.url, items([("g1", "One"), ("g2", "Two")]), etag: "\"v1\"")
        site.serve(notices.url, items([("g3", "Notice")]), etag: "\"n1\"")
        let clock = FakeClock(1_000)
        let store = FeedStore(directory: dir.url)
        let syncer = FeedSyncer(store: store, feeds: [articles, notices], transport: site, now: { clock.now() })

        let first = await syncer.refresh()
        #expect(first.updated == ["a", "n"] && first.newItems == 3 && first.failures.isEmpty)
        #expect(store.items(in: nil).count == 3 && store.generation == 2)

        clock.advance(600)
        let second = await syncer.refresh()
        #expect(second.notModified == ["a", "n"] && second.updated.isEmpty && second.newItems == 0)
        #expect(store.updatedAt == Date(timeIntervalSince1970: 1_600))
        #expect(store.generation == 2)
    }

    @Test("New entries are added and the ones the site's feed has dropped are still kept for offline")
    func keepsOlderItems() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        site.serve(articles.url, items([("g1", "One"), ("g2", "Two")]), etag: "\"v1\"")
        let store = FeedStore(directory: dir.url)
        let syncer = FeedSyncer(store: store, feeds: [articles], transport: site)
        _ = await syncer.refresh()
        site.serve(articles.url, items([("g3", "Three"), ("g2", "Two")]), etag: "\"v2\"")
        let report = await syncer.refresh()
        #expect(report.updated == ["a"] && report.newItems == 1)
        #expect(Set(store.items(in: "a").map(\.id)) == ["g1", "g2", "g3"])
    }

    @Test("One feed failing keeps what it had and does not stop the others")
    func failureIsolated() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        site.serve(articles.url, items([("g1", "One")]), etag: "\"v1\"")
        site.serve(notices.url, items([("g2", "Notice")]), etag: "\"n1\"")
        let store = FeedStore(directory: dir.url)
        let syncer = FeedSyncer(store: store, feeds: [articles, notices], transport: site)
        _ = await syncer.refresh()

        site.fail(articles.url)                                   // no network for this one
        site.serve(notices.url, items([("g4", "Notice 2")]), etag: "\"n2\"")
        let report = await syncer.refresh()
        #expect(report.failures.keys.sorted() == ["a"] && report.updated == ["n"])
        #expect(store.items(in: "a").map(\.id) == ["g1"], "the kept items stay")
        #expect(Set(store.items(in: "n").map(\.id)) == ["g2", "g4"])

        site.status(notices.url, 500)
        let again = await syncer.refresh()
        #expect(again.failures.keys.sorted() == ["a", "n"])
        #expect(again.failures["n"] == FeedError.badStatus(500).errorDescription)
    }

    @Test("A feed that is not a feed, too large, or on the wrong address is refused and nothing is kept")
    func refused() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        let html = LiveFeed(id: "h", title: "H", url: URL(string: "https://feeds.test/html")!, format: .rss)
        let big = LiveFeed(id: "b", title: "B", url: URL(string: "https://feeds.test/big")!, format: .rss)
        let insecure = LiveFeed(id: "i", title: "I", url: URL(string: "http://feeds.test/i.xml")!, format: .rss)
        let elsewhere = LiveFeed(id: "e", title: "E", url: URL(string: "https://feeds.test/e.xml")!, format: .rss, allowedHosts: ["other.test"])
        site.serve(html.url, Data("<html>no</html>".utf8))
        site.serve(big.url, Data(count: FeedLimits.maxBytes + 1))
        site.serve(insecure.url, items([("g", "x")]))
        site.serve(elsewhere.url, items([("g", "x")]))
        let store = FeedStore(directory: dir.url)
        let report = await FeedSyncer(store: store, feeds: [html, big, insecure, elsewhere], transport: site).refresh()
        #expect(report.failures.keys.sorted() == ["b", "e", "h", "i"])
        #expect(report.failures["i"] == FeedError.unsafeFeedURL.errorDescription && report.failures["e"] == FeedError.unsafeFeedURL.errorDescription)
        #expect(site.requests(insecure.url) == 0 && site.requests(elsewhere.url) == 0, "never fetched")
        #expect(store.items(in: nil).isEmpty)
    }

    @Test("Two refreshes asked for at once share one run")
    func joins() async throws {
        let dir = TempDir()
        defer { dir.cleanup() }
        let site = FakeFeeds()
        site.serve(articles.url, items([("g1", "One")]), etag: "\"v1\"")
        let syncer = FeedSyncer(store: FeedStore(directory: dir.url), feeds: [articles], transport: site)
        async let first = syncer.refresh()
        async let second = syncer.refresh()
        let (one, two) = await (first, second)
        #expect(one == two)
        #expect(site.requests(articles.url) == 1)
    }
}
