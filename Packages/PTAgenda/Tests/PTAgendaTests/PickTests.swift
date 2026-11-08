import Foundation
import Testing
import PTCore
@testable import PTAgenda

private func pickEvent(_ slug: String, _ time: String, day: String = "2026-11-10") -> Event {
    Event(date: day, time: time, title: slug, place: "Stage 1", kind: "talk", official: true,
          page: "events/\(slug)/index.html")
}

@MainActor private func pickStore() -> ScheduleStore {
    ScheduleStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("pick-\(UUID().uuidString)"))
}

private func asPick(_ event: Event) -> SchedulePick {
    SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
}

@Suite("Pick rules")
struct PickRulesTests {
    @Test func aSessionThatOverlapsAPickIsFlagged() {
        let picks = [asPick(pickEvent("a", "14:00-15:00"))]
        #expect(PickRules.overlapping(pickEvent("b", "14:30-15:30"), in: picks).map(\.title) == ["a"])
        #expect(PickRules.overlapping(pickEvent("c", "13:00-14:30"), in: picks).map(\.title) == ["a"])
        #expect(PickRules.overlapping(pickEvent("d", "14:10-14:20"), in: picks).map(\.title) == ["a"])
    }

    @Test func touchingIsNotOverlapping() {
        let picks = [asPick(pickEvent("a", "14:00-15:00"))]
        #expect(PickRules.overlapping(pickEvent("after", "15:00-16:00"), in: picks).isEmpty)
        #expect(PickRules.overlapping(pickEvent("before", "13:00-14:00"), in: picks).isEmpty)
    }

    @Test func anotherDayNeverOverlaps() {
        let picks = [asPick(pickEvent("a", "14:00-15:00"))]
        #expect(PickRules.overlapping(pickEvent("b", "14:00-15:00", day: "2026-11-11"), in: picks).isEmpty)
    }

    @Test func theEventItselfNeverCountsAndASessionWithNoEndLastsThirtyMinutes() {
        let a = pickEvent("a", "14:00-15:00")
        #expect(PickRules.overlapping(a, in: [asPick(a)]).isEmpty)
        let open = pickEvent("open", "14:00")                                  // no end: 14:00 to 14:30
        #expect(PickRules.overlapping(pickEvent("b", "14:20-14:40"), in: [asPick(open)]).map(\.title) == ["open"])
        #expect(PickRules.overlapping(pickEvent("c", "14:30-15:00"), in: [asPick(open)]).isEmpty)
    }

    @Test func overlappingPicksComeSortedByStart() {
        let picks = [asPick(pickEvent("late", "14:20-15:00")), asPick(pickEvent("early", "14:00-14:30"))]
        #expect(PickRules.overlapping(pickEvent("x", "14:10-14:40"), in: picks).map(\.title) == ["early", "late"])
    }

    @Test func theWhenLabelNamesTheDayAndTheTime() {
        let label = PickRules.whenLabel(pickEvent("a", "14:00-15:00"))
        #expect(!label.isEmpty)                                              // the format follows the person's locale
        #expect(PickRules.whenLabel(pickEvent("odd", "to be announced")) == "to be announced")
    }
}

@Suite("Pick feedback")
@MainActor
struct PickFeedbackTests {
    @Test func pickingASessionSaysSoAndIsInTheSchedule() throws {
        let schedule = pickStore()
        let feedback = PickFeedback()
        let a = pickEvent("a", "14:00-15:00")
        feedback.toggle(a, in: schedule)
        #expect(schedule.isPicked(a))
        let toast = try #require(feedback.toast)
        #expect(!toast.isClash)
        if case .added(let when) = toast.kind { #expect(!when.isEmpty) } else { Issue.record("expected an added toast") }
    }

    @Test func aPickThatOverlapsAnotherSaysWhichOne() throws {
        let schedule = pickStore()
        let feedback = PickFeedback()
        feedback.toggle(pickEvent("a", "14:00-15:00"), in: schedule)
        feedback.toggle(pickEvent("b", "14:30-15:30"), in: schedule)
        let toast = try #require(feedback.toast)
        #expect(toast.isClash)
        #expect(toast.kind == .clash(with: "a", pickID: "a"))
        #expect(schedule.picks.count == 2)                                   // still added: the person chooses later
    }

    @Test func tappingTheStarAgainRemovesTheSessionAndClearsTheToast() {
        let schedule = pickStore()
        let feedback = PickFeedback()
        let a = pickEvent("a", "14:00-15:00")
        feedback.toggle(a, in: schedule)
        feedback.toggle(a, in: schedule)
        #expect(!schedule.isPicked(a))
        #expect(feedback.toast == nil)
    }

    @Test func theToastGoesAwayByItself() async throws {
        let schedule = pickStore()
        let feedback = PickFeedback(visibleFor: .milliseconds(60))
        feedback.toggle(pickEvent("a", "14:00-15:00"), in: schedule)
        #expect(feedback.toast != nil)
        try await Task.sleep(for: .milliseconds(400))
        #expect(feedback.toast == nil)
    }

    @Test func dismissClearsTheToastAtOnce() {
        let schedule = pickStore()
        let feedback = PickFeedback()
        feedback.toggle(pickEvent("a", "14:00-15:00"), in: schedule)
        feedback.dismiss()
        #expect(feedback.toast == nil)
    }
}

@MainActor
private final class Published {
    var calls: [String] = []
    func record(_ agenda: [Event], _ saved: [Event]) { calls.append("\(agenda.count)/\(saved.count)") }
}

@Suite("Now and next republisher")
@MainActor
struct NowNextRepublisherTests {
    @Test func publishesWhenAnAgendaLoadsAndWhenThePicksChange() async throws {
        let schedule = pickStore()
        let published = Published()
        let republisher = NowNextRepublisher(schedule: schedule, publish: { agenda, saved in published.record(agenda, saved) })
        let a = pickEvent("a", "14:00-15:00")
        let b = pickEvent("b", "16:00-17:00")

        schedule.toggle(a)                                                   // no agenda yet: nothing to publish
        try await Task.sleep(for: .milliseconds(150))
        #expect(published.calls.isEmpty)

        republisher.agendaDidLoad([a, b])
        #expect(published.calls == ["2/1"])                                  // the agenda, with a as the saved session

        schedule.toggle(b)                                                   // a pick: the notification republishes
        try await Task.sleep(for: .milliseconds(150))
        #expect(published.calls == ["2/1", "2/2"])

        schedule.toggle(a)
        try await Task.sleep(for: .milliseconds(150))
        #expect(published.calls == ["2/1", "2/2", "2/1"])
    }
}

@Suite("Pick seed")
@MainActor
struct PickSeedTests {
    @Test func acceptsSlugsAndFullIdsAndDropsDuplicates() {
        let ids = PickSeed.ids(in: ["app", "-PTSeedPicks", "a, events/b/index.html,a,,bad/slug", "-other"])
        let expected: [String] = ["a", "b"]
        #expect(ids == expected)
        #expect(PickSeed.ids(in: ["app"]).isEmpty)
        #expect(PickSeed.ids(in: ["-PTSeedPicks"]).isEmpty)
    }

    @Test func seedsTheScheduleOnce() {
        let schedule = pickStore()
        schedule.seedPicks(["a", "b"])
        schedule.seedPicks(["a", "c"])
        #expect(schedule.picks.count == 3)
    }
}

@Suite("Agenda opening day")
struct AgendaOpeningDayTests {
    @Test func opensOnTodayDuringTheSummitElseAllDays() {
        #expect(AgendaView.initialDay(now: Lisbon.instant(day: "2026-11-11", clock: "08:00")!) == "2026-11-11")
        #expect(AgendaView.initialDay(now: Lisbon.instant(day: "2026-11-08", clock: "08:00")!) == "all")
        #expect(AgendaView.initialDay(now: Lisbon.instant(day: "2026-11-13", clock: "08:00")!) == "all")
    }
}

@Suite("Agenda clock", .serialized)
struct AgendaClockTests {
    @Test func overrideReplacesTheRealTimeUntilCleared() {
        let pretend = Lisbon.instant(day: "2026-11-10", clock: "14:05")!
        AgendaClock.override = pretend
        #expect(AgendaClock.now == pretend)
        AgendaClock.override = nil
        #expect(abs(AgendaClock.now.timeIntervalSinceNow) < 5)
    }
}
