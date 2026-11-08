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
}
