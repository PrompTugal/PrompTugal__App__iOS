import Foundation
import Testing
@testable import PrompTugal

@Suite("Now and next snapshot")
struct NowNextTests {
    private func event(_ id: String, _ date: String, _ time: String) -> Event {
        Event(date: date, time: time, title: id, place: "Stage", kind: "talk", official: true,
              page: "events/\(id)/index.html")
    }

    private let now = Lisbon.instant(day: "2026-11-11", clock: "10:15")!

    @Test("Keeps running and upcoming sessions, drops ended ones, marks saved ones")
    func snapshot() {
        let agenda = [event("ended", "2026-11-11", "09:00-10:00"), event("running", "2026-11-11", "10:00-11:00"),
                      event("later", "2026-11-11", "12:00-12:30"), event("far", "2026-11-14", "12:00-12:30")]
        let snapshot = NowNextPublisher.makeSnapshot(agenda: agenda, saved: [agenda[2]], now: now)
        #expect(snapshot.items.map(\.id) == ["events/running/index.html", "events/later/index.html"])
        #expect(snapshot.items.map(\.mine) == [false, true])
        #expect(snapshot.now(at: now).map(\.title) == ["running"])
        #expect(snapshot.next(after: now).map(\.title) == ["later"])
    }

    @Test("Saved sessions beyond the horizon are kept")
    func savedBeyondHorizon() {
        let far = event("far", "2026-11-14", "12:00-12:30")
        let snapshot = NowNextPublisher.makeSnapshot(agenda: [far], saved: [far], now: now)
        #expect(snapshot.items.map(\.title) == ["far"])
    }

    @Test("Timeline change points are the starts and ends in range")
    func changes() {
        let agenda = [event("running", "2026-11-11", "10:00-11:00"), event("later", "2026-11-11", "12:00-12:30")]
        let snapshot = NowNextPublisher.makeSnapshot(agenda: agenda, saved: [], now: now)
        let changes = snapshot.changes(after: now, until: now.addingTimeInterval(3 * 3_600))
        #expect(changes.map { LisbonClock.time($0) }.count == 3)
        #expect(changes == changes.sorted())
    }

    @Test("Round-trips through JSON")
    func roundTrip() throws {
        let snapshot = NowNextPublisher.makeSnapshot(agenda: [event("later", "2026-11-11", "12:00-12:30")],
                                                     saved: [], now: now)
        let decoded = SharedContainer.decode(try SharedContainer.encode(snapshot))
        #expect(decoded == snapshot)
    }
}
