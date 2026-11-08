import Foundation
import Testing
import PTCore
@testable import PTAgenda

@Suite("Now board")
struct NowBoardTests {
    private func event(_ slug: String, _ day: String, _ time: String, place: String) -> Event {
        Event(date: day, time: time, title: slug, place: place, kind: "talk", official: true,
              page: "events/\(slug)/index.html")
    }

    private func at(_ day: String, _ clock: String) -> Date { Lisbon.instant(day: day, clock: clock)! }

    private func pick(_ event: Event) -> SchedulePick {
        SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    private let opening = Event(date: "2026-11-10", time: "09:00-10:00", title: "opening", place: "Centre Stage",
                                kind: "talk", official: true, page: "events/opening/index.html")
    private let keynote = Event(date: "2026-11-10", time: "10:00-11:00", title: "keynote", place: "Centre Stage",
                                kind: "talk", official: true, page: "events/keynote/index.html")
    private let panel = Event(date: "2026-11-10", time: "10:30-11:15", title: "panel", place: "Stage B",
                              kind: "talk", official: true, page: "events/panel/index.html")
    private let lunch = Event(date: "2026-11-10", time: "12:00-12:30", title: "lunch", place: "Stage B",
                              kind: "talk", official: true, page: "events/lunch/index.html")
    private let late = Event(date: "2026-11-10", time: "18:00-19:00", title: "late", place: "Centre Stage",
                             kind: "talk", official: true, page: "events/late/index.html")
    private let dayTwo = Event(date: "2026-11-11", time: "09:00-10:00", title: "dayTwo", place: "Centre Stage",
                               kind: "talk", official: true, page: "events/dayTwo/index.html")

    private var agenda: [Event] { [opening, keynote, panel, lunch, late, dayTwo] }

    private func id(_ event: Event) -> String { ScheduleID.fromPage(event.page)! }

    @Test func theVenueNowAndNextAreWhatRunsAndWhatStartsSoon() {
        let board = NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-10", "10:35"))
        #expect(board.venueNow.map(\.title) == ["keynote", "panel"])      // by start
        #expect(board.venueNext.map(\.title) == ["lunch"])                // late is beyond three hours
        #expect(board.day == "2026-11-10")
        #expect(board.phase == .live)
        #expect(board.mineNow.isEmpty && board.mineNext.isEmpty && board.nextMine == nil)
    }

    @Test func myProgramIsMarkedAndSeparate() {
        let board = NowBoard.snapshot(agenda: agenda, picks: [pick(keynote), pick(late)], now: at("2026-11-10", "10:35"))
        #expect(board.mineNow.map(\.title) == ["keynote"])
        #expect(board.mineNext.map(\.title) == ["late"])
        #expect(board.nextMine?.title == "late")
        #expect(board.venueNow.first { $0.title == "keynote" }?.mine == true)
        #expect(board.venueNow.first { $0.title == "panel" }?.mine == false)
    }

    @Test func myNextLooksADayAhead() {
        let board = NowBoard.snapshot(agenda: agenda, picks: [pick(dayTwo)], now: at("2026-11-10", "19:30"))
        #expect(board.mineNext.map(\.title) == ["dayTwo"])
        #expect(board.nextMine?.minutesUntilStart(from: at("2026-11-10", "19:30")) == 13 * 60 + 30)
    }

    @Test func twoPicksThatOverlapAreAClash() throws {
        let board = NowBoard.snapshot(agenda: agenda, picks: [pick(keynote), pick(panel)], now: at("2026-11-10", "10:35"))
        let clash = try #require(board.clashes.first)
        #expect(board.clashes.count == 1)
        #expect(clash.first.title == "keynote" && clash.second.title == "panel")
        #expect(clash.minutes == 30 && !clash.travel)
    }

    @Test func picksThatAreOverDoNotClash() {
        let board = NowBoard.snapshot(agenda: agenda, picks: [pick(opening), pick(keynote), pick(panel)],
                                      now: at("2026-11-10", "11:30"))
        #expect(board.clashes.isEmpty)
    }

    @Test func stagesShowWhatIsOnAndWhatIsNextOnEach() throws {
        let board = NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-10", "10:35"))
        #expect(board.stages.map(\.place) == ["Centre Stage", "Stage B"])
        let stageB = try #require(board.stages.last)
        #expect(stageB.now?.title == "panel")
        #expect(stageB.next?.title == "lunch")
        #expect(board.stages.first?.now?.title == "keynote")
        #expect(board.stages.first?.next == nil)                          // late is beyond the horizon
    }

    @Test func thePhaseSaysWhereTheSummitIs() {
        #expect(NowBoard.snapshot(agenda: [], picks: [], now: at("2026-11-10", "10:00")).phase == .noAgenda)
        #expect(NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-10", "07:00")).phase
                == .before(at("2026-11-10", "09:00")))
        #expect(NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-10", "13:00")).phase == .live)   // late is still to come
        #expect(NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-10", "19:30")).phase
                == .between(at("2026-11-11", "09:00")))
        #expect(NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-11", "08:00")).phase == .live)    // the day's first is still to come
        #expect(NowBoard.snapshot(agenda: agenda, picks: [], now: at("2026-11-11", "10:30")).phase == .ended)
    }

    @Test func myProgramStillShowsWhenTheAgendaHasNotLoaded() {
        let board = NowBoard.snapshot(agenda: [], picks: [pick(keynote), pick(late)], now: at("2026-11-10", "10:35"))
        #expect(board.phase == .noAgenda)
        #expect(board.mineNow.map(\.title) == ["keynote"])
        #expect(board.mineNext.map(\.title) == ["late"])
        #expect(board.venueNow.isEmpty)
    }

    @Test func aSessionWithNoEndRunsThirtyMinutes() {
        let open = Event(date: "2026-11-10", time: "14:00", title: "open", place: "Stage B", kind: "talk",
                         official: true, page: "events/open/index.html")
        let during = NowBoard.snapshot(agenda: [open], picks: [], now: at("2026-11-10", "14:20"))
        #expect(during.venueNow.map(\.title) == ["open"])
        #expect(during.venueNow.first?.minutesLeft(at: at("2026-11-10", "14:20")) == 10)
        let after = NowBoard.snapshot(agenda: [open], picks: [], now: at("2026-11-10", "14:40"))
        #expect(after.venueNow.isEmpty)
    }

    @Test func theLimitCapsEachList() {
        let many = (0..<12).map { event("s\($0)", "2026-11-10", "11:\(String(format: "%02d", $0 * 4))-12:59", place: "Stage \($0)") }
        let board = NowBoard.snapshot(agenda: many, picks: [], now: at("2026-11-10", "10:00"), limit: 5)
        #expect(board.venueNext.count == 5)
        #expect(board.venueNext.map(\.title) == ["s0", "s1", "s2", "s3", "s4"])
    }

    @Test func entryHelpersNeverGoNegative() {
        let entry = NowBoard.Entry(id: "x", title: "x", place: "", start: at("2026-11-10", "10:00"),
                                   end: at("2026-11-10", "11:00"), mine: false, url: nil)
        #expect(entry.minutesUntilStart(from: at("2026-11-10", "10:30")) == 0)
        #expect(entry.minutesLeft(at: at("2026-11-10", "11:30")) == 0)
        #expect(entry.minutesUntilStart(from: at("2026-11-10", "09:15")) == 45)
        #expect(entry.isLive(at: at("2026-11-10", "10:00")) && !entry.isLive(at: at("2026-11-10", "11:00")))
    }
}
