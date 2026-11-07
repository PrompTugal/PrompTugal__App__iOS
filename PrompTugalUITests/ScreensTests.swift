import UIKit
import XCTest

/// Screenshots of every main screen, for the team and Dinis to see without a Mac.
/// Run by .github/workflows/screens.yml on dev (scheme PrompTugalScreens), one iPhone and one iPad.
/// The shell reads the launch arguments (Shell/LaunchOptions.swift): -PTDestination <id> opens that
/// screen, -PTSampleData uses bundled sample data instead of the network, -PTMe <id> picks who "me" is.
final class ScreensTests: XCTestCase {
    /// Design's `Destinations` ids, exactly.
    static let destinations = [
        "today", "team.people", "agents.activity", "briefed", "news.home", "news.newsroom", "news.graph",
        "obs.native", "debug", "settings", "reader.agenda", "vault", "wall",
    ]

    /// The shell marks the launched destination with this accessibility identifier, so the test can
    /// tell an opened screen from a fallback (an unknown id silently shows the last selection).
    static func marker(_ id: String) -> String { "pt.destination.\(id)" }

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testEveryScreen() {
        // Landscape on iPad shows the sidebar and the detail side by side, as the team uses it.
        // screens.yml turns the iPad PNGs upright (the raw capture is in portrait pixels).
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        for id in Self.destinations {
            let app = XCUIApplication()
            app.launchArguments = ["-PTDestination", id, "-PTSampleData", "-PTMe", "ana"]
            app.launch()
            let opened = app.descendants(matching: .any)[Self.marker(id)].waitForExistence(timeout: 10)
            sleep(1)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = id
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertTrue(opened, "Destination \(id) did not open (no element \(Self.marker(id)))")
            app.terminate()
        }
    }
}
