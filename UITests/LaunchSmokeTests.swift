import XCTest

final class LaunchSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsStablePlaceholder() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["app.launch-placeholder.root"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["app.launch-placeholder.title"].exists)
        XCTAssertTrue(app.staticTexts["app.launch-placeholder.environment"].exists)
    }
}
