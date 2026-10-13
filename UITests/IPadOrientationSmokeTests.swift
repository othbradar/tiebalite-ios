import XCTest

final class IPadOrientationSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeUsesFullPortraitWidthAndLandscapeSidebarThreeTimes() {
        executionTimeAllowance = 120
        let device = XCUIDevice.shared
        device.orientation = .portrait
        defer { device.orientation = .portrait }
        // This scenario uses the production scene without the layout harness.
        let app = UITestHarness.launchIsolated(scenario: .rootNavigationMixedMedia)
        let search = app.buttons["home.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            for landscape in [true, false] {
                device.orientation = landscape ? .landscapeLeft : .portrait
                let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let window = app.windows.firstMatch.frame
                    let ratio = search.frame.width / window.width
                    return window.width > 0 && window.height > 0 && search.isHittable
                        && (window.width > window.height) == landscape
                        && (landscape ? ratio < 0.8 : ratio > 0.9)
                }, object: app)
                XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 5), .completed)
                UITestHarness.requireTabSelected(.followedForums, in: app)
            }
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "Home after three orientation round trips")
    }
}
