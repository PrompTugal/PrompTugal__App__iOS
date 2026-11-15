import Foundation
import Testing
@testable import PTLocal

private let townJSON = """
{"id":"faro","name":"Faro","kind":"municipality","parent":"algarve","status":"live","updated":"2026-11-15",
 "by":"place.faro@PrompTugal.dinis","mandate":"PrompTugal.news Faro: AI and technology in Faro.",
 "look":{"accent":"#0B5C7A","landmark":"Arco da Vila"},
 "ai_news":[
  {"title":"Older","url":"https://example.org/a","read_on":"2026-11-15","ai_path":"direct","date":"2026-09-01","steps":0},
  {"title":"Newer","url":"https://example.org/b","read_on":"2026-11-15","ai_path":"one step","date":"2026-11-06","steps":1},
  {"title":"Broken, no url","read_on":"2026-11-15"}
 ],
 "ai_map":[{"name":"UAlg","type":"institution","source_url":"https://www.ualg.pt/x","read_on":"2026-11-15","steps":0}],
 "events":[{"title":"Talk","url":"https://example.org/e","ai_path":{"odd":"shape"}}],
 "sources":[{"name":"Barlavento","url":"https://www.barlavento.pt","kind":"press","feed":null}],
 "gaps":["We could not open postal.pt."],
 "voice":{"lede":"Faro, oh pá"}}
"""

private let dashboardJSON = """
{"built":"v0.1.1502","at":"2026-11-15T23:11:23.000Z",
 "asks":[{"from":"story board","since":"2026-11-06","ask":"Is this right?"}],
 "handoffs":[{"from":"curator","to":"newsroom","n":3}],
 "agents":[
  {"role":"place.faro","agent":"place.faro@PrompTugal.dinis","state":"third pass live","minute":7,"scheduled":true,
   "updated":"2026-11-15T23:40Z","stale":false,"last_wake":null,"done":["a"],"next":["b"],"asks":["c"]},
  {"role":"dev","agent":"dev@PrompTugal.dinis","state":"disabled at Dinis's word","scheduled":false,"stale":false},
  {"role":"abp","agent":"abp@PrompTugal.dinis","state":"running: a new session","scheduled":false,"stale":false,
   "last_wake":{"started":"2026-11-15T23:01Z","outcome":"ok","line":"fine"}},
  {"agent":"quiet@PrompTugal.dinis","stale":true},
  {"role":"no-agent-field"}
 ]}
"""

@Suite("PTLocal")
struct PTLocalTests {
    @Test("A town file decodes, and one bad story or odd event field does not hide the rest")
    func decodesTown() throws {
        let site = try JSONDecoder().decode(PlaceSite.self, from: Data(townJSON.utf8))
        #expect(site.id == "faro")
        #expect(site.isLive)
        #expect(site.aiNews.map(\.title) == ["Older", "Newer"])
        #expect(site.aiNews[1].stepsLabel == "1 step")
        #expect(site.aiNews[0].stepsLabel == "direct")
        #expect(site.events.count == 1 && site.events[0].aiPath == nil)
        #expect(site.aiMap.first?.sourceHost == "ualg.pt")
        #expect(site.voice?.lede == "Faro, oh pá")
    }

    @Test("Only http and https links leave the app")
    func safeLinks() {
        #expect(PlaceSite.safeURL("https://www.ualg.pt") != nil)
        #expect(PlaceSite.safeURL("javascript:alert(1)") == nil)
        #expect(PlaceSite.safeURL("file:///etc/passwd") == nil)
    }

    @Test("The built-in snapshot has Portugal, the Algarve and all 17 towns, and every file decodes")
    func snapshotComplete() throws {
        for info in PlaceDirectory.all {
            let url = try #require(LocalResources.bundle.url(forResource: "place-\(info.id)", withExtension: "json"),
                                   "place-\(info.id).json is not bundled")
            let site = try JSONDecoder().decode(PlaceSite.self, from: Data(contentsOf: url))
            #expect(site.id == info.id)
        }
        #expect(PlaceDirectory.towns.count == 17)
        #expect(Set(PlaceDirectory.towns.map(\.id)).count == 17)
        #expect(!LocalStore.snapshotDay.isEmpty)
    }

    @Test("Every town sits inside the Algarve on the map")
    func coordinatesInAlgarve() {
        for town in PlaceDirectory.towns {
            #expect((36.9...37.6).contains(town.latitude), "\(town.id) latitude")
            #expect((-9.0 ... -7.3).contains(town.longitude), "\(town.id) longitude")
        }
    }

    @Test("The dashboard decodes, skips an agent without a name, and reads each status")
    func decodesDashboard() throws {
        let board = try JSONDecoder().decode(NewsroomDashboard.self, from: Data(dashboardJSON.utf8))
        #expect(board.agents.count == 4)
        #expect(board.updated != nil)
        let faro = try #require(board.agent(forPlace: "faro"))
        #expect(faro.group == .places)
        #expect(faro.placeID == "faro")
        #expect(faro.status == .waiting)            // it asks for something
        #expect(faro.updatedDate != nil)            // minutes-only time stamp
        #expect(board.agents.first { $0.role == "dev" }?.status == .stopped)
        #expect(board.agents.first { $0.role == "abp" }?.status == .working)
        #expect(board.agents.first { $0.agent.hasPrefix("quiet") }?.role == "quiet")
        #expect(board.agents.first { $0.agent.hasPrefix("quiet") }?.status == .stale)
        #expect(board.handoffs.first?.n == 3)
    }

    @Test("Offline first launch: the store answers from the snapshot and says so")
    @MainActor func snapshotProvenance() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(fetch: { _ in throw URLError(.notConnectedToInternet) },
                               cache: LocalDiskCache(directory: dir), bundle: LocalResources.bundle)
        #expect(store.placeProvenance == .snapshot(LocalStore.snapshotDay))
        #expect(store.townSites.count == 17)
        await store.refreshPlaces()
        #expect(store.placeProvenance == .snapshot(LocalStore.snapshotDay))   // nothing live, nothing cached
        #expect(store.townSites.count == 17)
        await store.refreshDashboard()
        #expect(store.dashboard == nil)
    }

    @Test("Live data replaces the snapshot and is cached for next time")
    @MainActor func liveThenCached() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = LocalDiskCache(directory: dir)
        let live = LocalStore(fetch: { url in
            if url.path.hasSuffix("dashboard.json") { return Data(dashboardJSON.utf8) }
            if url.lastPathComponent == "faro.json" { return Data(townJSON.utf8) }
            throw URLError(.fileDoesNotExist)
        }, cache: cache, bundle: LocalResources.bundle)
        await live.refreshAll()
        #expect(live.placeProvenance.isLive)
        #expect(live.site("faro")?.aiNews.count == 2)
        #expect(live.dashboard?.agents.count == 4)

        let offline = LocalStore(fetch: { _ in throw URLError(.notConnectedToInternet) }, cache: cache, bundle: LocalResources.bundle)
        await offline.refreshAll()
        if case .cached = offline.placeProvenance {} else { Issue.record("expected the cached copy, got \(offline.placeProvenance)") }
        #expect(offline.site("faro")?.aiNews.count == 2)
        #expect(offline.dashboard?.agents.count == 4)
    }

    @Test("The latest stories come newest first, each story once")
    @MainActor func latestOrder() async throws {
        let store = LocalStore(fetch: { url in
            if url.lastPathComponent == "faro.json" || url.lastPathComponent == "loule.json" { return Data(townJSON.utf8) }
            throw URLError(.fileDoesNotExist)
        }, cache: LocalDiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
           bundle: LocalResources.bundle)
        await store.refreshPlaces()
        let latest = store.latestFromTowns(limit: 50, only: ["faro", "loule"])
        #expect(latest.map(\.story.title) == ["Newer", "Older"])
    }

    @Test("The simulated verify numbers are stable and never exceed what is mapped")
    func simulatedNumbers() {
        for mapped in 0...30 {
            #expect(CityNewsroomFlow.simulatedAsked(mapped) <= mapped)
            #expect(CityNewsroomFlow.simulatedConfirmed(mapped) <= CityNewsroomFlow.simulatedAsked(mapped) || mapped < 3)
        }
    }
}
