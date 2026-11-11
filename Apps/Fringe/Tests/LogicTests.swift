import Foundation
import Testing
@testable import Fringe

/// Lisbon times in November are UTC, so "Z" times read the same on the clock.
private func t(_ s: String) -> Date { FeedDate.parse(s)! }

private func event(_ id: String, _ start: String?, _ end: String?, date: String = "2026-11-12",
                   status: String = "on", place: String = "Some venue, Rua X 1, 1000-001 Lisboa (Beato)",
                   inLisbon: Bool? = true) -> FeedEvent {
    FeedEvent(id: id, name: id, date: date, start: start.map(t), end: end.map(t), place: place,
              status: status, inLisbon: inLisbon)
}

@Suite struct FeedParsing {
    @Test func parsesTheBundledCopy() throws {
        let url = try #require(Bundle.main.url(forResource: "events", withExtension: "json"))
        let feed = try EventFeed.decode(Data(contentsOf: url))
        #expect(feed.events.count > 100)
        #expect(feed.builtAt != nil)
        #expect(feed.events.allSatisfy { !$0.id.isEmpty && !$0.date.isEmpty })
    }

    @Test func toleratesMissingAndNewFields() throws {
        let json = """
        {"built_at":"2026-11-11T18:02:41.058Z","events":[
          {"id":"a","name":"A","date":"2026-11-12","start":"2026-11-12T17:00:00Z","end":null,"brand_new":1},
          {"name":"No id","start":"2026-11-13T09:00:00Z"},
          {"id":"bad"}
        ]}
        """
        let feed = try EventFeed.decode(Data(json.utf8))
        #expect(feed.events.count == 2)
        #expect(feed.events[0].end == nil)
        #expect(feed.events[1].date == "2026-11-13")
        #expect(feed.builtAt != nil)
    }

    @Test func communityHostLines() throws {
        let json = """
        {"communities":[{"id":"x","name":"X","what":{"text":"Since 2019, we help."},"events":["e1"]},
                        {"id":"y","name":"Y","what":null,"events":["e2"]}]}
        """
        let c = try JSONDecoder().decode(CommunityFeed.self, from: Data(json.utf8))
        #expect(c.hostLines == ["e1": "Since 2019, we help."])
    }
}

@Suite struct LisbonAndOnline {
    @Test func online() {
        #expect(event("a", nil, nil, status: "online", place: "Zoom").category == .online)
        #expect(event("b", nil, nil, status: "unknown", place: "online (stream)", inLisbon: false).category == .online)
    }

    @Test func nearLisbonAndFarAway() {
        let sintra = event("s", nil, nil, place: "R. Barbosa du Bocage 16, 2710-405 Sintra, Portugal", inLisbon: false)
        #expect(sintra.category == .inPerson(nearLisbon: true))
        #expect(sintra.area == "Sintra, near Lisbon")
        #expect(event("e", nil, nil, place: "Address given to guests, Estoril (Estoril)", inLisbon: false).area == "Estoril, near Lisbon")
        #expect(event("c", nil, nil, place: "UBI, 6200-358 Covilhã, Portugal", inLisbon: false).category == .hidden)
        #expect(event("m", nil, nil, place: "Estação Biológica de Mértola, Mértola", inLisbon: false).category == .hidden)
        #expect(event("n", nil, nil, place: "CNEMA, 2000-471 Santarém", inLisbon: false).category == .hidden)
    }

    @Test func lisbonAreaEndsInLisboa() {
        #expect(event("a", nil, nil).area == "Beato, Lisboa")
        #expect(event("b", nil, nil, place: "Address given to guests, Lisboa").area == "Address given to guests, Lisboa")
        let lines = event("c", nil, nil, place: "Av. Duque de Loulé 24, Av. Duque de Loulé 24, 1050-085 Lisboa (Marquês de Pombal)").addressLines
        #expect(lines.first == "Av. Duque de Loulé 24")
        #expect(lines.second == "1050-085 Lisboa, near Marquês de Pombal")
    }

    @Test func privateAddressHasNoMap() {
        #expect(event("a", nil, nil, place: "Address given to guests, Lisboa").mapsURL == nil)
        #expect(event("b", nil, nil).mapsURL?.host == "maps.apple.com")
    }

    @Test func bundledCountsMatchTheRules() throws {
        let url = try #require(Bundle.main.url(forResource: "events", withExtension: "json"))
        let events = try EventFeed.decode(Data(contentsOf: url)).events
        let hidden = events.filter { $0.category == .hidden }
        #expect(hidden.allSatisfy { e in ["Covilh", "Mértola", "Santar"].contains { (e.place ?? "").contains($0) } || e.inLisbon == false })
        #expect(events.filter { $0.category == .online }.count >= 19)
        #expect(!events.contains { $0.category != .hidden && $0.category != .online && ($0.place ?? "").contains("Covilh") })
    }

    @Test func statusWords() {
        #expect(event("a", nil, nil, status: "moved").eventStatus.word == "Moved")
        #expect(event("a", nil, nil, status: "cancelled").eventStatus.word == "Cancelled")
        #expect(event("a", nil, nil, status: "on").eventStatus.word == nil)
    }
}

@Suite struct Times {
    @Test func pastMidnightStaysOnStartDay() {
        let party = event("p", "2026-11-12T21:00:00Z", "2026-11-13T02:00:00Z")
        #expect(party.endsNextDay)
        #expect(party.timeRange == "21:00 to 02:00 +1")
        #expect(DayPart.of(party) == .evening)
        #expect(Planner.days(of: [party]).map(\.key) == ["2026-11-12"])
    }

    @Test func partsOfTheDay() {
        #expect(DayPart.of(event("a", "2026-11-12T09:00:00Z", nil)) == .morning)
        #expect(DayPart.of(event("a", "2026-11-12T12:00:00Z", nil)) == .afternoon)
        #expect(DayPart.of(event("a", "2026-11-12T18:00:00Z", nil)) == .evening)
        #expect(DayPart.of(event("a", nil, nil)) == .noTime)
    }

    @Test func onNowComesFirst() {
        let a = event("a", "2026-11-12T16:00:00Z", "2026-11-12T19:00:00Z")
        let b = event("b", "2026-11-12T18:30:00Z", "2026-11-12T20:00:00Z")
        let c = event("c", "2026-11-12T09:00:00Z", "2026-11-12T10:00:00Z")
        let sections = Planner.sections([b, c, a], now: t("2026-11-12T17:00:00Z"), isToday: true)
        #expect(sections.map(\.part) == [.onNow, .morning, .evening])
        #expect(sections[0].events.map(\.id) == ["a"])
        let other = Planner.sections([b, c, a], now: t("2026-11-12T17:00:00Z"), isToday: false)
        #expect(other.map(\.part) == [.morning, .afternoon, .evening])
    }

    @Test func whenText() {
        let e = event("a", "2026-11-12T18:30:00Z", "2026-11-12T21:00:00Z")
        #expect(Planner.whenText(e, now: t("2026-11-12T17:10:00Z")) == "in 1 h 20 min")
        #expect(Planner.whenText(e, now: t("2026-11-12T18:40:00Z")) == "on now")
    }
}

@Suite struct SavedAndCalendar {
    let agents = event("agents", "2026-11-12T17:00:00Z", "2026-11-12T19:30:00Z", status: "moved")
    let show = event("show", "2026-11-12T18:30:00Z", "2026-11-12T21:00:00Z")
    let party = event("party", "2026-11-12T21:00:00Z", "2026-11-13T02:00:00Z")

    @Test func clashes() {
        let health = event("health", "2026-11-12T17:00:00Z", "2026-11-12T20:00:00Z")
        #expect(Planner.clashes(health, with: [agents, show]))
        #expect(!Planner.clashes(party, with: [show]))  // touching ends do not clash
        let cancelled = event("x", "2026-11-12T18:00:00Z", "2026-11-12T19:00:00Z", status: "cancelled")
        #expect(!Planner.clashes(cancelled, with: [agents]))
    }

    @Test func overlapSentence() {
        let text = Planner.daySummary(day: Day(key: "2026-11-12"), saved: [agents, show, party])
        #expect(text == "Thu 12: 3 saved. Two overlap from 18:30 to 19:30.")
        #expect(Planner.daySummary(day: Day(key: "2026-11-14"), saved: []) == "Sat 14: nothing saved yet.")
    }

    @Test func threeAtOnce() {
        let third = event("third", "2026-11-12T18:00:00Z", "2026-11-12T19:00:00Z")
        let o = Planner.overlaps([agents, show, third])
        #expect(o.count == 1)
        #expect(o.first?.count == 3)
        #expect(o.first.map { FeedDate.hhmm($0.start) } == "18:00")
        #expect(o.first.map { FeedDate.hhmm($0.end) } == "19:30")
    }

    @Test func columns() {
        let p = Planner.placements([agents, show, party])
        #expect(p["agents"] == Planner.Placement(column: 0, columns: 2))
        #expect(p["show"] == Planner.Placement(column: 1, columns: 2))
        #expect(p["party"] == Planner.Placement(column: 0, columns: 1))
    }

    @Test func coloursFollowStartOrder() {
        #expect(Planner.colourIndex(of: party, in: [party, show, agents]) == 2)
    }

    @Test func nextSkipsEndedAndCancelled() {
        let gone = event("gone", "2026-11-12T09:00:00Z", "2026-11-12T10:00:00Z")
        let off = event("off", "2026-11-12T17:30:00Z", "2026-11-12T18:00:00Z", status: "cancelled")
        #expect(Planner.next(of: [gone, off, show, agents], now: t("2026-11-12T17:10:00Z"))?.id == "agents")
    }

    @MainActor @Test func savedStoreKeepsIDs() throws {
        let defaults = try #require(UserDefaults(suiteName: "ltf-tests-\(UUID().uuidString)"))
        let store = SavedStore(defaults: defaults)
        store.toggle(show)
        #expect(store.isSaved(show))
        #expect(SavedStore(defaults: defaults).ids == ["show"])
        store.toggle(show)
        #expect(!store.isSaved(show))
    }

    @Test func changeNotices() {
        let before = event("e", "2026-11-11T17:00:00Z", "2026-11-11T19:00:00Z", date: "2026-11-11")
        let snapshot = ["e": SavedStore.fingerprint(before)]
        let moved = event("e", "2026-11-12T17:00:00Z", "2026-11-12T19:00:00Z", status: "moved")
        let r = SavedStore.changes(savedIDs: ["e"], snapshot: snapshot, events: [moved])
        #expect(r.notices.map(\.text) == ["e has moved. It is now Thursday 12, 17:00 to 19:00."])
        let cancelled = event("e", "2026-11-11T17:00:00Z", "2026-11-11T19:00:00Z", date: "2026-11-11", status: "cancelled")
        #expect(SavedStore.changes(savedIDs: ["e"], snapshot: snapshot, events: [cancelled]).notices.map(\.text) == ["e is cancelled."])
        #expect(SavedStore.changes(savedIDs: ["e"], snapshot: snapshot, events: [before]).notices.isEmpty)
    }
}
