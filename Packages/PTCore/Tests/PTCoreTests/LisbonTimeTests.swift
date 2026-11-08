import Foundation
import Testing
@testable import PTCore

@Suite("Lisbon time parsing")
struct LisbonTimeTests {
    private func utc(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)!
    }

    @Test("November is UTC+0 in Lisbon")
    func winterTime() {
        #expect(Lisbon.instant(day: "2026-11-10", clock: "09:30") == utc("2026-11-10T09:30:00Z"))
    }

    @Test("July is UTC+1 in Lisbon")
    func summerTime() {
        #expect(Lisbon.instant(day: "2026-07-01", clock: "12:00") == utc("2026-07-01T11:00:00Z"))
    }

    @Test("Bad input gives nil", arguments: [
        ("2026-11-10", "24:00"), ("2026-11-10", "09:60"), ("2026-11", "09:00"), ("", "09:00"), ("2026-11-10", "9")
    ])
    func rejectsBadInput(day: String, clock: String) {
        #expect(Lisbon.instant(day: day, clock: clock) == nil)
    }

    @Test("An event's start and end come from its time range")
    func eventRange() throws {
        let event = Event(date: "2026-11-11", time: "14:00-14:45", title: "Talk", place: "Centre Stage",
                          kind: "talk", official: true, page: "events/talk/index.html")
        #expect(event.start == utc("2026-11-11T14:00:00Z"))
        #expect(event.end == utc("2026-11-11T14:45:00Z"))
    }

    @Test("A range past midnight ends the next day")
    func pastMidnight() {
        let event = Event(date: "2026-11-11", time: "23:00-01:00", title: "Night Summit", place: "Lisbon",
                          kind: "party", official: false, page: "events/night/index.html")
        #expect(event.end == utc("2026-11-12T01:00:00Z"))
    }

    @Test("Detail URL is the event's JSON")
    func detailURL() {
        let event = Event(date: "2026-11-11", time: "10:00", title: "x", place: "y", kind: "talk", official: true,
                          page: "events/opening-night/index.html")
        #expect(event.detailURL?.absoluteString == "https://promptugal.news/api/v1/events/opening-night.json")
        #expect(event.end == nil)
    }
}

@Suite("Lisbon day (shared helper, Q8)")
struct LisbonDayHelperTests {
    @Test("Late evening UTC in summer is already the next Lisbon day")
    func summerMidnight() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-07-01T23:30:00Z"))
        #expect(Lisbon.day(date) == "2026-07-02")
    }

    @Test("In winter Lisbon is on UTC")
    func winter() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-11-09T23:30:00Z"))
        #expect(Lisbon.day(date) == "2026-11-09")
    }
}
