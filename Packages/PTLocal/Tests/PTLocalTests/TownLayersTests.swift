import Foundation
import Testing
@testable import PTLocal

private let eventsJSON = """
{"data_read_at":"2026-11-21T09:20:40Z","place":"faro","read_at":"2026-11-21T09:20:40Z","count":5,
 "events":[
  {"@type":"Event","name":"Over already","startDate":"2026-11-21","endDate":null,
   "location":{"@type":"Place","name":"Teatro das Figuras"},"url":"https://teatrodasfiguras.pt/agenda/a","read_at":"2026-11-21T07:10:04Z"},
  {"@type":"Event","name":"Tonight","startDate":"2026-11-25","endDate":null,
   "location":{"@type":"Place","name":"Teatro das Figuras"},"url":"https://teatrodasfiguras.pt/agenda/b"},
  {"@type":"Event","name":"Runs on","startDate":"2026-11-01","endDate":"2026-12-31",
   "location":"Museu Municipal","url":null,"source":"https://cm-faro.pt/agenda (Faro council agenda page)"},
  {"@type":"Event","name":"No link at all","startDate":"2026-12-01","url":"javascript:alert(1)"},
  {"@type":"Event","startDate":"2026-12-02","url":"https://x.pt/no-name"}
 ]}
"""

private let noticesJSON = """
{"summary":{"read_on":"2026-11-19","still_open":4},
 "still_open":[
  {"notice":"1/2026","council":"faro","published":"2026-11-01","deadline":"2026-11-30","what":"Later","base_price_eur":6640085,
   "diario_da_republica":"https://files.diariodarepublica.pt/a.pdf"},
  {"notice":"2/2026","council":"faro","deadline":"2026-11-26","what":"Sooner","base_price_eur":33625.5,
   "diario_da_republica":"https://files.diariodarepublica.pt/b.pdf"},
  {"notice":"3/2026","council":"faro","deadline":"2026-11-22","what":"Closed","diario_da_republica":"https://files.diariodarepublica.pt/c.pdf"},
  {"notice":"4/2026","council":"faro-sul","deadline":"2026-12-09","what":"Another council whose id starts with faro"},
  {"council":"faro","what":"no notice number, dropped"}
 ]}
"""

private let councilJSON = """
{"id":"faro","name":"Faro","page":"https://civic.promptugal.news/councils/faro/",
 "contracts_2026":{"contracts":199,"value_eur":11747495,"direct_awards":115},
 "sources":[{"title":"BASE","url":"https://dados.gov.pt/","read_on":"2026-11-17"},{"title":"old","read_on":"2026-11-10"}]}
"""

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

/// 25 Nov 2026, 22:00 in Lisbon (UTC in winter).
private let now = ISO8601DateFormatter().date(from: "2026-11-25T22:00:00Z")!

@Suite("Town layers: events and council notices")
struct TownLayersTests {
    @Test("Events: only those not over today, soonest first, each with a safe link; a nameless one is dropped")
    func events() throws {
        let feed = try decode(TownEventsFeed.self, eventsJSON)
        #expect(feed.events.count == 4)
        #expect(feed.readDate == ISO8601DateFormatter().date(from: "2026-11-21T09:20:40Z"))
        let upcoming = feed.upcoming(now: now)
        #expect(upcoming.map(\.name) == ["Runs on", "Tonight"])
        #expect(upcoming[0].venue == "Museu Municipal")
        #expect(upcoming[0].link?.absoluteString == "https://cm-faro.pt/agenda")
        #expect(upcoming[1].venue == "Teatro das Figuras")
    }

    @Test("Events read on 21 Nov say snapshot on 25 Nov")
    func eventsFreshness() throws {
        let feed = try decode(TownEventsFeed.self, eventsJSON)
        #expect(Freshness.of(feed.readDate, now: now).isLive == false)
    }

    @Test("Notices: this council only (exact id), still open today, soonest deadline first")
    func notices() throws {
        let feed = try decode(CivicNotices.self, noticesJSON)
        #expect(feed.stillOpen.count == 4)
        #expect(feed.readOn == "2026-11-19")
        let open = feed.open(council: "faro", now: now)
        #expect(open.map(\.notice) == ["2/2026", "1/2026"])
        #expect(open[1].basePriceEUR == 6640085)
        #expect(open[0].link?.host() == "files.diariodarepublica.pt")
        #expect(feed.open(council: "faro-sul", now: now).map(\.notice) == ["4/2026"])
        #expect(feed.open(council: "far", now: now).isEmpty)
    }

    @Test("Council file: its page, 2026 contracts and newest source read")
    func council() throws {
        let file = try decode(CivicCouncil.self, councilJSON)
        #expect(file.name == "Faro")
        #expect(file.contracts2026 == 199)
        #expect(file.value2026 == 11747495)
        #expect(file.readOn == "2026-11-17")
        #expect(file.pageURL?.absoluteString == "https://civic.promptugal.news/councils/faro/")
    }

    @Test("Which council a place has: the 16 by their own id, Quarteira in Loulé, none for the region or country")
    func councilForPlace() {
        #expect(CivicCouncil.ids.count == 16)
        #expect(CivicCouncil.council(for: "vila-real-de-santo-antonio") == "vila-real-de-santo-antonio")
        #expect(CivicCouncil.council(for: "quarteira") == "loule")
        #expect(CivicCouncil.council(for: "algarve") == nil)
        #expect(CivicCouncil.council(for: "portugal") == nil)
        #expect(CivicCouncil.council(for: "lago") == nil)
    }

    @Test("Formatting: days and euros")
    func formatting() {
        #expect(TownLayerDates.day("2026-11-25") == "25 Nov")
        #expect(TownLayerDates.day("2026-12-01T19:00:00+00:00") == "1 Dec")
        #expect(TownLayerDates.day("soon") == "soon")
        #expect(TownLayerDates.euros(6640085) == "€6,640,085")
    }

    @Test("The store reads events and civic feeds once, then keeps them for 10 minutes")
    @MainActor func storeReads() async throws {
        let counter = FetchCounter()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("town-layers-\(UUID().uuidString)")
        let store = TownLayersStore(fetch: { url in
            await counter.add(url)
            if url.host() == "data.promptugal.news" { return Data(eventsJSON.utf8) }
            let body: String = url.path.contains("councils") ? councilJSON : noticesJSON
            return Data(body.utf8)
        }, cache: LocalDiskCache(directory: dir), clock: { now })
        await store.load(placeID: "faro")
        await store.load(placeID: "faro")
        #expect(await counter.count == 3)
        #expect(store.events["faro"]?.value.events.count == 4)
        #expect(store.councils["faro"]?.value.contracts2026 == 199)
        #expect(store.notices?.value.stillOpen.count == 4)
        #expect(store.events["faro"]?.provenance.isLive == true)
        await store.load(placeID: "portugal")
        #expect(await counter.count == 4)
        LocalDiskCache(directory: dir).clear()
    }
}

private actor FetchCounter {
    private(set) var urls: [URL] = []
    var count: Int { urls.count }
    func add(_ url: URL) { urls.append(url) }
}
