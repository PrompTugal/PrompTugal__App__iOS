import Foundation
import Testing
import PTCore
@testable import PTAgenda

@Suite("Program model")
struct ProgramModelTests {
    private func pick(_ slug: String, _ time: String, day: String = "2026-11-10") -> SchedulePick {
        let event = Event(date: day, time: time, title: slug, place: "Stage 1", kind: "talk", official: false,
                          page: "events/\(slug)/index.html")
        return SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    private func shape(_ model: ProgramModel) -> [String] {
        model.rows.map { row in
            switch row {
            case .session(let entry): return "session:" + entry.title
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
