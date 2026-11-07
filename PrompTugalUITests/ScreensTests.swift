import UIKit
import XCTest

/// Screenshots of every main screen, for the team and Dinis to see without a Mac.
/// Run by .github/workflows/screens.yml on dev (scheme PrompTugalScreens), one iPhone and one iPad.
/// The shell reads the launch arguments (Shell/LaunchOptions.swift): -PTDestination <id> opens that
/// screen, -PTSampleData uses bundled sample data instead of the network, -team.me <id> picks who "me" is for
/// this launch (a UserDefaults argument, never saved).
///
/// One test per screen, so a crash or a slow accessibility query on one screen cannot stop the others.
final class ScreensTests: XCTestCase {
    /// Design's `Destinations` ids, exactly. screens.yml expects one PNG per id (13).
    static let destinations = ["today", "team.people", "agents.activity", "briefed", "news.home", "news.newsroom", "news.graph", "obs.native", "debug", "settings", "reader.agenda", "vault", "wall"]

    /// The shell marks every destination view with this accessibility identifier, so the test can tell
    /// an opened screen from a fallback (an unknown id silently shows the last selection).
    static func marker(_ id: String) -> String { "pt.destination.\(id)" }

    @MainActor func test01_today() { shoot("today") }
    @MainActor func test02_team_people() { shoot("team.people") }
    @MainActor func test03_agents_activity() { shoot("agents.activity") }
    @MainActor func test04_briefed() { shoot("briefed") }
    @MainActor func test05_news_home() { shoot("news.home") }
    @MainActor func test06_news_newsroom() { shoot("news.newsroom") }
    @MainActor func test07_news_graph() { shoot("news.graph") }
    @MainActor func test08_obs_native() { shoot("obs.native") }
    @MainActor func test09_debug() { shoot("debug") }
    @MainActor func test10_settings() { shoot("settings") }
    @MainActor func test11_reader_agenda() { shoot("reader.agenda") }
    @MainActor func test12_vault() { shoot("vault") }
    @MainActor func test13_wall() { shoot("wall") }

    func testListMatchesTheTestMethods() {
        XCTAssertEqual(Self.destinations.count, 13)
    }

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    private func shoot(_ id: String) {
        // Landscape on iPad shows the sidebar and the detail side by side, as the team uses it.
        // screens.yml turns the iPad PNGs upright from their EXIF orientation (the raw capture is
        // the portrait framebuffer).
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        let app = XCUIApplication()
        app.launchArguments = ["-PTDestination", id, "-PTSampleData", "-team.me", "ana"]
        app.launch()
        sleep(3)
        // Keep the screenshot first: the check below can time out on a screen with a very large
        // accessibility tree (the full agenda), and a query timeout ends the test.
        // The whole screen, not app.screenshot(): in landscape on iPad, the app element's capture
        // crops the portrait framebuffer to the landscape frame, which kept only a square of the UI
        // and filled the rest with black (screens run 13).
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = id
        attachment.lifetime = .keepAlways
        add(attachment)
        let marker = app.descendants(matching: .any).matching(identifier: Self.marker(id)).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 10),
                      "Destination \(id) did not open (no element \(Self.marker(id)))")
        app.terminate()
    }
}
