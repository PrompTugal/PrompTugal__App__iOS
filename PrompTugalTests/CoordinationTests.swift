import Foundation
import Testing
@testable import PrompTugal

@Suite("Where is everyone")
struct CoordinationTests {
    private func event(_ time: String, _ slug: String, place: String = "Centre Stage", day: String = "2026-11-10") -> Event {
        Event(date: day, time: time, title: slug.capitalized, place: place, kind: "talk", official: true,
              page: "events/\(slug)/index.html")
    }

    private var events: [Event] {
        [event("09:00-09:30", "alpha"), event("09:15-09:45", "beta", place: "Stage 2"),
         event("11:00-11:30", "gamma"), event("15:00-15:20", "delta"), event("10:00-10:30", "other", day: "2026-11-11")]
    }

    private func plan(_ person: String, _ ids: [String]) -> TeammatePlan {
        TeammatePlan(person: person, name: person, source: .me, pickIds: ids, loadedAt: .now)
    }

    @Test("Sessions with two or more of us, in time order")
    func together() {
        let plans = [plan("dinis", ["events/alpha", "events/gamma"]),
                     plan("silvio", ["events/gamma/index.html", "events/alpha"]),
                     plan("vicky", ["beta"])]
        let result = CoordinationAnalysis.build(plans: plans, events: events, day: "2026-11-10")
        #expect(result.together.map(\.event.title) == ["Alpha", "Gamma"])
        #expect(result.together.first?.people == ["dinis", "silvio"])
        #expect(result.perPerson["vicky"] == 1)
        #expect(result.peoplePerDay["2026-11-10"] == 3)
    }

    @Test("A clash is two of one person's picks at the same time; back-to-back is not")
    func clashes() {
        let plans = [plan("dinis", ["events/alpha", "events/beta", "events/gamma"])]
        let result = CoordinationAnalysis.build(plans: plans, events: events, day: "2026-11-10")
        #expect(result.clashes.count == 1)
        #expect(result.clashes.first?.first.title == "Alpha" && result.clashes.first?.second.title == "Beta")
        // Negative control: touching but not overlapping.
        let a = event("09:00-09:30", "a"), b = event("09:30-10:00", "b")
        #expect(!CoordinationAnalysis.overlaps(a, b))
        #expect(CoordinationAnalysis.overlaps(a, event("09:29-10:00", "c")))
    }

    @Test("Meet here: after a shared session, then free windows that keep stand-ups free")
    func meetSlots() throws {
        let plans = [plan("dinis", ["events/alpha", "events/delta"]), plan("silvio", ["events/alpha"])]
        let result = CoordinationAnalysis.build(plans: plans, events: events, day: "2026-11-10")
        let first = try #require(result.meetSlots.first)
        #expect(first.kind == .afterSession(events[0]))
        let half = try #require(Lisbon.instant(day: "2026-11-10", clock: "09:30"))
        #expect(first.start == half)
        let free = result.meetSlots.filter { $0.kind == .freeWindow }
        #expect(!free.isEmpty && free.count <= 3)
        for slot in free {
            for standup in ["13:00", "18:00"] {
                let start = try #require(Lisbon.instant(day: "2026-11-10", clock: standup))
                #expect(!(slot.start < start.addingTimeInterval(1800) && start < slot.end), "no free window over a stand-up")
            }
        }
    }

    @Test("Free windows: gaps of at least the minimum, none inside busy time")
    func freeWindows() throws {
        func at(_ clock: String) throws -> Date { try #require(Lisbon.instant(day: "2026-11-10", clock: clock)) }
        let busy = [(try at("09:00"), try at("10:00")), (try at("10:20"), try at("12:00")), (try at("11:00"), try at("12:30"))]
        let gaps = CoordinationAnalysis.freeWindows(busy: busy, from: try at("09:00"), to: try at("14:00"), minimum: 1800)
        #expect(gaps.count == 1)
        let start = try at("12:30"), end = try at("14:00")
        #expect(gaps.first?.0 == start && gaps.first?.1 == end)
        let allDay = [(try at("08:00"), try at("15:00"))]
        let none = CoordinationAnalysis.freeWindows(busy: allDay, from: try at("09:00"), to: end, minimum: 60)
        #expect(none.isEmpty)
    }

    @Test("Nobody's plan: nothing together, no clashes, no crash")
    func empty() {
        let result = CoordinationAnalysis.build(plans: [], events: [], day: "2026-11-10")
        #expect(result.together.isEmpty && result.clashes.isEmpty)
    }

    @Test("Picks not in the agenda are ignored, not counted")
    func unknownPicks() {
        let result = CoordinationAnalysis.build(plans: [plan("a", ["events/nope"]), plan("b", ["events/nope"])],
                                                events: events, day: "2026-11-10")
        #expect(result.together.isEmpty)
        #expect(result.perPerson["a"] == 0)
    }

    @Test("The store keeps vault ids per person, never keys")
    @MainActor func linksStoreNoKeys() {
        let name = "coord-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let store = CoordinationStore(defaults: defaults)
        #expect(store.linkedVaults.isEmpty)
        store.unlink(person: "x")
        let saved = defaults.dictionary(forKey: CoordinationStore.linksKey) as? [String: String] ?? [:]
        #expect(saved.values.allSatisfy { !$0.contains("sgit_") })
        defaults.removePersistentDomain(forName: name)
    }
}
