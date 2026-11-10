import Foundation
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
}
