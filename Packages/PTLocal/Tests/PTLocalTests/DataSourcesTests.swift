import Foundation
import Testing
@testable import PTLocal

private let indexJSON = """
{"version":"v0.1.153","built_at":"2026-11-24T07:34:42.753Z","sources":[
 {"id":"events-pt","title":"Events in Portugal","publisher":"councils and venues","cadence":"twice a day",
  "read_at":"2026-11-21T07:09:28Z","status":"partly failed","headline":"593 events","page":"https://data.promptugal.news/sources/events-pt/"},
 {"id":"ipma-uv","title":"UV index","cadence":"hourly","read_at":"2026-11-21T07:12:29Z","status":"ok","headline":"28 places"},
 {"id":"ipma-warnings","title":"Warnings","cadence":"hourly","read_at":"2026-11-21T07:12:31Z","status":"ok","headline":"23 active warnings in 25 areas"},
 {"id":"ipma","title":"Not a weather feed: no dash","read_at":"2026-11-25T21:00:00Z","status":"ok"},
 {"id":"meteoalarm-pt","title":"MeteoAlarm","read_at":"2026-11-21T07:12:33Z","status":"ok","headline":"82 messages"},
 {"id":"social","title":"Social signals","read_at":"2026-11-21T07:12:53Z","status":"ok","headline":"146 posts"},
 {"id":"storm-charles-archive","title":"Archive","read_at":"2026-11-25T21:30:00Z","status":"archived"},
 {"title":"no id, dropped"}
]}
"""

private let now = ISO8601DateFormatter().date(from: "2026-11-25T22:00:00Z")!
private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

@Suite("Data sources")
struct DataSourcesTests {
    @Test("The catalogue decodes its sources; exact ids; archived ones left out of the newest read")
    func catalogue() throws {
        let index = try JSONDecoder().decode(DataIndex.self, from: Data(indexJSON.utf8))
        #expect(index.sources.count == 7)
        #expect(index.source("ipma-uv")?.headline == "28 places")
        #expect(index.source("ipma-u") == nil)
        #expect(index.weatherSources.map(\.id) == ["ipma-uv", "ipma-warnings", "meteoalarm-pt"])
        #expect(index.newestRead == at("2026-11-25T21:00:00Z"))
    }

    @Test("Weather, events and signals are counted from the catalogue, with their read times")
    func derived() throws {
        let index = try JSONDecoder().decode(DataIndex.self, from: Data(indexJSON.utf8))
        let weather = try #require(DataSiteProbe.reading(site: "weather", index: index))
        #expect(weather.count == 3)
        #expect(weather.readAt == at("2026-11-21T07:12:33Z"))
        #expect(weather.note == "IPMA: 23 active warnings in 25 areas")
        let events = try #require(DataSiteProbe.reading(site: "events", index: index))
        #expect(events.countText == "593 events")
        #expect(events.note == "Last read: partly failed")
        #expect(Freshness.of(events.readAt, now: now).isLive == false)
        #expect(DataSiteProbe.reading(site: "signals", index: index)?.count == 146)
        #expect(DataSiteProbe.reading(site: "news", index: index) == nil)
    }

    @Test("Each site's own feed gives its count and read time")
    func feeds() {
        func read(_ id: String, _ json: String) -> SiteReading? { DataSiteProbe.reading(site: id, data: Data(json.utf8)) }
        #expect(read("news", #"{"built":"2026-11-25","days":45,"items":[1,2,3]}"#)
                == SiteReading(count: 3, unit: "items in the last 45 days", readAt: at("2026-11-25T00:00:00Z")))
        #expect(read("civic", #"{"councils":[{},{}],"sources":[{"read_on":"2026-11-17"},{"read_on":"2026-11-19"}]}"#)?.readAt
                == at("2026-11-19T00:00:00Z"))
        let live = read("live", #"{"read_at":"2026-11-21T08:35:57Z","register_state":"read (913 cameras kept, 0 skipped)","places":[1,2]}"#)
        #expect(live?.countText == "913 cameras")
        #expect(read("live", #"{"places":[1,2]}"#)?.countText == "2 places")
        #expect(read("bulletins", #"{"made":"2026-11-21T08:58:53Z","bulletins":[1,2,3,4,5,6,7,8]}"#)?.count == 8)
        #expect(read("library", #"{"count":82,"items":[]}"#)?.readAt == nil)
        #expect(read("videos", #"{"updated":"2026-11-18T16:10Z","count":32}"#)?.readAt == at("2026-11-18T16:10:00Z"))
        #expect(read("travel", #"{"read_at":"2026-11-19T13:57:09Z","places":[1]}"#)?.countText == "1 places")
        #expect(read("news", "not json") == nil)
        #expect(read("unknown", "{}") == nil)
    }

    @Test("Thirteen sites, each with a site link; only data, not weather or events, reads the catalogue")
    func sites() {
        #expect(DataSite.all.count == 13)
        #expect(Set(DataSite.all.map(\.id)).count == 13)
        #expect(DataSite.all.first { $0.id == "data" }?.feed == DataIndex.url)
        #expect(DataSite.all.first { $0.id == "weather" }?.feed == nil)
    }

    @Test("First number in a headline")
    func numbers() {
        #expect(DataSiteProbe.firstNumber("593 events") == 593)
        #expect(DataSiteProbe.firstNumber("read (913 cameras kept, 0 skipped)") == 913)
        #expect(DataSiteProbe.firstNumber("none") == nil)
        #expect(DataSiteProbe.firstNumber(nil) == nil)
    }

    @Test("The store reads each feed once, derives weather, events and signals, and waits 10 minutes")
    @MainActor func store() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("data-sources-\(UUID().uuidString)")
        let store = DataSourcesStore(fetch: { url in
            if url == DataIndex.url { return Data(indexJSON.utf8) }
            return Data(#"{"count":5,"items":[1,2,3,4,5],"updated":"2026-11-25T21:30:00Z","read_at":"2026-11-25T21:30:00Z"}"#.utf8)
        }, cache: LocalDiskCache(directory: dir), clock: { now })
        await store.load()
        #expect(store.index?.sources.count == 7)
        #expect(store.readings["events"]?.count == 593)
        #expect(store.readings["library"]?.count == 5)
        #expect(store.readings["startups"] == nil)
        #expect(store.provenance["weather"]?.isLive == true)
        let counts = store.freshCounts(now: now)
        #expect(counts.dated > 0 && counts.live < counts.dated)
        LocalDiskCache(directory: dir).clear()
    }
}
