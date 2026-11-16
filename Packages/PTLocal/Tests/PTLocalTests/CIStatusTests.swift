import Foundation
import Testing
@testable import PTLocal

/// A trimmed ci-status.json as scripts/ci-status/collect.py writes it, with one broken run and one unreadable pipeline.
private let statusJSON = """
{"schema":1,"generatedAt":"2026-11-15T23:31:00Z","repo":"PrompTugal/PrompTugal__App__iOS","shipBranch":"dev","refreshMinutes":10,
 "pipelines":[
  {"id":"website","title":"Product site","repo":"PrompTugal/PrompTugal__App__iOS","workflow":"website.yml","available":true,
   "liveLabel":"live on ios.app.promptugal.news",
   "runs":[
    {"id":2,"number":203,"event":"push","branch":"dev","status":"in_progress","conclusion":null,"startedAt":"2026-11-15T23:30:00Z",
     "finishedAt":null,"durationSeconds":60,"running":true,"commit":"abc","shortCommit":"abc","title":"Merge x"},
    {"id":1,"number":202,"url":"https://github.com/x/y/actions/runs/1","event":"push","branch":"dev","status":"completed",
     "conclusion":"success","startedAt":"2026-11-15T23:25:31Z","finishedAt":"2026-11-15T23:27:00Z","durationSeconds":89,
     "running":false,"commit":"def","shortCommit":"def","title":"Merge y","pushToLive":{"pushedAt":"2026-11-15T23:25:31Z","seconds":88}},
    {"number":"no id, so this run is dropped"}
   ],
   "pushToLive":{"latestSeconds":88,"medianSeconds":85,"fastestSeconds":67,"samples":7}},
  {"id":"ios","title":"iOS apps","workflow":"ios.yml","available":true,"liveLabel":"processed in TestFlight","runs":[],
   "pushToLive":{"latestSeconds":1476,"medianSeconds":4176,"fastestSeconds":1476,"samples":6},
   "pushToUpload":{"latestSeconds":1330,"medianSeconds":3327,"fastestSeconds":799,"samples":8}},
  {"id":"news","title":"PrompTugal.news site deploy","available":false,"reason":"GitHub answered 403","runs":[],"pushToLive":null}
 ],
 "testflight":{"available":true,"apps":{
  "promptugal":{"app":"promptugal","bundle":"news.promptugal.reader","version":"0.4.98","build":"601","uploadedAt":"2026-11-11T20:39:51Z","processed":true},
  "fringe":{"app":"fringe","bundle":"news.promptugal.fringe","version":"0.4.102","build":604,"processed":false}}}}
"""

@Suite("CI status")
struct CIStatusTests {
    @Test("ci-status.json decodes; a run without an id is dropped, an unreadable pipeline says why")
    func decodes() throws {
        let status = try #require(CIStatusStore.decode(Data(statusJSON.utf8)))
        #expect(status.pipelines.count == 3)
        #expect(status.generatedAt == CIStatus.date("2026-11-15T23:31:00Z"))
        let site = try #require(status.pipeline("website"))
        #expect(site.runs.count == 2)
        #expect(site.runs[0].outcome == .running)
        #expect(site.runs[1].outcome == .success)
        #expect(site.latestShipped?.number == 202)
        #expect(site.inFlight(branch: "dev")?.number == 203)
        #expect(status.pipeline("ios")?.pushToUpload?.latestSeconds == 1330)
        #expect(status.pipeline("news")?.available == false)
        #expect(status.pipeline("news")?.reason == "GitHub answered 403")
        #expect(status.testFlightBuild(bundle: "news.promptugal.fringe")?.build == "604")   // a number reads as a string
        #expect(status.testFlightBuild(bundle: "news.promptugal.reader")?.processed == true)
    }

    @Test("Update available only when TestFlight's build number is higher than the installed one")
    func updateAvailable() throws {
        let status = try #require(CIStatusStore.decode(Data(statusJSON.utf8)))
        let latest = status.testFlightBuild(bundle: "news.promptugal.reader")
        #expect(InstalledBuild(bundle: "news.promptugal.reader", version: "0.4.90", build: "598").update(against: latest) == .available("601"))
        #expect(InstalledBuild(bundle: "news.promptugal.reader", version: "0.4.98", build: "601").update(against: latest) == .upToDate)
        #expect(InstalledBuild(bundle: "news.promptugal.reader", version: "0.4.99", build: "1000").update(against: latest) == .upToDate)
        #expect(InstalledBuild(bundle: "news.promptugal.reader", version: "1.0", build: "local").update(against: latest) == .unknown)
        #expect(InstalledBuild(bundle: "x", version: nil, build: "1").update(against: nil) == .unknown)
    }

    @Test("A file with no pipelines is not a status")
    func emptyIsNil() {
        #expect(CIStatusStore.decode(Data(#"{"schema":1,"available":false,"pipelines":[]}"#.utf8)) == nil)
        #expect(CIStatusStore.decode(Data("not json".utf8)) == nil)
    }

    @Test("Live first, then the site's copy, then this device's copy, and the screen says which")
    @MainActor func sources() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = LocalDiskCache(directory: dir)
        let installed = InstalledBuild(bundle: "news.promptugal.reader", version: "0.4.90", build: "598")
        let live = CIStatusStore(fetch: { url in
            guard url.host == "raw.githubusercontent.com" else { throw URLError(.fileDoesNotExist) }
            return Data(statusJSON.utf8)
        }, cache: cache, installed: installed)
        await live.refresh()
        #expect(live.source.isLive)
        #expect(live.update == .available("601"))

        let site = CIStatusStore(fetch: { url in
            guard url.host == "ios.app.promptugal.news" else { throw URLError(.notConnectedToInternet) }
            return Data(statusJSON.utf8)
        }, cache: LocalDiskCache(directory: dir.appendingPathComponent("other")), installed: installed)
        await site.refresh()
        if case .siteCopy = site.source {} else { Issue.record("expected the site copy, got \(site.source)") }

        let offline = CIStatusStore(fetch: { _ in throw URLError(.notConnectedToInternet) }, cache: cache, installed: installed)
        await offline.refresh()
        if case .cached = offline.source {} else { Issue.record("expected the cached copy, got \(offline.source)") }
        #expect(offline.status?.pipelines.count == 3)
        #expect(offline.phase == .loaded)
    }

    @Test("Durations read like the website's")
    func durations() {
        #expect(CIStatusView.duration(nil) == "–")
        #expect(CIStatusView.duration(9) == "9s")
        #expect(CIStatusView.duration(85) == "1m 25s")
        #expect(CIStatusView.duration(3720) == "1h 02m")
    }
}
