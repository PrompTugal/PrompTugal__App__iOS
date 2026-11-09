import Foundation
import Testing
@testable import PTCore

private struct FakeSource: ContentSource {
    let files: [String: Data]
    let generation: Int
    func data(at path: String) -> Data? { files[path] }
}

@Suite("Content sources", .serialized)
struct ContentSourceTests {
    @Test("A registered source is found by site id, replaced by a later one, and removed")
    func registry() {
        defer { ContentSources.unregister("test.site") }
        #expect(ContentSources.source(for: "test.site") == nil)
        ContentSources.register(FakeSource(files: ["a.json": Data("1".utf8)], generation: 1), for: "test.site")
        #expect(ContentSources.source(for: "test.site")?.data(at: "a.json") == Data("1".utf8))
        #expect(ContentSources.source(for: "other.site") == nil)
        ContentSources.register(FakeSource(files: [:], generation: 2), for: "test.site")
        #expect(ContentSources.source(for: "test.site")?.generation == 2)
        #expect(ContentSources.source(for: "test.site")?.data(at: "a.json") == nil)
        ContentSources.unregister("test.site")
        #expect(ContentSources.source(for: "test.site") == nil)
    }
}

private struct FakeFeeds: LiveFeedSource {
    let all: [FeedItem]
    var updatedAt: Date? { nil }
    var generation: Int { 1 }
    func items(in feed: String?) -> [FeedItem] { feed.map { name in all.filter { $0.feed == name } } ?? all }
}

@Suite("Live feeds", .serialized)
struct LiveFeedsTests {
    @Test("The registered feed source is the one readers get, and it can be removed")
    func registry() {
        defer { LiveFeeds.source = nil }
        #expect(LiveFeeds.source == nil)
        LiveFeeds.source = FakeFeeds(all: [FeedItem(id: "1", feed: "a", title: "One"), FeedItem(id: "2", feed: "b", title: "Two")])
        #expect(LiveFeeds.source?.items(in: nil).count == 2)
        #expect(LiveFeeds.source?.items(in: "b").map(\.title) == ["Two"])
        LiveFeeds.source = nil
        #expect(LiveFeeds.source == nil)
    }

    @Test("A feed item survives a JSON round trip, links and all")
    func codable() throws {
        let item = FeedItem(id: "g", feed: "f", title: "T", summary: "S", url: URL(string: "https://example.test/a"),
                            imageURL: URL(string: "https://example.test/i.png"), published: Date(timeIntervalSince1970: 1_000), category: "News")
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(FeedItem.self, from: data) == item)
    }
}

private struct FakeFiles: ContentSource {
    let files: [String: String]
    var generation: Int { 1 }
    func data(at path: String) -> Data? { files[path].map { Data($0.utf8) } }
}

// Part of the serialized suite above: these tests also set `LiveFeeds.source`.
extension LiveFeedsTests {
    private func item(_ id: String, _ url: String?, title: String = "T", at seconds: TimeInterval = 100) -> FeedItem {
        FeedItem(id: id, feed: LiveContent.articlesFeedID, title: title, summary: "S", url: url.flatMap(URL.init(string:)),
                 published: Date(timeIntervalSince1970: seconds), category: "News")
    }

    @Test("A feed entry becomes a story only with a title and an https link on promptugal.news")
    func storyMapping() {
        #expect(Story(item("a", "https://promptugal.news/articles/a.html"))?.url.absoluteString == "https://promptugal.news/articles/a.html")
        #expect(Story(item("a", "https://promptugal.news/articles/a.html"))?.category == "News")
        #expect(Story(item("b", "https://other.test/b")) == nil, "another host")
        #expect(Story(item("c", "http://promptugal.news/c")) == nil, "not https")
        #expect(Story(item("d", nil)) == nil, "no link")
        #expect(Story(item("e", "https://promptugal.news/e", title: "")) == nil, "no title")
    }

    @Test("Stories come from the registered feeds, newest first as the source gives them, without repeats, capped")
    func stories() {
        defer { LiveFeeds.source = nil }
        #expect(LiveContent.stories().isEmpty, "nothing registered")
        LiveFeeds.source = FakeFeeds(all: [item("a", "https://promptugal.news/a"), item("b", "https://elsewhere.test/b"),
                                                item("a", "https://promptugal.news/a"), item("c", "https://promptugal.news/c")])
        #expect(LiveContent.stories().map(\.id) == ["a", "c"])
        #expect(LiveContent.stories(limit: 1).map(\.id) == ["a"])
    }

    @Test("The agenda comes from the synced files, sorted, and is nil when absent or unreadable")
    func agenda() {
        defer { ContentSources.unregister(LiveContent.siteID) }
        #expect(LiveContent.agenda() == nil, "nothing registered")
        let json = """
        {"items":[{"date":"2026-11-10","time":"10:00-10:30","title":"Later","place":"P","kind":"talk","official":true,"page":"events/b/index.html"},
                  {"date":"2026-11-09","time":"09:00-09:30","title":"Earlier","place":"P","kind":"talk","official":true,"page":"events/a/index.html"}]}
        """
        ContentSources.register(FakeFiles(files: [LiveContent.agendaPath: json]), for: LiveContent.siteID)
        #expect(LiveContent.agenda()?.map(\.title) == ["Earlier", "Later"])
        ContentSources.register(FakeFiles(files: [LiveContent.agendaPath: "{\"items\":[]}"]), for: LiveContent.siteID)
        #expect(LiveContent.agenda() == nil, "an empty agenda is not used")
        ContentSources.register(FakeFiles(files: [LiveContent.agendaPath: "not json"]), for: LiveContent.siteID)
        #expect(LiveContent.agenda() == nil)
        ContentSources.register(FakeFiles(files: [:]), for: LiveContent.siteID)
        #expect(LiveContent.agenda() == nil)
    }
}
