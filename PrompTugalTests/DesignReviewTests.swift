import CoreGraphics
import Foundation
import Testing
@testable import PrompTugal

// Tests for the design session's App Review readiness fixes (briefs/2026-11-08__app-review-readiness).

@Suite("Wake grid taps")
struct WakeGridTapTests {
    @Test("A tap on the hour header selects nothing; rows map from the header down")
    func rows() {
        #expect(WakeGrid.row(at: 5, header: 18, rowHeight: 18, count: 3) == nil)
        #expect(WakeGrid.row(at: 17.9, header: 18, rowHeight: 18, count: 3) == nil)
        #expect(WakeGrid.row(at: 18, header: 18, rowHeight: 18, count: 3) == 0)
        #expect(WakeGrid.row(at: 40, header: 18, rowHeight: 18, count: 3) == 1)
        #expect(WakeGrid.row(at: 200, header: 18, rowHeight: 18, count: 3) == nil)
    }
}

@MainActor
@Suite("Debug mode and links (S4)")
struct DebugLinkTests {
    @Test("Debug-only screens open from a link only while debug mode is on")
    func openable() {
        #expect(Destinations.openable("debug", debug: false) == nil)
        #expect(Destinations.openable("debug", debug: true)?.id == "debug")
        #expect(Destinations.openable("today", debug: false)?.id == "today")
        #expect(Destinations.openable("no-such-screen", debug: true) == nil)
    }

    @Test("Debug mode is on by default only in debug builds")
    func defaultOn() {
        #if DEBUG
        #expect(DebugMode.defaultOn)
        #else
        #expect(!DebugMode.defaultOn)
        #endif
    }
}

@MainActor
@Suite("Sample data for App Review (R1)")
struct SampleDataTests {
    @Test("Sample data fills the team, agents and newsroom, and stays put")
    func sampleData() async {
        let data = PreviewSamples.data()
        #expect(data.team.value?.people?.count == 2)
        #expect(data.person(SampleMode.samplePersonID)?.first == "Ana")
        #expect(data.dashboard.value?.agents?.count == 3)
        #expect(data.status.value?.pipeline?.isEmpty == false)
        #expect(data.board.value?.stories?.count == 3)
        #expect(data.team.pinned)

        // A pinned feed never goes to the network, even when forced.
        let before = data.team.updated
        await data.team.load(force: true)
        #expect(data.team.updated == before)
        #expect(data.team.value?.people?.count == 2)
    }

    @Test("Loading sample data does not change who I am")
    func dataLeavesIdentity() {
        let saved = UserDefaults.standard.string(forKey: DashboardData.meKey)
        defer { UserDefaults.standard.set(saved, forKey: DashboardData.meKey) }
        UserDefaults.standard.set("someone", forKey: DashboardData.meKey)
        _ = PreviewSamples.data()
        #expect(UserDefaults.standard.string(forKey: DashboardData.meKey) == "someone")
    }

    @Test("Leaving sample mode puts the previous choice back")
    func enterAndLeave() throws {
        let defaults = try #require(UserDefaults(suiteName: "pt.tests.sample.\(UUID().uuidString)"))
        defaults.set(SampleMode.readerID, forKey: DashboardData.meKey)
        SampleMode.enter(defaults: defaults)
        #expect(defaults.bool(forKey: SampleMode.key))
        #expect(defaults.string(forKey: DashboardData.meKey) == SampleMode.samplePersonID)
        SampleMode.leave(defaults: defaults)
        #expect(!defaults.bool(forKey: SampleMode.key))
        #expect(defaults.string(forKey: DashboardData.meKey) == SampleMode.readerID)
        #expect(defaults.string(forKey: SampleMode.previousKey) == nil)
    }

    @Test("The reader and sample ids are distinct from each other and from any real person")
    func ids() {
        #expect(SampleMode.readerID != SampleMode.samplePersonID)
        #expect(!SampleMode.readerID.isEmpty)
    }
}

@Suite("Settings links (R3)")
struct SupportLinkTests {
    @Test("Privacy and support pages are https on the app's own site")
    func links() {
        for url in [SupportLinks.privacy, SupportLinks.support] {
            #expect(url.scheme == "https")
            #expect(url.host() == "ios.app.promptugal.news")
        }
        #expect(SupportLinks.privacy.lastPathComponent == "privacy.html")
        #expect(SupportLinks.support.lastPathComponent == "support.html")
        #expect(SupportLinks.independence.contains("not affiliated"))
    }
}

@Suite("Layouts for Split View (Q9)")
struct SplitViewLayoutTests {
    @Test("The wall uses two columns only when there is room, with a bounded side column")
    func wall() {
        #expect(!WallLayout.twoColumns(width: 507))   // half-screen iPad Split View
        #expect(!WallLayout.twoColumns(width: 375))   // iPhone SE
        #expect(WallLayout.twoColumns(width: 1180))
        #expect(WallLayout.sideColumn(width: 760) == 280)
        #expect(WallLayout.sideColumn(width: 1366) == 380)
    }
}

@MainActor
@Suite("Team notes: reading credit, checkout, reminder links")
struct TeamNotesTests {
    @Test("Reading credit is in the shell only when it is available (R5)")
    func readingCredit() {
        #expect((Destinations.destination("team.store") != nil) == ReadingCredit.isAvailable)
    }

    @Test("WebPage refuses checkout pages, including new Stripe subdomains (3.1.1)")
    func checkout() throws {
        #expect(WebPageModel.refuses(try #require(URL(string: "https://buy.stripe.com/abc"))))
        #expect(WebPageModel.refuses(try #require(URL(string: "https://checkout.stripe.com/pay"))))
        #expect(!WebPageModel.refuses(try #require(URL(string: "https://promptugal.news/agenda/"))))
    }

    @Test("A reminder's session link opens that session; briefing links only on our own sites (Q6)")
    func links() throws {
        let session = try #require(URL(string: "promptugal://open/team.schedule?session=ai-your-new-news-editor"))
        #expect(ShellLink.page(in: session)?.url.absoluteString
                == "https://promptugal.news/events/ai-your-new-news-editor/index.html")

        let briefing = try #require(URL(string: "promptugal://open/team.schedule?url=https://web-summit.sgit.ai/meetings/x/"))
        #expect(ShellLink.page(in: briefing)?.url.host() == "web-summit.sgit.ai")

        let elsewhere = try #require(URL(string: "promptugal://open/team.schedule?url=https://example.com/"))
        #expect(ShellLink.page(in: elsewhere) == nil)

        let odd = try #require(URL(string: "promptugal://open/team.schedule?session=../../x"))
        #expect(ShellLink.page(in: odd) == nil)

        let plain = try #require(URL(string: "promptugal://open/team.schedule"))
        #expect(ShellLink.page(in: plain) == nil)
    }
}
