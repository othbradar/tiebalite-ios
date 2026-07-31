import XCTest

final class IPadAppShellSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRegularSplitRouteSurvivesOrientationAndRootSwitch() {
        let app = UITestHarness.launch(scenario: .emptyShell)
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft

        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.tap(.openForum, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.tap(.openThread, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        device.orientation = .portrait
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsRoot, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        device.orientation = .portrait
    }

    @MainActor
    func testCanonicalStateSurvivesRegularCompactRegularProjection() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requireTabSelected(.recommendations, in: app)
        UITestHarness.tap(.openForum, in: app)
        UITestHarness.tap(.openThread, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requireTabSelected(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)
    }
}
