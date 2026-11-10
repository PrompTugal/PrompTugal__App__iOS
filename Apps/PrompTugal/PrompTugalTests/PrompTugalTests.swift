import Foundation
import PTAgenda
import PTCore
import SwiftUI
import Testing
@testable import PrompTugal

@Suite("PrompTugal public app")
struct PublicAppTests {
    @Test("the app bundle is the existing PrompTugal record")
    func bundleId() {
        #expect(Bundle.main.bundleIdentifier == "news.promptugal.reader")
    }

    @Test("Info.plist declares the promptugal URL scheme")
    func urlScheme() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains("promptugal"))
    }

    @Test("the agenda seed is bundled and decodes (offline first launch)")
    func agendaSeed() {
        #expect(AgendaSeed.events().count > 150)
    }

    @Test("iPhone has five tabs in order: Now, My program, Explore, Map, News")
    @MainActor func fiveTabs() {
        let tabs = PublicDestinations.all.filter { $0.phoneTab != nil }.sorted { ($0.phoneTab ?? 0) < ($1.phoneTab ?? 0) }
        #expect(tabs.map(\.id) == ["now", "team.schedule", "explore", "map", "news.home"])
        #expect(tabs.compactMap(\.phoneTab) == [0, 1, 2, 3, 4])
    }

    @Test("More keeps the settings id, so old links still open it")
    @MainActor func moreKeepsItsID() throws {
        let more = try #require(PublicDestinations.destination("settings"))
        #expect(more.title == "More")
        #expect(more.phoneTab == nil)
        #expect(PublicDestinations.listed("More", debug: false).map(\.id).contains("map") == false)
    }

    @Test("promptugal://open/map still opens the map, now a tab")
    @MainActor func mapLinkStillWorks() {
        #expect(PublicDestinations.openable("map", debug: false)?.phoneTab == 3)
    }

    @Test("only one new pick made in the app goes to the calendar")
    func pickCalendarRule() {
        #expect(PickCalendarRule.newPick(old: ["a"], new: ["a", "b"], fromApp: true) == "b")
        #expect(PickCalendarRule.newPick(old: [], new: ["a", "b"], fromApp: true) == nil)
        #expect(PickCalendarRule.newPick(old: ["a"], new: ["a", "b"], fromApp: false) == nil)
        #expect(PickCalendarRule.newPick(old: ["a", "b"], new: ["a"], fromApp: true) == nil)
    }

    @Test("the ids sent to the calendar survive a round trip")
    func pickCalendarIDs() {
        let ids: Set<String> = ["talk-b", "talk-a"]
        #expect(PickCalendarRule.ids(PickCalendarRule.raw(ids)) == ids)
        #expect(PickCalendarRule.ids("").isEmpty)
    }

    @Test("the stand links to RiskMandate's own site over https")
    func standLink() {
        #expect(StandSection.site.scheme == "https")
        #expect(StandSection.site.host == "riskmandate.ai")
    }

    @Test("the public app uses the soft look; story headlines keep the serif")
    @MainActor func softLook() {
        #expect(Look.current == .soft)
        #expect(Typo.headline == Font.system(.headline, weight: .semibold))
        #expect(Typo.story == Font.system(.headline, design: .serif, weight: .semibold))
        #expect(Typo.data == Font.subheadline.monospacedDigit())
        #expect(Space.radius == 22)
    }

    @Test("the greeting follows the time in Lisbon")
    @MainActor func greeting() throws {
        let iso = ISO8601DateFormatter()
        // Lisbon is on UTC in November.
        #expect(NowView.greeting(at: try #require(iso.date(from: "2026-11-11T09:00:00Z"))) == "Good morning")
        #expect(NowView.greeting(at: try #require(iso.date(from: "2026-11-11T11:59:00Z"))) == "Good morning")
        #expect(NowView.greeting(at: try #require(iso.date(from: "2026-11-11T12:00:00Z"))) == "Good afternoon")
        #expect(NowView.greeting(at: try #require(iso.date(from: "2026-11-11T18:00:00Z"))) == "Good evening")
        #expect(NowView.greeting(at: try #require(iso.date(from: "2026-11-11T23:30:00Z"))) == "Good evening")
    }

    @Test("the notice decodes, shows only in its window, and links only to promptugal.news")
    func notice() throws {
        let json = """
        {"id":"storm","show_from":"2026-11-10T19:00:00Z","show_until":"2026-11-11T21:00:00Z","kicker":"Storm Charles",
         "title":"No summit on Wednesday","lines":["One.","Two."],"sources":"IPMA.",
         "link":{"title":"What is known","url":"https://promptugal.news/articles/red-wind-warning-lisbon-wednesday.html"}}
        """
        let notice = try AppNotice.decode(Data(json.utf8))
        let iso = ISO8601DateFormatter()
        #expect(notice.isShowing(at: try #require(iso.date(from: "2026-11-11T09:00:00Z"))))
        #expect(!notice.isShowing(at: try #require(iso.date(from: "2026-11-11T21:00:00Z"))))
        #expect(!notice.isShowing(at: try #require(iso.date(from: "2026-11-10T18:59:00Z"))))
        #expect(notice.safeLink != nil)
        let elsewhere = json.replacingOccurrences(of: "https://promptugal.news/", with: "https://example.com/")
        #expect(try AppNotice.decode(Data(elsewhere.utf8)).safeLink == nil)
    }

    @Test("a day called off leaves the picks that are on it")
    @MainActor func cancelledDays() throws {
        let json = #"{"id":"s","show_from":"2026-11-10T19:00:00Z","show_until":"2026-11-11T21:00:00Z","title":"T","lines":[],"cancelled_days":["2026-11-11"]}"#
        #expect(try AppNotice.decode(Data(json.utf8)).cancelledDays == ["2026-11-11"])
        let before = AgendaHub.cancelledDays
        defer { AgendaHub.cancelledDays = before }
        AgendaHub.cancelledDays = ["2026-11-11"]
        let wednesday = Event(date: "2026-11-11", time: "10:00-10:20", title: "A", place: "Centre Stage", kind: "session",
                              official: true, page: "events/a/index.html")
        let thursday = Event(date: "2026-11-12", time: "10:00-10:20", title: "B", place: "Centre Stage", kind: "session",
                             official: true, page: "events/b/index.html")
        #expect(!AgendaHub.isOn(SchedulePick(id: "a", at: .now, event: wednesday)))
        #expect(AgendaHub.isOn(SchedulePick(id: "b", at: .now, event: thursday)))
        #expect(AgendaHub.isOn(SchedulePick(id: "c", at: .now, event: nil)))
    }

    @Test("the app opens in light mode by default; Match iPhone follows the phone")
    func appearance() {
        #expect(Appearance(rawValue: "light")?.scheme == .light)
        #expect(Appearance.system.scheme == nil)
        #expect((Appearance(rawValue: "") ?? .light).scheme == .light)
    }

    @Test("a category keeps its accent, whatever its case, and the accent is one of the five")
    func categoryAccent() {
        #expect(Palette.accent(for: "AI") == Palette.accent(for: "ai"))
        #expect(Palette.accents.contains(Palette.accent(for: "The summit")))
        #expect(Palette.accents.count == 5)
    }
}
