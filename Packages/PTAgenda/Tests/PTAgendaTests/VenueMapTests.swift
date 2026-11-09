import Foundation
import Testing
import PTCore
@testable import PTAgenda

@Suite("Venue map")
struct VenueMapTests {
    private func map() throws -> VenueMap { try #require(VenueMap.shared) }

    @Test func theBuiltInMapHasTheNineAreasAndItsCredit() throws {
        let map = try map()
        let labels: [String] = map.areas.map(\.label)
        #expect(labels.contains("MEO Arena") && labels.contains("FIL") && labels.contains("Pavilion 3"))
        #expect(map.areas.count == 9 && map.frame.width == 1000)
        #expect(VenueMap.attribution == "© OpenStreetMap contributors")
        for area in map.areas { #expect(!SVGPathData.commands(area.d).isEmpty, "\(area.label) has an outline") }
    }

    @Test func eventsLandOnTheAreaTheyAreIn() throws {
        let map = try map()
        #expect(map.area(forPlace: "Pavilion 2")?.label == "Pavilion 2")
        #expect(map.area(forPlace: "Pavilhão de Portugal")?.label == "Pavilhão de Portugal")
        #expect(map.area(forPlace: "Centre Stage")?.label == "MEO Arena")
        #expect(map.area(forPlace: "Stage 4")?.label == "FIL")                       // a summit room, hall not stated
        #expect(map.area(forPlace: "Masterclass 1", where: "Masterclass 1 (Masterclasses), MEO Arena and FIL")?.label == "MEO Arena")
        #expect(map.area(forPlace: "Stage 9", where: "Stage 9, FIL and MEO Arena")?.label == "FIL")
        #expect(map.area(forPlace: "Humberto Delgado Airport, Terminal 1") == nil)
        #expect(map.area(forPlace: "Hotel bar, Baixa") == nil)
        #expect(map.area(forPlace: "") == nil)
    }

    @Test func aShortNameIsMatchedAsAWholeWord() {
        #expect(VenueMap.firstWordMatch(of: "fil", in: "stage 4, fil") == 9)
        #expect(VenueMap.firstWordMatch(of: "fil", in: "a film set") == nil)
        #expect(VenueMap.firstWordMatch(of: "pavilion 1", in: "pavilion 10") == nil)
    }

    @Test func theSvgPathsParse() {
        let commands = SVGPathData.commands("M598 64.1L785.4 79.3L760.6 452.9Z")
        #expect(commands.count == 4)
        #expect(commands.first == .move(CGPoint(x: 598, y: 64.1)))
        #expect(commands.last == .close)
        #expect(SVGPathData.commands("M10-5L-3.5 4")[0] == .move(CGPoint(x: 10, y: -5)))
        #expect(SVGPathData.commands("M10-5L-3.5 4")[1] == .line(CGPoint(x: -3.5, y: 4)))
        #expect(SVGPathData.commands("").isEmpty)
    }

    @Test func pinsWalksAndPicksThatAreNotOnTheMap() throws {
        func pick(_ slug: String, _ time: String, place: String) -> SchedulePick {
            let event = Event(date: "2026-11-10", time: time, title: slug, place: place, kind: "talk", official: false,
                              page: "events/\(slug)/index.html")
            return SchedulePick(id: ScheduleID.fromPage(event.page)!, at: .distantPast, event: event)
        }
        let picks = [pick("keynote", "10:00-10:30", place: "Centre Stage"), pick("next", "10:35-11:00", place: "Pavilion 3"),
                     pick("dinner", "20:00-21:00", place: "Hotel bar, Baixa")]
        let now = Lisbon.instant(day: "2026-11-10", clock: "10:27")!
        let model = VenueMapModel(map: try map(), picks: picks, now: now)
        let pinLabels: [String] = model.pins.map(\.label)
        let expectedLabels: [String] = ["Pavilion 3", "MEO Arena"]          // in the map's own order
        #expect(pinLabels == expectedLabels)
        #expect(model.pins.allSatisfy(\.isActive))                          // the current session and the next one
        let unplaced: [String] = model.unplaced.map(\.title)
        #expect(unplaced == ["dinner"])
        #expect(model.walks.count == 1 && model.walks[0].minutes == 5 && model.walks[0].toTitle == "next")
    }
}
