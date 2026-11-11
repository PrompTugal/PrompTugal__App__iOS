import Foundation
import PTCore
import Testing
@testable import PTFringe

@Suite("Fringe events")
struct FringeEventTests {
    private func seed() throws -> [FringeEvent] {
        try FringeFeed.events(from: try #require(FringeStore.bundledSeed()))
    }

    @Test("the bundled seed (a copy of the live events.json) decodes, in day and time order, with a time on every event")
    func seedDecodes() throws {
        let events = try seed()
        #expect(events.count > 60)
        #expect(events.allSatisfy { $0.start != nil && !$0.date.isEmpty })
        #expect(events == events.sorted(by: FringeEvent.earlier))
        #expect(Set(events.map(\.id)).count == events.count)
    }

    @Test("status is unknown when the feed says nothing, and never guessed")
    func unknownStatus() throws {
        let data = Data(#"{"events":[{"name":"A","date":"2026-11-12"},{"name":"B","date":"2026-11-12","status":"weird"}]}"#.utf8)
        let events = try FringeFeed.events(from: data)
        #expect(events.map(\.statusValue) == [.unknown, .unknown])
        #expect(events.allSatisfy { $0.start == nil && !$0.isPickable })
    }

    @Test("only the name is required: an event with no date is kept, sorted last, and cannot be picked")
    func nameOnly() throws {
        let data = Data(#"{"events":[{"name":"Floating"},{"name":"Dated","date":"2026-11-12"}]}"#.utf8)
        let events = try FringeFeed.events(from: data)
        #expect(events.map(\.name) == ["Dated", "Floating"])
        #expect(events[1].date.isEmpty && !events[1].isPickable)
    }

    @Test("a malformed event is skipped and the rest are kept; a bare array and items also read")
    func lenient() throws {
        let one = Data(#"{"events":[{"date":"2026-11-12"},{"name":"Ok","date":"2026-11-12"}]}"#.utf8)
        #expect(try FringeFeed.events(from: one).map(\.name) == ["Ok"])
        let bare = Data(#"[{"name":"X","date":"2026-11-13"}]"#.utf8)
        #expect(try FringeFeed.events(from: bare).count == 1)
        let items = Data(#"{"items":[{"name":"Y","date":"2026-11-13"}]}"#.utf8)
        #expect(try FringeFeed.events(from: items).count == 1)
    }

    @Test("the served feed's ISO instants become Lisbon clocks, and its extra fields read")
    func liveShape() throws {
        let data = Data(#"""
        {"events":[{"id":"2026-11-11-x","name":"X","date":"2026-11-11","start":"2026-11-11T08:30:00Z","end":"2026-11-11T10:00:00Z",
          "kind":"meetup","status":"cancelled","cost":"free","label":"Fact","storm_moved":true,"check":"The page says so."},
         {"name":"Late","start":"2026-11-12T23:00:00Z","end":"2026-11-13T00:30:00Z"},
         {"name":"Plain","date":"2026-11-12","start":"2026-11-12T09:15:00.000Z"},
         {"name":"Bad","date":"2026-11-12","start":"soon","storm_moved":"maybe"}]}
        """#.utf8)
        let events = try FringeFeed.events(from: data)
        let x = try #require(events.first { $0.name == "X" })
        #expect(x.start == "08:30" && x.end == "10:00" && x.date == "2026-11-11")
        #expect(x.id == "2026-11-11-x" && x.cost == "free" && x.labelText == "Fact" && x.movedByStorm && !x.check.isEmpty)
        let late = try #require(events.first { $0.name == "Late" })
        #expect(late.date == "2026-11-12" && late.start == "23:00" && late.end == "00:30")
        let end = try #require(late.endDate)
        let start = try #require(late.startDate)
        #expect(end.timeIntervalSince(start) == 90 * 60)
        #expect(events.first { $0.name == "Plain" }?.start == "09:15")
        let bad = try #require(events.first { $0.name == "Bad" })
        #expect(bad.start == nil && bad.stormMoved == nil && !bad.movedByStorm && bad.labelText == nil)
    }

    @Test("clocks: only HH:mm, anything else is no time")
    func clocks() {
        #expect(FringeEvent.clock("18:30") == "18:30")
        #expect(FringeEvent.clock("08:15:00") == "08:15")
        #expect(FringeEvent.clock("TBC") == nil)
        #expect(FringeEvent.clock("") == nil)
        #expect(FringeEvent.clock(nil) == nil)
        #expect(FringeEvent.clock("25:00") == nil)
    }

    @Test("the plan event carries the id as its page, and a nominal hour only when the end is missing")
    func planEvent() {
        let timed = FringeEvent(name: "Open Coffee", date: "2026-11-12", start: "09:30", end: "11:30")
        #expect(timed.planEvent.time == "09:30-11:30")
        #expect(timed.id == "2026-11-12-open-coffee-0930")
        #expect(timed.planEvent.page == "events/2026-11-12-open-coffee-0930/index.html")
        let keyed = FringeEvent(name: "Open Coffee", date: "2026-11-12", start: "09:30", end: "11:30", id: "site-id.7")
        #expect(keyed.id == "site-id.7" && keyed.planEvent.page == "events/site-id.7/index.html")
        let open = FringeEvent(name: "Late", date: "2026-11-12", start: "18:00")
        #expect(open.planEvent.time == "18:00-19:00")
        #expect(open.timeLabel != "18:00-19:00")
        let none = FringeEvent(name: "Untimed", date: "2026-11-12")
        #expect(none.planEvent.time.isEmpty && !none.isPickable)
    }

    @Test("a cancelled event cannot be picked")
    func cancelledNotPickable() {
        let event = FringeEvent(name: "Gone", date: "2026-11-12", start: "10:00", end: "11:00", status: "cancelled")
        #expect(!event.isPickable)
    }

    @Test("slugs are ASCII, hyphenated and short")
    func slug() {
        #expect(FringeEvent.slug("Open Coffee Lisbon #53!") == "open-coffee-lisbon-53")
        #expect(FringeEvent.slug("São Bento café") == "sao-bento-cafe")
        #expect(FringeEvent.slug(String(repeating: "a", count: 200)).count == 60)
    }
}

@Suite("Fringe filters and now")
struct FringeFilterTests {
    private let events = [
        FringeEvent(name: "A", kind: "meetup", date: "2026-11-12", start: "09:00", end: "10:00", topics: ["AI", "founders"]),
        FringeEvent(name: "B", kind: "workshop", date: "2026-11-12", start: "11:00", end: "12:00", topics: ["design"]),
        FringeEvent(name: "C", kind: "meetup", date: "2026-11-13", start: "09:00", end: "10:00", topics: ["ai"]),
        FringeEvent(name: "D", kind: "meetup", date: "2026-11-12", start: "12:30", end: "13:30", status: "cancelled"),
        FringeEvent(name: "E", kind: "party", date: "2026-11-12"),
    ]

    @Test("day, kind and topic combine, and topics match without case")
    func combine() {
        #expect(FringeFilter(day: "2026-11-12").apply(events).map(\.name) == ["A", "B", "D", "E"])
        #expect(FringeFilter(kind: "meetup").apply(events).map(\.name) == ["A", "C", "D"])
        #expect(FringeFilter(topic: "AI").apply(events).map(\.name) == ["A", "C"])
        #expect(FringeFilter(day: "2026-11-12", kind: "meetup", topic: "ai").apply(events).map(\.name) == ["A"])
        #expect(FringeFilter().apply(events).count == 5)
        #expect(!FringeFilter().isActive && FringeFilter(day: "x").isActive)
    }

    @Test("the storm filter keeps only what the site says the storm moved")
    func stormFilter() {
        let list = [
            FringeEvent(name: "Moved", date: "2026-11-12", start: "09:00", stormMoved: true),
            FringeEvent(name: "Same", date: "2026-11-12", start: "10:00", stormMoved: false),
            FringeEvent(name: "Unsaid", date: "2026-11-12", start: "11:00"),
        ]
        #expect(FringeFilter(stormMoved: true).apply(list).map(\.name) == ["Moved"])
        #expect(FringeFilter(stormMoved: false).apply(list).count == 3)
        #expect(FringeFilter(stormMoved: true).isActive)
    }

    @Test("quick days: today, tomorrow and the day after, named, in Lisbon time")
    func quickDays() throws {
        let now = try #require(Lisbon.instant(day: "2026-11-11", clock: "23:30"))
        let days = FringeFilter.quickDays(now: now, locale: Locale(identifier: "en"))
        #expect(days.map(\.id) == ["2026-11-11", "2026-11-12", "2026-11-13"])
        #expect(days.map(\.label) == ["Today", "Tomorrow", "Friday"])
    }

    @Test("the options come from the data")
    func options() {
        #expect(FringeFilter.days(in: events) == ["2026-11-12", "2026-11-13"])
        #expect(FringeFilter.kinds(in: events) == ["meetup", "party", "workshop"])
        #expect(FringeFilter.topics(in: events) == ["ai", "design", "founders"])
    }

    @Test("now and next: live now, later today, untimed today; cancelled never listed")
    func nowAndNext() throws {
        let now = try #require(Lisbon.instant(day: "2026-11-12", clock: "09:30"))
        let model = FringeNow(events: events, now: now)
        #expect(model.onNow.map(\.name) == ["A"])
        #expect(model.next.map(\.name) == ["B"])
        #expect(model.untimed.map(\.name) == ["E"])
        let late = try #require(Lisbon.instant(day: "2026-11-12", clock: "13:00"))
        let model2 = FringeNow(events: events, now: late)
        #expect(model2.onNow.isEmpty && model2.next.isEmpty)
    }
}

@Suite("Fringe network rules")
struct FringeNetworkTests {
    @Test("only lisbontechfringe.com and storm-charles.promptugal.news over https")
    func hosts() throws {
        #expect(FringeHosts.isAllowed(FringeHosts.events))
        #expect(FringeHosts.isAllowed(FringeHosts.storm))
        #expect(!FringeHosts.isAllowed(try #require(URL(string: "http://lisbontechfringe.com/api/v1/events.json"))))
        #expect(!FringeHosts.isAllowed(try #require(URL(string: "https://websummit.com/"))))
        #expect(!FringeHosts.isAllowed(try #require(URL(string: "https://lisbontechfringe.com.evil.example/"))))
        #expect(!FringeHosts.isAllowed(try #require(URL(string: "https://fringe.promptugal.news/api/v1/events.json"))))   // the old host is dropped
        #expect(FringeHosts.allowed.count == 2)
    }

    @Test("the storm headline reads from the index and survives the round trip the store keeps")
    func storm() throws {
        let index = Data(#"""
        {"built_at":"2026-11-11T10:46:01.238Z","site":"https://storm-charles.promptugal.news/",
         "incidents":[{"title":"Storm Charles","status":"open","headline":{"text":"Day 2 is off","source":"Web Summit","url":"https://example.org/x","at":"10 Nov 19:09 UTC"}}]}
        """#.utf8)
        let headline = try #require(StormHeadline.parse(index))
        #expect(headline.text == "Day 2 is off" && headline.incident == "Storm Charles")
        let kept = try JSONEncoder().encode(headline.asIndex)
        #expect(StormHeadline.parse(kept) == headline)
        #expect(StormHeadline.parse(Data("{}".utf8)) == nil)
    }

    @MainActor
    @Test("the store starts from the seed, and a kept copy wins over the seed")
    func store() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("fringe-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = FringeStore(directory: directory)
        #expect(first.source == .seed && first.events.count > 60)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"events":[{"name":"Kept","date":"2026-11-12"}]}"#.utf8).write(to: directory.appendingPathComponent("events.json"))
        let second = FringeStore(directory: directory)
        #expect(second.source == .cache && second.events.map(\.name) == ["Kept"])
    }
}
