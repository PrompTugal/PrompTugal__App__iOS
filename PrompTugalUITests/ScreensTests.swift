import UIKit
import XCTest

/// Screenshots of every main screen, for the team and Dinis to see without a Mac.
/// Run by .github/workflows/screens.yml on dev (scheme PrompTugalScreens), one iPhone and one iPad.
/// The shell reads the launch arguments: -PTDestination <id> opens that screen, -PTSampleData uses
/// bundled sample data instead of the network, -PTMe <person id> picks who "me" is.
final class ScreensTests: XCTestCase {
    static let destinations = [
        "today", "team.people", "agents.activity", "briefed", "news.home", "news.newsroom", "news.graph",
        "obs.native", "debug", "settings", "reader.agenda", "vault",
    ]

    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testEveryScreen() {
        // Landscape on iPad shows the sidebar and the detail side by side, as the team uses it.
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        for id in Self.destinations {
            let app = XCUIApplication()
            app.launchArguments = ["-PTDestination", id, "-PTSampleData", "-PTMe", "ana"]
            app.launch()
            sleep(2)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = id
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
