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
