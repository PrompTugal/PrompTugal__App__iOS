import Foundation
import Testing
@testable import PTLocal

private let statusJSON = """
{"version":"v0.1.2280","built":"2026-11-25","page":"https://promptugal.news/newsroom/index.html",
 "counts":{"runs":50,"agents":31,"note":"not a number"},
 "ledger":{"lines":44,"last":{"short":"e0c13ee","when":"2026-11-05T03:45:45Z"}},
 "agents":[
  {"id":"curator-vicky","name":"curator@web-summit.vicky","status":"running","page":"https://promptugal.news/newsroom/agents/curator-vicky.html"},
  {"id":"curator","name":"curator@other","page":"javascript:alert(1)"}
 ],
 "pipeline":[
  {"stage":"research","label":"Research","state":"running","desks":["researcher-vicky"],
   "last_run":{"id":"r1","when":"2026-11-05T19:30:00Z","what":"the summit"}},
  {"stage":"write","label":"Write","state":"planned","desks":["desk-journalist"],"last_run":null},
  {"label":"no stage, dropped"}
 ],
 "runs":[
  {"id":"a","when":"2026-11-05T19:45:00Z","kind":"desk","by":"curator@web-summit.vicky","agent":"curator-vicky","what":"2 new captures","issues":[]},
  {"id":"b","when":"2026-11-05T20:15:00Z","kind":"desk","by":"curator@other","agent":"curator","what":"connections"},
  {"id":"c","when":"2026-11-30T00:00:00Z","kind":"work","agent":"newsroom-dinis","what":"ahead of the clock"},
  {"id":"d","what":"no time, dropped"}
 ]}
"""

private func decode() throws -> NewsroomStatus {
    try JSONDecoder().decode(NewsroomStatus.self, from: Data(statusJSON.utf8))
}

private let now = ISO8601DateFormatter().date(from: "2026-11-25T22:00:00Z")!

@Suite("Newsroom status feed")
struct NewsroomStatusTests {
    @Test("Decodes the pipeline and runs, dropping items that do not fit")
    func decodes() throws {
        let status = try decode()
        #expect(status.version == "v0.1.2280")
        #expect(status.counts["runs"] == 50)
        #expect(status.counts["note"] == nil)
        #expect(status.pipeline.map(\.stage) == ["research", "write"])
        #expect(status.pipeline[0].lastRun?.what == "the summit")
        #expect(status.pipeline[1].lastRun == nil)
        #expect(status.runs.map(\.id) == ["a", "b", "c"])
        #expect(status.ledgerLast == "2026-11-05T03:45:45Z")
    }

    @Test("Recent runs newest first, a time ahead of the clock sorting as now")
    func recent() throws {
        let status = try decode()
        #expect(status.recentRuns(limit: 2, now: now).map(\.id) == ["c", "b"])
        #expect(status.newestRun(now: now) == now)
    }

    @Test("Each run opens its own agent's page; an unsafe or missing page falls back to the status page")
    func links() throws {
        let status = try decode()
        let runs = status.runs
        #expect(status.link(for: runs[0]).absoluteString == "https://promptugal.news/newsroom/agents/curator-vicky.html")
        // "curator" is a prefix of "curator-vicky": it must not borrow that agent's page.
        #expect(status.link(for: runs[1]) == status.pageURL)
        #expect(status.link(for: runs[2]) == status.pageURL)
        #expect(runs[0].handle == "curator")
        #expect(runs[2].handle == "newsroom-dinis")
    }

    @Test("The feed's own time is the day it was built, so it reads as a snapshot by evening")
    func freshness() throws {
        let status = try decode()
        #expect(Freshness.of(status.builtAt, now: now).isLive == false)
    }
}
