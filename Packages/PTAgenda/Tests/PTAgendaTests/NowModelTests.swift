import Foundation
import Testing
import PTCore
@testable import PTAgenda

@Suite("Now model")
struct NowModelTests {
    private func event(_ slug: String, _ day: String, _ time: String, place: String = "Stage 1",
                       official: Bool = false, kind: String = "talk") -> Event {
        Event(date: day, time: time, title: slug, place: place, kind: kind, official: official,
              page: "events/\(slug)/index.html")
    }

    private func at(_ day: String, _ clock: String) -> Date { Lisbon.instant(day: day, clock: clock)! }

    private func pick(_ event: Event) -> SchedulePick {
        SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    // Monday 9 to Thursday 12 November: registration and opening night, a busy Tuesday afternoon, then three more days.
    private var registration: Event { event("registration", "2026-11-09", "07:30-18:00", place: "Humberto Delgado Airport, Terminal 1", official: true, kind: "registration") }
    private var registration10: Event { event("registration10", "2026-11-10", "07:30-17:00", place: "Humberto Delgado Airport, Terminal 1", official: true, kind: "registration") }
    private var openingNight: Event { event("openingNight", "2026-11-09", "18:00-21:00", place: "Centre Stage", official: true, kind: "summit") }
    private var keynote: Event { event("keynote", "2026-11-10", "14:00-14:40", place: "Centre Stage", official: true) }
    private var s4a: Event { event("s4a", "2026-11-10", "13:30-14:20", place: "Stage 4") }
    private var s6: Event { event("s6", "2026-11-10", "14:00-15:00", place: "Stage 6") }
    private var s7: Event { event("s7", "2026-11-10", "14:00-14:30", place: "Stage 7") }
    private var s8: Event { event("s8", "2026-11-10", "13:45-14:50", place: "Stage 8") }
    private var s9: Event { event("s9", "2026-11-10", "14:05-14:50", place: "Stage 9") }
    private var s11: Event { event("s11", "2026-11-10", "14:00-15:30", place: "Stage 11") }
    private var stage12: Event { event("stage12", "2026-11-10", "14:30-15:00", place: "Stage 12") }
    private var stage2: Event { event("stage2", "2026-11-10", "15:00-15:30", place: "Stage 2") }
    private var later: Event { event("later", "2026-11-10", "16:00-16:30", place: "Stage 3") }
    private var closing10: Event { event("closing10", "2026-11-10", "18:00-19:00", place: "Centre Stage") }
    private var d11a: Event { event("d11a", "2026-11-11", "09:00-10:00") }
    private var d11b: Event { event("d11b", "2026-11-11", "09:30-10:30") }
    private var d11c: Event { event("d11c", "2026-11-11", "10:00-11:00") }
    private var d11d: Event { event("d11d", "2026-11-11", "10:30-11:30") }
    private var d12: Event { event("d12", "2026-11-12", "17:00-18:00") }

    private var agenda: [Event] {
        [registration, openingNight, registration10, keynote, s4a, s6, s7, s8, s9, s11, stage12, stage2, later, closing10,
         d11a, d11b, d11c, d11d, d12]
    }

    // MARK: Before the summit (8 Nov, 12:00)

    @Test func beforeTheSummitThereIsACountdownAndTheFirstTwoOfficialItems() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-08", "12:00"))
        #expect(model.phase == .before)
        #expect(model.countdown?.largest.unit == .hours)
        #expect(model.countdown?.largest.value == 19)                      // 19 h 30 min to 9 Nov 07:30
        let first: [String] = model.firstItems.map(\.title)
        #expect(first == ["registration", "openingNight"])                 // one registration, then the opening night
        #expect(model.forYou == nil && model.onNow.isEmpty && model.onNowCount == 0 && model.tomorrow.isEmpty)
    }

    @Test func theCountdownUsesTheLargestWholeUnit() {
        let opens = NowModel.Summit.lisbon2026.opens
        #expect(NowModel.Countdown(opens: opens, now: at("2026-11-08", "06:00")).largest.unit == .days)    // 25 h 30 min
        #expect(NowModel.Countdown(opens: opens, now: at("2026-11-08", "06:00")).largest.value == 1)
        #expect(NowModel.Countdown(opens: opens, now: at("2026-11-09", "07:10")).largest.unit == .minutes)
        #expect(NowModel.Countdown(opens: opens, now: at("2026-11-09", "07:10")).largest.value == 20)
        #expect(NowModel.Countdown(opens: opens, now: opens.addingTimeInterval(-30)).largest.value == 1)   // never "0 minutes"
    }

    @Test func theCountdownEndsWhenTheSummitOpens() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-09", "07:30"))
        #expect(model.phase == .during)                                    // registration is running
        #expect(model.countdown == nil && model.firstItems.isEmpty)
        #expect(model.onNow.isEmpty)                                       // registration is not a session
    }

    @Test func registrationNeverTakesASlotOnNowUpNextOrTomorrow() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-10", "11:00"))
        let titles: [String] = model.onNow.map(\.title)
        #expect(!titles.contains("registration10") && !titles.contains("registration"))
        #expect(model.onNowCount == 0 && model.firstItems.isEmpty)
        let evening = NowModel(events: agenda, picks: [], now: at("2026-11-09", "17:30"))
        let upNext: [String] = evening.upNext.map(\.title)
        #expect(upNext == ["openingNight"])                                // registration is live but is not listed
    }

    // MARK: During the summit (10 Nov, 14:05)

    @Test func onNowIsCentreStageFirstThenByStartAndCappedAtFive() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-10", "14:05"))
        #expect(model.phase == .during)
        #expect(model.onNowCount == 7)                                     // keynote, s4a, s8, s11, s6, s7, s9
        #expect(model.onNow.map(\.title) == ["keynote", "s4a", "s8", "s11", "s6"])
    }

    @Test func upNextIsTheNextHourByStart() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-10", "14:05"))
        #expect(model.upNext.map(\.title) == ["stage12", "stage2"])        // later (16:00) is more than an hour away
        #expect(model.upNext.first?.minutesUntilStart(from: model.now) == 25)
    }

    @Test func forYouIsTheCurrentPickWithItsClashFlag() throws {
        let model = NowModel(events: agenda, picks: [pick(keynote), pick(s6)], now: at("2026-11-10", "14:05"))
        let forYou = try #require(model.forYou)
        #expect(forYou.isNow)
        #expect(forYou.entry.title == "keynote")                           // both started at 14:00: the title decides
        #expect(forYou.clashes)
        #expect(forYou.clashesWith.map(\.title) == ["s6"])
        #expect(model.pickCount == 2)
    }

    @Test func forYouWithoutAClashHasNoFlag() throws {
        let model = NowModel(events: agenda, picks: [pick(keynote), pick(stage2)], now: at("2026-11-10", "14:05"))
        let forYou = try #require(model.forYou)
        #expect(forYou.entry.title == "keynote" && forYou.isNow && !forYou.clashes)
    }

    @Test func forYouIsTheNextPickWhenNothingIsRunning() throws {
        let model = NowModel(events: agenda, picks: [pick(closing10), pick(keynote)], now: at("2026-11-10", "16:10"))
        let forYou = try #require(model.forYou)
        #expect(forYou.entry.title == "closing10" && !forYou.isNow)
        #expect(forYou.entry.minutesUntilStart(from: model.now) == 110)
    }

    @Test func aPickThatIsOverDoesNotCountAsAClash() throws {
        // s4a ended at 14:20; the person is now in the keynote only
        let model = NowModel(events: agenda, picks: [pick(s4a), pick(keynote)], now: at("2026-11-10", "14:25"))
        let forYou = try #require(model.forYou)
        #expect(forYou.entry.title == "keynote" && !forYou.clashes)
    }

    @Test func venueEntriesKnowWhichOnesArePicked() {
        let model = NowModel(events: agenda, picks: [pick(keynote)], now: at("2026-11-10", "14:05"))
        #expect(model.onNow.first { $0.title == "keynote" }?.mine == true)
        #expect(model.onNow.first { $0.title == "s4a" }?.mine == false)
    }

    @Test func aSessionWithNoEndLastsThirtyMinutes() {
        let open = event("open", "2026-11-10", "14:00")
        #expect(NowModel(events: [open], picks: [], now: at("2026-11-10", "14:20")).onNow.map(\.title) == ["open"])
        #expect(NowModel(events: [open], picks: [], now: at("2026-11-10", "14:30")).onNow.isEmpty)
    }

    // MARK: Between days, and after

    @Test func betweenDaysTomorrowShowsTheFirstThreeSessionsOfTheNextDay() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-10", "20:00"))
        #expect(model.phase == .between)
        #expect(model.tomorrow.map(\.title) == ["d11a", "d11b", "d11c"])
        #expect(model.onNow.isEmpty && model.upNext.isEmpty)
    }

    @Test func theMorningOfASummitDayIsStillDuring() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-10", "07:00"))
        #expect(model.phase == .during)                                    // more sessions start today
        #expect(model.tomorrow.isEmpty)
    }

    @Test func afterTheLastSessionOfTheSummitButBeforeItClosesIsBetweenWithNoTomorrow() {
        let model = NowModel(events: agenda, picks: [], now: at("2026-11-12", "23:00"))
        #expect(model.phase == .between)
        #expect(model.tomorrow.isEmpty)
    }

    @Test func afterTheSummitThePhaseIsAfterAndThePicksAreCounted() {
        let model = NowModel(events: agenda, picks: [pick(keynote), pick(d11a)], now: at("2026-11-13", "00:30"))
        #expect(model.phase == .after)
        #expect(model.pickCount == 2)
        #expect(model.forYou == nil && model.onNow.isEmpty && model.upNext.isEmpty && model.tomorrow.isEmpty)
        #expect(model.countdown == nil)
    }

    // MARK: Offline

    @Test func withNoAgendaDuringTheSummitMyProgramStillShows() throws {
        let model = NowModel(events: [], picks: [pick(keynote)], now: at("2026-11-10", "13:00"))
        #expect(model.phase == .during)
        #expect(model.onNow.isEmpty && model.upNext.isEmpty)
        let forYou = try #require(model.forYou)
        #expect(forYou.entry.title == "keynote" && !forYou.isNow)
    }

    @Test func entryHelpersNeverGoNegative() {
        let entry = NowModel.Entry(id: "x", title: "x", place: "", start: at("2026-11-10", "10:00"),
                                   end: at("2026-11-10", "11:00"), mine: false, official: false, url: nil)
        #expect(entry.minutesUntilStart(from: at("2026-11-10", "10:30")) == 0)
        #expect(entry.minutesLeft(at: at("2026-11-10", "11:30")) == 0)
        #expect(entry.minutesUntilStart(from: at("2026-11-10", "09:15")) == 45)
        #expect(entry.minutesLeft(at: at("2026-11-10", "10:20")) == 40)
        #expect(entry.isLive(at: at("2026-11-10", "10:00")) && !entry.isLive(at: at("2026-11-10", "11:00")))
    }
}
