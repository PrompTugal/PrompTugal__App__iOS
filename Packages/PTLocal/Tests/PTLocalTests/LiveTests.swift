import CoreGraphics
import Foundation
import Testing
@testable import PTLocal

private func dashboard(_ json: String) throws -> NewsroomDashboard {
    try JSONDecoder().decode(NewsroomDashboard.self, from: Data(json.utf8))
}

private let before = """
{"built":"v1","at":"2026-11-15T23:00:00.000Z","asks":[],
 "grid_hours":["00","01","02","03"],
 "handoffs":[{"from":"curator","to":"newsroom","n":3}],
 "agents":[
  {"role":"place.faro","agent":"place.faro@PrompTugal.dinis","state":"second pass","updated":"2026-11-15T22:40Z",
   "done":["a"],"next":[],"asks":[],"grid":"··●●","commits_24h":2},
  {"role":"abp","agent":"abp@PrompTugal.dinis","state":"observe","updated":"2026-11-15T22:00Z",
   "last_wake":{"started":"2026-11-15T21:19Z","outcome":"ok","line":"fine"},"done":[],"next":[],"asks":[],"grid":"····"}
 ]}
"""

private let after = """
{"built":"v2","at":"2026-11-15T23:30:00.000Z","asks":[],
 "handoffs":[{"from":"curator","to":"newsroom","n":5},{"from":"detective.places","to":"Dinis","n":1}],
 "agents":[
  {"role":"place.faro","agent":"place.faro@PrompTugal.dinis","state":"third pass live","updated":"2026-11-15T23:20Z",
   "done":["a","b","c"],"next":[],"asks":["Dinis: allow postal.pt"]},
  {"role":"abp","agent":"abp@PrompTugal.dinis","state":"observe","updated":"2026-11-15T22:00Z",
   "last_wake":{"started":"2026-11-15T23:19Z","outcome":"ok","line":"four reviewed"},"done":[],"next":[],"asks":[]},
  {"role":"viz.places","agent":"viz.places@PrompTugal.dinis","focus":"maps","updated":"2026-11-15T23:59Z"}
 ]}
"""

private let now = ISO8601DateFormatter().date(from: "2026-11-15T23:30:00Z")!

@Suite("Live newsroom")
struct LiveTests {
    @Test("The latest ticker lists each update and wake, newest first, with town names")
    func latestTicker() throws {
        let events = NewsroomDiff.latest(try dashboard(before), now: now)
        #expect(events.count == 3)
        #expect(events.first?.text == "place.faro@ updated Faro")
        #expect(events.first?.detail == "second pass")
        #expect(events.contains { $0.kind == .wake && $0.text == "abp@ woke: ok" })
        #expect(zip(events, events.dropFirst()).allSatisfy { $0.date >= $1.date })
        #expect(events.allSatisfy { $0.origin == .latest })
    }

    @Test("Diffing two dashboards finds updates with new done items, wakes, asks, handoffs and new agents")
    func diff() throws {
        let events = NewsroomDiff.changes(from: try dashboard(before), to: try dashboard(after), now: now)
        let kinds = events.map(\.kind)
        #expect(kinds.contains(.done))
        #expect(kinds.contains(.wake))
        #expect(kinds.contains(.ask))
        #expect(kinds.contains(.joined))
        #expect(events.filter { $0.kind == .handoff }.count == 2)
        let done = try #require(events.first { $0.kind == .done })
        #expect(done.text == "place.faro@ updated Faro: 2 new done")
        #expect(done.detail == "c")
        let handoff = try #require(events.first { $0.kind == .handoff && $0.role == "curator" })
        #expect(handoff.text == "curator → newsroom: 2 new handoffs")
        #expect(events.allSatisfy { $0.origin == .watched })
        // An agent that did not change says nothing; abp only woke.
        #expect(events.filter { $0.role == "abp" }.map(\.kind) == [.wake])
    }

    @Test("The same dashboard twice changes nothing")
    func noChange() throws {
        let d = try dashboard(after)
        #expect(NewsroomDiff.changes(from: d, to: d, now: now).isEmpty)
    }

    @Test("A time written ahead of the clock is read as now")
    func futureClamped() throws {
        let events = NewsroomDiff.changes(from: try dashboard(before), to: try dashboard(after), now: now)
        let joined = try #require(events.first { $0.kind == .joined })
        #expect(joined.date == now)
        let viz = try #require(try dashboard(after).agents.first { $0.role == "viz.places" })
        #expect(viz.lastSign(now: now) == now)
    }

    @Test("Merging keeps each line once, newest in front, capped")
    func merge() throws {
        let latest = NewsroomDiff.latest(try dashboard(before), now: now)
        let merged = NewsroomDiff.merge(latest, into: latest)
        #expect(merged.count == latest.count)
        #expect(NewsroomDiff.merge(latest, into: [], cap: 2).count == 2)
    }

    @Test("New stories and map entries in a place file become ticker lines")
    func placeDiff() throws {
        let base = """
        {"id":"faro","name":"Faro","status":"researching","updated":"2026-11-15","by":"place.faro@PrompTugal.dinis","mandate":"m",
         "ai_news":[{"title":"Old","url":"https://e.org/1"}],"ai_map":[{"name":"UAlg","source_url":"https://ualg.pt"}]}
        """
        let next = """
        {"id":"faro","name":"Faro","status":"live","updated":"2026-11-16","by":"place.faro@PrompTugal.dinis","mandate":"m",
         "ai_news":[{"title":"Old","url":"https://e.org/1"},{"title":"New A","url":"https://e.org/2"},{"title":"New B","url":"https://e.org/3"}],
         "ai_map":[{"name":"UAlg","source_url":"https://ualg.pt"},{"name":"Dengun","source_url":"https://dengun.com"}]}
        """
        let a = try JSONDecoder().decode(PlaceSite.self, from: Data(base.utf8))
        let b = try JSONDecoder().decode(PlaceSite.self, from: Data(next.utf8))
        let events = NewsroomDiff.placeChanges(from: ["faro": a], to: ["faro": b], now: now)
        #expect(events.map(\.kind) == [.stories, .mapped, .live])
        #expect(events[0].text == "place.faro@ updated Faro: 2 new stories")
        #expect(events[0].detail == "New A")
        #expect(events[1].detail == "Dengun")
        #expect(NewsroomDiff.roles(in: events) == ["place.faro"])
    }

    @Test("The extra fields decode: the 24-hour grid and commits")
    func extras() throws {
        let extras = try JSONDecoder().decode(LiveDashboardExtras.self, from: Data(before.utf8))
        #expect(extras.gridHours.count == 4)
        #expect(extras.agents["place.faro"]?.fired == [false, false, true, true])
        #expect(extras.agents["place.faro"]?.commits24h == 2)
        #expect(extras.agents["abp"]?.fired == [false, false, false, false])
        #expect(WakeGrid.rows(extras).map(\.role) == ["place.faro"])
    }

    @Test("Activity fades from 1 to 0 over its window")
    func decay() {
        #expect(LiveNewsroom.decay(since: now, now: now, window: 600) == 1)
        #expect(abs(LiveNewsroom.decay(since: now.addingTimeInterval(-300), now: now, window: 600) - 0.5) < 0.0001)
        #expect(LiveNewsroom.decay(since: now.addingTimeInterval(-601), now: now, window: 600) == 0)
    }

    @Test("Ago reads like a person would say it")
    func ago() {
        #expect(LiveTicker.ago(now, now: now) == "now")
        #expect(LiveTicker.ago(now.addingTimeInterval(-125), now: now) == "2 min ago")
        #expect(LiveTicker.ago(now.addingTimeInterval(-7200), now: now) == "2 h ago")
    }
}

@Suite("Live layout")
struct LiveLayoutTests {
    private var roles: [String] {
        ["place.portugal", "place.algarve"] + PlaceDirectory.towns.map { "place.\($0.id)" }
            + ["detective.places", "viz.places", "data.places", "abp", "conductor", "security", "librarian"]
    }

    @Test("Every agent gets one node, inside the board, and the outsiders a handoff names join them")
    func nodes() {
        let nodes = NewsroomLayout.nodes(roles: roles, handoffs: [(from: "curator", to: "newsroom"), (from: "detective.places", to: "Dinis"), (from: "abp@PrompTugal.dinis", to: "conductor")])
        #expect(Set(nodes.map(\.id)).count == nodes.count)
        #expect(nodes.count == roles.count + 3)
        #expect(nodes.allSatisfy { (0...1).contains($0.point.x) && (0...1).contains($0.point.y) })
        #expect(nodes.filter { $0.kind == .outside }.map(\.label) == ["curator", "newsroom", "Dinis"])
        #expect(nodes.first { $0.id == "place.algarve" }?.kind == .region)
        #expect(nodes.filter { $0.kind == .town }.count == 17)
        #expect(nodes.filter { $0.kind == .placeDesk }.count == 3)
    }

    @Test("Towns keep their order on the map: Lagos west of Faro, Faro west of Tavira; Alcoutim north of Faro")
    func geography() {
        let nodes = NewsroomLayout.nodes(roles: roles, handoffs: [])
        func p(_ id: String) -> CGPoint { nodes.first { $0.id == "place.\(id)" }!.point }
        #expect(p("lagos").x < p("faro").x)
        #expect(p("faro").x < p("tavira").x)
        #expect(p("alcoutim").y < p("faro").y)
        let band = NewsroomLayout.townBand
        #expect(nodes.filter { $0.kind == .town }.allSatisfy { band.insetBy(dx: -0.001, dy: -0.001).contains($0.point) })
    }

    @Test("No two nodes sit on top of each other")
    func spacing() {
        let nodes = NewsroomLayout.nodes(roles: roles, handoffs: [(from: "curator", to: "newsroom"), (from: "x", to: "Dinis")])
        for (i, a) in nodes.enumerated() {
            for b in nodes[(i + 1)...] {
                #expect(hypot(a.point.x - b.point.x, a.point.y - b.point.y) > 0.01, "\(a.id) and \(b.id) overlap")
            }
        }
    }

    @Test("A handoff name finds its agent by role or address, or stays outside")
    func handoffNames() {
        let set = Set(roles)
        #expect(NewsroomLayout.nodeID(for: "abp", roles: set) == "abp")
        #expect(NewsroomLayout.nodeID(for: "abp@PrompTugal.dinis", roles: set) == "abp")
        #expect(NewsroomLayout.nodeID(for: "Dinis", roles: set) == "outside:Dinis")
    }

    @Test("The handoff curve starts at the sender and ends at the receiver")
    func curve() {
        let a = CGPoint(x: 0, y: 0), b = CGPoint(x: 1, y: 0)
        #expect(NewsroomLayout.curvePoint(from: a, to: b, t: 0) == a)
        #expect(NewsroomLayout.curvePoint(from: a, to: b, t: 1) == b)
        #expect(NewsroomLayout.curvePoint(from: a, to: b, t: 0.5).y != 0)
    }
}

@Suite("Algarve cartogram")
struct CartogramTests {
    @Test("The tile map has every town once, no two in one cell, all inside the grid")
    func tiles() {
        #expect(Set(AlgarveCartogram.tiles.keys) == Set(PlaceDirectory.towns.map(\.id)))
        let cells = AlgarveCartogram.tiles.values.map { "\($0.col),\($0.row)" }
        #expect(Set(cells).count == cells.count)
        #expect(AlgarveCartogram.tiles.values.allSatisfy { (0..<AlgarveCartogram.columns).contains($0.col) && (0..<AlgarveCartogram.rows).contains($0.row) })
    }

    @Test("Radii follow area: four times the stories, twice the radius; nothing still shows")
    func radii() {
        let r = AlgarveCartogram.radii(["a": 16, "b": 4, "c": 0], maxRadius: 40, minRadius: 8)
        #expect(r["a"] == 40)
        #expect(r["b"] == 20)
        #expect(r["c"] == 8)
    }

    @Test("The Dorling layout leaves no overlaps, stays in bounds, and is deterministic")
    func dorling() {
        let size = CGRect(x: 0, y: 0, width: 360, height: 160)
        let aspect = AlgarveCartogram.aspect
        let w = min(size.width, size.height * aspect), h = w / aspect
        let start = PlaceDirectory.towns.enumerated().map { i, info -> AlgarveCartogram.Bubble in
            let u = AlgarveCartogram.unitPoint(latitude: info.latitude, longitude: info.longitude)
            let p = CGPoint(x: u.x * w, y: u.y * h)
            return AlgarveCartogram.Bubble(id: info.id, center: p, radius: CGFloat(8 + (i % 5) * 4), home: p)
        }
        #expect(AlgarveCartogram.worstOverlap(start) > 0)
        let placed = AlgarveCartogram.dorling(start, bounds: size)
        #expect(AlgarveCartogram.worstOverlap(placed) < 1.0)
        #expect(placed.allSatisfy { size.insetBy(dx: -0.5, dy: -0.5).contains(CGRect(x: $0.center.x - $0.radius, y: $0.center.y - $0.radius, width: $0.radius * 2, height: $0.radius * 2)) })
        #expect(placed == AlgarveCartogram.dorling(start, bounds: size))
    }

    @Test("Intensity is a square-root scale between 0 and 1")
    func intensity() {
        #expect(AlgarveCartogram.intensity(25, max: 100) == 0.5)
        #expect(AlgarveCartogram.intensity(200, max: 100) == 1)
        #expect(AlgarveCartogram.intensity(5, max: 0) == 0)
    }
}

@Suite("This story, these agents")
struct StoryAgentsTests {
    @Test("A story is credited to the agent that writes each site carrying it, and to desks whose notes name its town")
    func credits() throws {
        let faro = try JSONDecoder().decode(PlaceSite.self, from: Data("""
        {"id":"faro","name":"Faro","status":"live","updated":"2026-11-15","by":"place.faro@PrompTugal.dinis","mandate":"m",
         "ai_news":[{"title":"Vibathon","url":"https://e.org/v","read_on":"2026-11-15","publisher":"Barlavento"}]}
        """.utf8))
        let region = try JSONDecoder().decode(PlaceSite.self, from: Data("""
        {"id":"algarve","name":"The Algarve","status":"live","updated":"2026-11-15","by":"place.algarve@PrompTugal.dinis","mandate":"m",
         "ai_news":[{"title":"Vibathon","url":"https://e.org/v"}]}
        """.utf8))
        let dash = try dashboard("""
        {"agents":[{"role":"detective.places","agent":"detective.places@PrompTugal.dinis","state":"sweeping Faro and Loulé"},
                   {"role":"abp","agent":"abp@PrompTugal.dinis","state":"policies"}]}
        """)
        let story = faro.aiNews[0]
        let credits = StoryAgents.credits(for: story, places: ["faro": faro, "algarve": region], dashboard: dash)
        #expect(credits.map(\.role) == ["place.algarve", "place.faro", "detective.places"])
        #expect(credits[1].how == .wrote)
        #expect(credits[1].note.contains("Faro's site"))
        #expect(credits[2].how == .mentions)
        #expect(credits[2].note.contains("Faro"))
    }
}

@Suite("Live strips")
struct LiveStripTests {
    @Test("Faces get two letters: a town's initials, or the desk's name")
    func initials() {
        #expect(AgentFace.initials("place.vila-do-bispo") == "VB")
        #expect(AgentFace.initials("place.faro") == "Fa")
        #expect(AgentFace.initials("place.algarve") == "Al")
        #expect(AgentFace.initials("abp") == "Ab")
        #expect(AgentFace.initials("detective.places") == "De")
    }

    @Test("The home strip shows the agents with the latest sign of life first")
    func recent() throws {
        let d = try JSONDecoder().decode(NewsroomDashboard.self, from: Data(after.utf8))
        let recent = NewsroomLiveSection.recentAgents(d, now: now, limit: 2)
        #expect(recent.map(\.role) == ["viz.places", "place.faro"])
    }

    @Test("A shared watcher reads at most once a minute")
    func due() {
        #expect(LiveNewsroom.isDue(lastPoll: nil, now: now))
        #expect(!LiveNewsroom.isDue(lastPoll: now.addingTimeInterval(-30), now: now))
        #expect(LiveNewsroom.isDue(lastPoll: now.addingTimeInterval(-60), now: now))
    }
}

@Suite("Algarve map component")
struct AlgarveMapComponentTests {
    private let town = AlgarveMapTown(id: "faro", name: "Faro", latitude: 37.0, longitude: -7.9, accentHex: "#0B5C7A",
                                      live: true, stories: 14, mapped: 12, agentLastSign: now.addingTimeInterval(-7200))

    @Test("The measures read stories, map entries and agent activity")
    func metrics() {
        #expect(AlgarveMetric.stories.value(town, now: now) == 14)
        #expect(AlgarveMetric.mapped.value(town, now: now) == 12)
        let fresh = AlgarveMetric.fresh.value(town, now: now)
        #expect(abs(fresh - (1 - 2.0 / 24)) < 0.0001)
        #expect(AlgarveMetric.fresh.label(fresh) == "2h")
        #expect(AlgarveMetric.fresh.label(0) == "–")
    }

    @Test("Short names fit the tiles")
    func shortNames() {
        #expect(AlgarveAbstractMap.shortName(id: "vila-real-de-santo-antonio", name: "Vila Real de Santo António") == "VRSA")
        #expect(AlgarveAbstractMap.shortName(id: "faro", name: "Faro") == "Faro")
    }
}

@Suite("Replay")
struct ReplayTests {
    @Test("An agent is lit in the hours it fired and fades after")
    func activity() {
        let fired = [false, true, false, false, false]
        #expect(LiveReplay.activity(fired: fired, at: 0.5) == 0)
        #expect(LiveReplay.activity(fired: fired, at: 1.2) == 1)
        #expect(abs(LiveReplay.activity(fired: fired, at: 2.75) - 0.5) < 0.0001)
        #expect(LiveReplay.activity(fired: fired, at: 3.6) == 0)
        #expect(LiveReplay.activity(fired: [], at: 1) == 0)
    }

    @Test("Per-hour counts add up the agents that fired")
    func perHour() throws {
        let extras = LiveDashboardExtras(gridHours: ["00", "01", "02"], agents: [
            "a": .init(fired: [true, false, true], commits24h: 0),
            "b": .init(fired: [true, true, false], commits24h: 0),
        ])
        #expect(LiveReplay.perHour(extras) == [2, 1, 1])
    }
}

@Suite("Ticker filters")
struct TickerFilterTests {
    @Test("Towns, desks and asks split the ticker")
    func filters() {
        let town = LiveEvent(date: now, role: "place.faro", kind: .update, text: "t", origin: .latest)
        let desk = LiveEvent(date: now, role: "abp", kind: .wake, text: "d", origin: .latest)
        let ask = LiveEvent(date: now, role: "abp", kind: .ask, text: "a", origin: .watched)
        #expect(TickerFilter.all.includes(town) && TickerFilter.all.includes(ask))
        #expect(TickerFilter.towns.includes(town) && !TickerFilter.towns.includes(desk))
        #expect(TickerFilter.desks.includes(desk) && !TickerFilter.desks.includes(ask) && !TickerFilter.desks.includes(town))
        #expect(TickerFilter.asks.includes(ask) && !TickerFilter.asks.includes(desk))
    }
}

@Suite("Live summary")
struct LiveSummaryTests {
    @Test("Headline numbers come from the dashboard")
    func summary() throws {
        let d = try JSONDecoder().decode(NewsroomDashboard.self, from: Data(before.utf8))
        let extras = try JSONDecoder().decode(LiveDashboardExtras.self, from: Data(before.utf8))
        let s = LiveSummary.make(d, extras: extras, now: now)
        #expect(s.agents == 2)
        // faro updated 22:40 and abp's last sign 22:00 are both older than 30 minutes at 23:30.
        #expect(s.activeNow == 0)
        #expect(s.firedHours24h == 2)
        #expect(s.handoffs24h == 3)
        #expect(s.asksWaiting == 0)
        let later = LiveSummary.make(d, extras: extras, now: ISO8601DateFormatter().date(from: "2026-11-15T22:50:00Z")!)
        #expect(later.activeNow == 1)
    }
}
