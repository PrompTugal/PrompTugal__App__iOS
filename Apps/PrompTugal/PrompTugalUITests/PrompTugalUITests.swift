import UIKit
import XCTest

final class PrompTugalUITests: XCTestCase {
    @MainActor
    func testLaunchShowsShell() {
        let app = XCUIApplication()
        app.launch()
        // The shell's own identifier (PublicShell, "public-shell"), whatever element type SwiftUI gives the container:
        // the Now screen shows no "PrompTugal" text, so that is no longer a stable thing to wait for.
        let shell = app.descendants(matching: .any).matching(identifier: "public-shell").firstMatch
        XCTAssertTrue(shell.waitForExistence(timeout: 10))
    }

    /// Round 1 of the redesign: five tabs on iPhone, and the More button on every one of them opens More.
    @MainActor
    func testEveryTabHasMore() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "iPad uses the sidebar, not tabs")
        let app = XCUIApplication()
        app.launchArguments = ["-PTDestination", "now", "-PTSampleData", "-debug.enabled", "NO"]
        app.launch()
        for tab in ["Now", "My program", "Explore", "Map", "News"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "no \(tab) tab")
            button.tap()
            XCTAssertTrue(app.buttons["pt.more"].firstMatch.waitForExistence(timeout: 5), "no More button on \(tab)")
        }
        app.buttons["pt.more"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
    }
}

