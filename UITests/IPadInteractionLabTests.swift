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

    @MainActor
    func testMediaZoomPagingRotationAndCloseOnIPad() {
        let app = UITestHarness.launch(scenario: .emptyShell)
        let device = XCUIDevice.shared
        device.orientation = .portrait

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.tap(.debugOpenInteractionLab, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.tap(.interactionSectionMedia, in: app)
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
        UITestHarness.tap(.interactionMediaOpenMultiple, in: app)
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )

        let zoomSurface = app.descendants(matching: .any)[
            "interaction.media.zoom-surface.large"
        ]
        XCTAssertTrue(zoomSurface.waitForExistence(timeout: 5))
        zoomSurface.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        UITestHarness.requireLabelNotEqual(
            .interactionMediaZoom,
            to: "Zoom: 1.00",
            in: app
        )

        device.orientation = .landscapeLeft
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )
        UITestHarness.requireLabelNotEqual(
            .interactionMediaZoom,
            to: "Zoom: 1.00",
            in: app
        )

        UITestHarness.tap(.interactionMediaAccessibilityNext, in: app)
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: delayed",
            in: app
        )
        UITestHarness.tap(.interactionMediaAccessibilityPrevious, in: app)
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionMediaZoom,
            equals: "Zoom: 1.00",
            in: app
        )

        UITestHarness.tap(.interactionMediaClose, in: app)
        UITestHarness.requireLabel(
            .interactionMediaOverlayState,
            equals: "Overlay: absent",
            in: app
        )
        device.orientation = .portrait
    }
}
