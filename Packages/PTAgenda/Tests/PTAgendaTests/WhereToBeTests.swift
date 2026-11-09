import Foundation
import Testing
import PTCore
@testable import PTAgenda

@Suite("Where I need to be")
struct WhereToBeTests {
    private func pick(_ slug: String, _ time: String, place: String = "Stage 1", title: String? = nil) -> SchedulePick {
        let event = Event(date: "2026-11-10", time: time, title: title ?? slug, place: place, kind: "talk", official: false,
                          page: "events/\(slug)/index.html")
        return SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
    }

    private func at(_ clock: String) -> Date { Lisbon.instant(day: "2026-11-10", clock: clock)! }

    @Test func nextTenAndNextTwentyMinutesWithTheWalk() {
        let picks = [pick("now", "10:00-10:30", place: "Centre Stage"), pick("soon", "10:35-11:00", place: "Masterclass 1"),
                     pick("later", "10:45-11:30", place: "Hotel bar, Baixa"), pick("far", "11:30-12:00")]
        let model = WhereToBe(picks: picks, now: at("10:27"))
        #expect(model.current?.id == "now")
        let ten: [String] = model.next10.map(\.id)
        let twenty: [String] = model.next20.map(\.id)
        #expect(ten == ["soon"] && twenty == ["later"])                      // "far" is beyond 20 minutes
        let soon = model.next10[0]
        #expect(soon.walkMinutes == 5 && soon.leaveBy == at("10:30"))        // two venue rooms: 5 minutes
        #expect(soon.minutesToLeave == 3 && !soon.isLate)
        let later = model.next20[0]
        #expect(later.from?.id == "soon" && later.walkMinutes == 25)         // from the room before, to town
        #expect(later.leaveBy == at("10:20") && later.isLate)                // cannot make it from the previous leg
    }

    @Test func aFreePickIsNotAPlaceToBeOnTime() {
        let picks = [pick("registration", "09:00-18:00", place: "Terminal 1", title: "Registration"), pick("talk", "10:05-10:30")]
        let model = WhereToBe(picks: picks, now: at("10:00"))
        #expect(model.current == nil)
        let ids: [String] = model.legs.map(\.id)
        #expect(ids == ["talk"])
        #expect(model.legs[0].from == nil && model.legs[0].walkMinutes == 0 && model.legs[0].minutesToLeave == 5)
    }

    @Test func quietWhenNothingIsComingUp() {
        #expect(WhereToBe(picks: [], now: at("10:00")).isQuiet)
        #expect(WhereToBe(picks: [pick("later", "11:00-12:00")], now: at("10:00")).isQuiet)
        #expect(!WhereToBe(picks: [pick("now", "09:30-10:30")], now: at("10:00")).isQuiet)
    }

    @Test func thePersonsToggleCanTakeAPickOutOfThePlaces() {
        let picks = [pick("soon", "10:05-10:30")]
        #expect(WhereToBe(picks: picks, now: at("10:00")).legs.count == 1)
        #expect(WhereToBe(picks: picks, now: at("10:00"), toggled: ["soon": .free]).legs.isEmpty)
    }
}
