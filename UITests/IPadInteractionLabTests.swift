import XCTest

final class IPadInteractionLabTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPagerIDSurvivesOrientationAndRegularCompactProjection() {
        let app = UITestHarness.launch(scenario: .emptyShell)
        let device = XCUIDevice.shared

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.tap(.debugOpenInteractionLab, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )

        device.orientation = .landscapeLeft
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )
        device.orientation = .portrait
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )

        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )

        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )
        device.orientation = .portrait
    }
}
