import XCTest

final class PrompTugalUITests: XCTestCase {
    @MainActor
    func testLaunchShowsShell() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["PrompTugal"].waitForExistence(timeout: 10))
    }
}
