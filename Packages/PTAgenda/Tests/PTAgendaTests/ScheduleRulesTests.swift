import Foundation
import Testing
import PTCore
@testable import PTAgenda

// The shared schedule rules (PrompTugal__App__Mobile formats/schedule-rules, vendored in Fixtures/schedule-rules with
// its source sha in SOURCE): iOS, Android and the web must give the same answers for rules.json and cases.json.

private struct Rules: Decodable {
    struct Travel: Decodable {
        let sameplaceMinutes: Int, withinSummitMinutes: Int, elsewhereMinutes: Int, summitPlaceKeywords: [String]
        enum CodingKeys: String, CodingKey {
            case sameplaceMinutes = "same_place_minutes", withinSummitMinutes = "within_summit_minutes"
            case elsewhereMinutes = "elsewhere_minutes", summitPlaceKeywords = "summit_place_keywords"
        }
    }
    struct ShowsAsRules: Decodable {
        let freeTitlePatterns: [String], freeMinMinutes: Int
        enum CodingKeys: String, CodingKey {
            case freeTitlePatterns = "fallback_free_title_patterns", freeMinMinutes = "fallback_free_min_minutes"
        }
    }
    let travel: Travel
    let defaultDurationMinutes: Int
    let showsAs: ShowsAsRules
    enum CodingKeys: String, CodingKey {
        case travel, defaultDurationMinutes = "default_duration_minutes", showsAs = "shows_as"
    }
}

private struct Item: Decodable {
    let id: String
    let title: String
    let start: String
    let end: String?
    let place: String?
    let showsAs: String?
    enum CodingKeys: String, CodingKey { case id, title, start, end, place, showsAs = "shows_as" }
}

private struct Cases: Decodable {
    struct Travel: Decodable { let a: String, b: String, minutes: Int }
    struct ShowsAsCase: Decodable { let item: Item, expect: String; let toggles: [String: String]? }
    struct Expected: Decodable {
        let first: String, second: String, minutes: Int, travel: Bool, split: Bool
        let leaveAt: String?
        enum CodingKeys: String, CodingKey { case first, second, minutes, travel, split, leaveAt = "leave_at" }
    }
    struct ClashCase: Decodable {
        let name: String, items: [Item], expect: [Expected]
        let toggles: [String: String]?, splits: [String]?
    }
    let travel: [Travel]
    let showsAs: [ShowsAsCase]
    let clashes: [ClashCase]
    enum CodingKeys: String, CodingKey { case travel, showsAs = "shows_as", clashes }
}

private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/schedule-rules"))
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}

private func date(_ iso: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = formatter.date(from: iso) { return d }
    formatter.formatOptions = [.withInternetDateTime]
    return try #require(formatter.date(from: iso))
}

private func entry(_ item: Item, defaultMinutes: Int) throws -> NowModel.Entry {
    let start = try date(item.start)
    let end = try item.end.map(date) ?? start.addingTimeInterval(TimeInterval(defaultMinutes * 60))
    return NowModel.Entry(id: item.id, title: item.title, place: item.place ?? "", start: start, end: end,
                          mine: true, official: false, url: nil)
}

@Suite("Shared schedule rules")
struct ScheduleRulesTests {
    @Test func theNumbersAndWordListsAreTheSharedOnes() throws {
        let rules = try fixture("rules", as: Rules.self)
        #expect(rules.travel.sameplaceMinutes == 0)
        #expect(rules.travel.withinSummitMinutes == 5)
        #expect(rules.travel.elsewhereMinutes == 25)
        #expect(rules.defaultDurationMinutes == 30)
        #expect(rules.showsAs.freeMinMinutes == BusyRule.freeMinimumMinutes)
        let patterns: [String] = BusyRule.freeTitlePatterns
        #expect(rules.showsAs.freeTitlePatterns == patterns)
        // every keyword is a summit venue, and a place with none of them is not
        for keyword in rules.travel.summitPlaceKeywords { #expect(DayPlanner.isSummitVenue("The \(keyword) room")) }
        #expect(!DayPlanner.isSummitVenue("Hotel bar, Baixa"))
    }

    @Test func walkingMinutes() throws {
        for vector in try fixture("cases", as: Cases.self).travel {
            #expect(DayPlanner.travelMinutes(from: vector.a, to: vector.b) == vector.minutes,
                    "\(vector.a) to \(vector.b)")
        }
    }

    @Test func busyAndFree() throws {
        for vector in try fixture("cases", as: Cases.self).showsAs {
            let item = try entry(vector.item, defaultMinutes: 30)
            let toggled = vector.toggles?[item.id].flatMap(ShowsAs.init(rawValue:))
            let feed = vector.item.showsAs.flatMap(ShowsAs.init(rawValue:))
            #expect(BusyRule.resolve(item, toggled: toggled, feed: feed).rawValue == vector.expect, "\(vector.item.id)")
        }
    }

    @Test func clashesWithWalkingSplitsAndLeaveTimes() throws {
        for vector in try fixture("cases", as: Cases.self).clashes {
            let items: [DayPlanner.Item] = try vector.items.map { raw in
                let e = try entry(raw, defaultMinutes: 30)
                let toggled = vector.toggles?[e.id].flatMap(ShowsAs.init(rawValue:))
                let feed = raw.showsAs.flatMap(ShowsAs.init(rawValue:))
                let free = BusyRule.resolve(e, toggled: toggled, feed: feed) == .free
                return DayPlanner.Item(id: e.id, kind: .pick, title: e.title, start: e.start, end: e.end, place: e.place,
                                       eventID: e.id, free: free)
            }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
            let found = DayPlanner.clashes(in: items, splits: Set(vector.splits ?? []))
            #expect(found.count == vector.expect.count, "\(vector.name): how many")
            for (clash, want) in zip(found, vector.expect) {
                #expect(clash.first.id == want.first && clash.second.id == want.second, "\(vector.name)")
                #expect(clash.minutes == want.minutes && clash.travel == want.travel && clash.split == want.split, "\(vector.name)")
                let wantLeave: Date? = try want.leaveAt.map(date)
                #expect(clash.leaveAt == wantLeave, "\(vector.name): leave at")
            }
        }
    }
}
