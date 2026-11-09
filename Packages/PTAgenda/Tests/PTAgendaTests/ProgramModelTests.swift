import Foundation
import Testing
import PTCore
@testable import PTAgenda

@Suite("Program model")
struct ProgramModelTests {
    private func pick(_ slug: String, _ time: String, day: String = "2026-11-10", place: String = "Stage 1",
                      kind: String = "talk", title: String? = nil) -> SchedulePick {
        let event = Event(date: day, time: time, title: title ?? slug, place: place, kind: kind, official: false,
                          page: "events/\(slug)/index.html")
        return SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    private func shape(_ model: ProgramModel) -> [String] {
        model.rows.map { row in
            switch row {
            case .session(let entry): return "session:" + entry.title
            case .presence(let entry): return "presence:" + entry.title
            case .clash(let group): return "clash:" + group.entries.map(\.title).joined(separator: "+")
            case .free(let start, let end): return "free:\(Int(end.timeIntervalSince(start) / 60))"
            }
        }
    }

    @Test func clashesAndFreeTimeComeInTimeOrder() {
        let picks = [pick("e", "14:00-15:00"), pick("d", "13:15-14:00"), pick("c", "12:15-13:00"),
                     pick("b", "10:30-11:30"), pick("a", "10:00-11:00")]
        let rows: [String] = shape(ProgramModel(picks: picks, day: "2026-11-10"))
        // a and b overlap; 45 minutes free; c; a 15-minute gap is not shown; d touches e
        #expect(rows == ["clash:a+b", "free:45", "session:c", "session:d", "session:e"])
    }

    @Test func clashGroupKnowsTheOthers() throws {
        let model = ProgramModel(picks: [pick("a", "10:00-11:00"), pick("b", "10:30-11:30")], day: "2026-11-10")
        guard case .clash(let group) = try #require(model.rows.first) else { Issue.record("expected a clash"); return }
        #expect(group.others(than: "a") == ["b"])
    }

    @Test func daysCoverTheSummitAndCountPicks() {
        let model = ProgramModel(picks: [pick("a", "10:00-11:00"), pick("b", "12:00-13:00"),
                                         pick("c", "09:00-10:00", day: "2026-11-11")], day: "2026-11-10")
        let counts: [Int] = model.days.map(\.count)
        let ids: [String] = model.days.map(\.id)
        #expect(ids == ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12"])
        #expect(counts == [0, 2, 1, 0])
        #expect(model.pickCount == 3 && !model.isEmpty)
        #expect(model.dayEntries.count == 2)
    }

    @Test func noPicksIsEmpty() {
        let model = ProgramModel(picks: [], day: "2026-11-10")
        #expect(model.isEmpty && model.rows.isEmpty)
    }

    @Test func theDefaultDayIsTodayDuringTheSummitElseTheFirstPickDay() {
        let picks = [pick("a", "09:00-10:00", day: "2026-11-11")]
        #expect(ProgramModel.defaultDay(picks: picks, now: Lisbon.instant(day: "2026-11-12", clock: "09:00")!) == "2026-11-12")
        #expect(ProgramModel.defaultDay(picks: picks, now: Lisbon.instant(day: "2026-11-08", clock: "09:00")!) == "2026-11-11")
        #expect(ProgramModel.defaultDay(picks: [], now: Lisbon.instant(day: "2026-11-08", clock: "09:00")!) == "2026-11-10")
    }
}

@Suite("Program day chips")
struct ProgramDayChipTests {
    @Test func chipsAreShortInEveryLanguage() {
        for id in ["en_US", "pt_BR", "pt_PT"] {
            let label = ProgramModel.shortLabel("2026-11-10", locale: Locale(identifier: id))
            #expect(label.contains("10"))
            #expect(label.count <= 9)              // weekday abbreviation and the day number, never "Nov 10, 2026"
            #expect(!label.contains("2026"))
        }
        #expect(ProgramModel.shortLabel("not a day") == "not a day")
    }
}

@Suite("Busy, free and clashes you can see")
struct BusyFreeClashTests {
    private func pick(_ slug: String, _ time: String, place: String = "Stage 1", kind: String = "talk",
                      title: String? = nil) -> SchedulePick {
        let event = Event(date: "2026-11-10", time: time, title: title ?? slug, place: place, kind: kind, official: false,
                          page: "events/\(slug)/index.html")
        return SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    private func at(_ clock: String) -> Date { Lisbon.instant(day: "2026-11-10", clock: clock)! }

    private func shape(_ model: ProgramModel) -> [String] {
        model.rows.map { row in
            switch row {
            case .session(let entry): return "session:" + entry.title
            case .presence(let entry): return "presence:" + entry.title
            case .clash(let group): return "clash:" + group.entries.map(\.title).joined(separator: "+")
            case .free(let start, let end): return "free:\(Int(end.timeIntervalSince(start) / 60))"
            }
        }
    }

    @Test func aFreePresenceEventNeverClashesWithATalk() {
        let picks = [pick("reg", "07:30-18:00", kind: "registration", title: "Registration"), pick("talk", "10:00-11:00")]
        let model = ProgramModel(picks: picks, day: "2026-11-10")
        let rows: [String] = shape(model)
        #expect(rows == ["presence:Registration", "session:talk"])
        #expect(model.clashes.isEmpty)
    }

    @Test func theShowOpeningEveningIsFreeByTitleAndByLength() {
        let evening = pick("show", "18:00-20:00", kind: "talk", title: "Start of the show")
        let long = pick("expo", "09:00-13:00", kind: "talk")
        let panel = pick("panel", "18:30-19:15")
        let model = ProgramModel(picks: [evening, long, panel], day: "2026-11-10")
        #expect(model.showsAs["show"] == .free && model.showsAs["expo"] == .free && model.showsAs["panel"] == .busy)
        #expect(model.clashes.isEmpty)
    }

    @Test func thePersonsToggleWinsThenTheFeedThenTheRule() {
        let picks = [pick("a", "10:00-11:00"), pick("b", "10:30-11:30")]
        #expect(ProgramModel(picks: picks, day: "2026-11-10").clashes.count == 1)
        let feedFree = ProgramModel(picks: picks, day: "2026-11-10", feed: { $0 == "b" ? .free : nil })
        #expect(feedFree.clashes.isEmpty)
        let toggledBusy = ProgramModel(picks: picks, day: "2026-11-10", toggled: ["b": .busy],
                                       feed: { $0 == "b" ? .free : nil })
        #expect(toggledBusy.clashes.count == 1)                              // the toggle beats the feed
        let toggledFree = ProgramModel(picks: picks, day: "2026-11-10", toggled: ["a": .free])
        let rows: [String] = shape(toggledFree)
        #expect(rows == ["presence:a", "session:b"] && toggledFree.clashes.isEmpty)
    }

    @Test func aClashNamesTheOverlapOnBothSessions() throws {
        let model = ProgramModel(picks: [pick("a", "10:00-11:00"), pick("b", "10:30-11:30")], day: "2026-11-10")
        let pair = try #require(model.clashes.first)
        #expect(pair.first.id == "a" && pair.second.id == "b")
        #expect(pair.overlapStart == at("10:30") && pair.overlapEnd == at("11:00"))
        guard case .clash(let group) = try #require(model.rows.first) else { Issue.record("expected a clash"); return }
        #expect(group.pairs(with: "a").count == 1 && group.pairs(with: "b").count == 1)
        #expect(group.needsChoice && model.unresolvedClashes.count == 1)
    }

    @Test func splittingMyTimeKeepsTheOverlapButResolvesIt() throws {
        let picks = [pick("a", "10:00-11:00", place: "Stage 1"), pick("b", "10:30-11:30", place: "Stage 2")]
        let key = ProgramModel.splitKey("b", "a")
        #expect(key == "a|b")
        let model = ProgramModel(picks: picks, day: "2026-11-10", splits: [key])
        let pair = try #require(model.clashes.first)
        #expect(pair.isSplit && model.unresolvedClashes.isEmpty)
        guard case .clash(let group) = try #require(model.rows.first) else { Issue.record("expected a clash"); return }
        #expect(!group.needsChoice)
        #expect(pair.walkMinutes == 5)                                       // two stages in the venue
        #expect(pair.leaveAt == at("10:25"))                                 // leave A at 10:25 to be at B for 10:30
    }

    @Test func theLeaveTimeStaysInsideTheFirstSession() throws {
        // far apart: a 25 minute trip, but the second starts only 10 minutes into the first
        let picks = [pick("a", "10:00-11:00", place: "Stage 1"), pick("b", "10:10-11:30", place: "Café across town")]
        let pair = try #require(ProgramModel(picks: picks, day: "2026-11-10", splits: [ProgramModel.splitKey("a", "b")]).clashes.first)
        #expect(pair.walkMinutes == 25)
        #expect(pair.leaveAt == at("09:45"))                                 // the shared rule: second start minus the walk
        #expect(pair.leaveAtForDisplay == at("10:00"))                       // shown: never before the first one starts
    }

    @Test func theFallbackRule() {
        func entry(_ title: String, minutes: Int = 45) -> NowModel.Entry {
            NowModel.Entry(id: "x", title: title, place: "Stage 1", start: at("10:00"),
                           end: at("10:00").addingTimeInterval(TimeInterval(minutes * 60)), mine: true, official: false, url: nil)
        }
        for title in ["Registration", "Opening Night", "Start-of-the-show", "Venue hours", "ALL DAY lounge"] {
            #expect(BusyRule.fallback(entry(title)) == .free)
        }
        #expect(BusyRule.fallback(entry("Big expo", minutes: 180)) == .free)
        #expect(BusyRule.fallback(entry("Big expo", minutes: 179)) == .busy)
        for title in ["Panel: agents at work", "Workshop", "Meeting with the team", "Masterclass"] {
            #expect(BusyRule.fallback(entry(title)) == .busy)
        }
        #expect(BusyRule.resolve(entry("Workshop"), toggled: .free, feed: .busy) == .free)
        #expect(BusyRule.resolve(entry("Workshop"), toggled: nil, feed: .free) == .free)
        #expect(BusyRule.resolve(entry("Registration"), toggled: nil, feed: .busy) == .busy)
    }
}

@Suite("Plan choices")
@MainActor
struct PlanChoicesTests {
    @Test func choicesAreKeptOnTheDeviceAndCanBeCleared() throws {
        let name = "plan-choices-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = PlanChoices(defaults: defaults)
        first.set(.free, for: "a")
        first.toggleSplit("a|b")
        let again = PlanChoices(defaults: defaults)
        #expect(again.toggled["a"] == .free && again.splits.contains("a|b"))
        again.set(nil, for: "a")
        again.toggleSplit("a|b")
        let last = PlanChoices(defaults: defaults)
        #expect(last.toggled.isEmpty && last.splits.isEmpty)
    }
}

@Suite("Day planner and free picks")
struct DayPlannerFreeTests {
    private func event(_ slug: String, _ time: String, kind: String = "talk", place: String = "Stage 1") -> Event {
        Event(date: "2026-11-10", time: time, title: slug, place: place, kind: kind, official: false,
              page: "events/\(slug)/index.html")
    }

    private func pick(_ event: Event) -> SchedulePick {
        SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    @Test func aFreePickMakesNoClashAndLeavesTheGapsOpen() {
        let reg = event("registration", "07:30-18:00", kind: "registration", place: "Terminal 1")
        let talk = event("talk", "10:00-11:00")
        let plan = DayPlanner.plan(day: "2026-11-10", agenda: [], picks: [pick(reg), pick(talk)], standups: [])
        #expect(plan.clashes.isEmpty)
        #expect(plan.fixed.count == 2)
        #expect(plan.gaps.count == 2)                                        // 09:00-10:00 and 11:00-19:00, around the talk
    }

    @Test func thePersonCanMarkATalkFreeOrBusy() {
        let a = event("a", "10:00-11:00"), b = event("b", "10:30-11:30")
        let clash = DayPlanner.plan(day: "2026-11-10", agenda: [], picks: [pick(a), pick(b)], standups: [])
        #expect(clash.clashes.count == 1)
        var prefs = DayPlanner.Preferences()
        prefs.toggled = ["b": .free]
        let free = DayPlanner.plan(day: "2026-11-10", agenda: [], picks: [pick(a), pick(b)], standups: [], preferences: prefs)
        #expect(free.clashes.isEmpty)
    }
}

@Suite("shows_as from the feed")
struct FeedShowsAsTests {
    private func pick(_ slug: String, _ time: String, showsAs: String?) -> SchedulePick {
        let event = Event(date: "2026-11-10", time: time, title: slug, place: "Stage 1", kind: "talk", official: false,
                          page: "events/\(slug)/index.html", showsAs: showsAs)
        return SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    @Test func theEventsOwnShowsAsDecidesBeforeTheRule() {
        let picks = [pick("a", "10:00-11:00", showsAs: nil), pick("b", "10:30-11:30", showsAs: "free")]
        let model = ProgramModel(picks: picks, day: "2026-11-10")
        #expect(model.showsAs["b"] == .free && model.clashes.isEmpty)
        let busyOnRegistration = ProgramModel(picks: [pick("registration", "09:00-18:00", showsAs: "busy")], day: "2026-11-10")
        #expect(busyOnRegistration.showsAs["registration"] == .busy)
    }
}
