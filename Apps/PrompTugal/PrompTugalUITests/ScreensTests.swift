import UIKit
import XCTest

/// Screenshots of the public app's main screens, for the App Store pages and the team.
/// Run by .github/workflows/screens.yml (scheme PrompTugalScreens), one test per screen so a crash or a slow
/// accessibility query on one screen cannot stop the others. Each test attaches one screenshot named
/// "<NN>-<screen id>" (lifetime .keepAlways); NN is ux's store order.
///
/// Launch arguments (DEBUG builds only):
///   -PTDestination <id>   opens that screen (Shell/PublicShell.swift)
///   -PTSampleData         sample data instead of the network (ignored where not supported)
///   -PTNow <ISO date>     the app's "now" clock, from the environment variable PT_NOW when it is not empty
///                         (screens.yml sets TEST_RUNNER_PT_NOW); empty means real time
///   -PTHideTerm <text>    hides events and news containing the text (Debug only), from PT_HIDE_TERM when not empty
///   -PTSeedPicks <ids>    seeded picks, from the environment variable PT_SEED_PICKS when it is not empty
///
/// The ids come from ux. A destination that does not exist yet opens whatever the shell shows by default, so a
/// screenshot is still attached for it (screens.yml reports the ones it requires: now, team.schedule, explore, news.home).
final class ScreensTests: XCTestCase {
    /// ux's list, in store order.
    static let destinations = ["now", "team.schedule", "explore", "explore.talk", "news.home", "explore.people", "explore.graph", "map"]

    @MainActor func test01_now() { shoot(1, "now") }
    @MainActor func test02_team_schedule() { shoot(2, "team.schedule") }
    @MainActor func test03_explore() { shoot(3, "explore") }
    @MainActor func test04_explore_talk() { shoot(4, "explore.talk") }
    @MainActor func test05_news_home() { shoot(5, "news.home") }
    @MainActor func test06_explore_people() { shoot(6, "explore.people") }
    @MainActor func test07_explore_graph() { shoot(7, "explore.graph") }
    @MainActor func test08_map() { shoot(8, "map") }

    func testListMatchesTheTestMethods() {
        XCTAssertEqual(Self.destinations.count, 8)
    }

    override func setUp() {
        continueAfterFailure = true
    }

    /// The launch arguments for one screen: pure, so a unit test can check them.
    static func launchArguments(destination: String, environment: [String: String]) -> [String] {
        // Debug mode off, as in the Release build: no surface badges, no debug-only screens in the sidebar.
        var args = ["-PTDestination", destination, "-PTSampleData", "-debug.enabled", "NO"]
        if let now = environment["PT_NOW"], !now.isEmpty { args += ["-PTNow", now] }
        if let term = environment["PT_HIDE_TERM"], !term.isEmpty { args += ["-PTHideTerm", term] }
        if let picks = environment["PT_SEED_PICKS"], !picks.isEmpty { args += ["-PTSeedPicks", picks] }
        return args
    }

    func testLaunchArgumentsForwardTheClockAndThePicks() {
        XCTAssertEqual(Self.launchArguments(destination: "now", environment: [:]),
                       ["-PTDestination", "now", "-PTSampleData", "-debug.enabled", "NO"])
        XCTAssertEqual(Self.launchArguments(destination: "now", environment: ["PT_NOW": "", "PT_SEED_PICKS": ""]),
                       ["-PTDestination", "now", "-PTSampleData", "-debug.enabled", "NO"])
        XCTAssertEqual(
            Self.launchArguments(destination: "explore",
                                 environment: ["PT_NOW": "2026-11-10T11:00:00Z", "PT_SEED_PICKS": "a,b"]),
            ["-PTDestination", "explore", "-PTSampleData", "-debug.enabled", "NO", "-PTNow", "2026-11-10T11:00:00Z", "-PTSeedPicks", "a,b"])
        XCTAssertEqual(
            Self.launchArguments(destination: "now", environment: ["PT_HIDE_TERM": "Web Summit", "PT_SEED_PICKS": "a"]),
            ["-PTDestination", "now", "-PTSampleData", "-debug.enabled", "NO", "-PTHideTerm", "Web Summit", "-PTSeedPicks", "a"])
        XCTAssertEqual(Self.launchArguments(destination: "now", environment: ["PT_HIDE_TERM": ""]),
                       ["-PTDestination", "now", "-PTSampleData", "-debug.enabled", "NO"])
    }

    @MainActor
    private func shoot(_ index: Int, _ id: String) {
        // Landscape on iPad shows the sidebar and the detail side by side. screens.yml turns the iPad PNGs upright
        // from their EXIF orientation (the raw capture is the portrait framebuffer).
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments(destination: id, environment: ProcessInfo.processInfo.environment)
        app.launch()
        Self.dismissSystemAlert()
        sleep(3)
        // The reminders ask for notification permission once picks are seeded; the alert can appear late.
        Self.dismissSystemAlert(timeout: 1)
        // The whole screen, not app.screenshot(): in landscape on iPad the app element's capture crops the portrait
        // framebuffer and leaves black areas.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", index, id)
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    /// A system permission alert (notifications) sits in SpringBoard above every later launch and would be in every
    /// screenshot. Tap its last button, "Allow" in every language, so the shots show the app and My program shows
    /// no "notifications are off" warning.
    @MainActor
    private static func dismissSystemAlert(timeout: TimeInterval = 5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: timeout), alert.buttons.count > 0 {
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            sleep(1)
        }
    }
}
