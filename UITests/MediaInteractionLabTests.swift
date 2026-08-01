import XCTest

extension InteractionLabTests {
    @MainActor
    func testMediaSingleAndMultipleLoadingFailureZoomAndClose() {
        let app = launchMediaLab()
        verifySingleMediaPresentation(in: app)
        verifyMultipleMediaPresentation(in: app)
    }

    @MainActor
    func testMediaPinchPanChromeAndCancelledPagingStayOnCurrentID() {
        let app = launchMediaLab()
        UITestHarness.tap(.interactionMediaOpenMultiple, in: app)

        let zoomSurface = app.descendants(matching: .any)[
            "interaction.media.zoom-surface.large"
        ]
        XCTAssertTrue(zoomSurface.waitForExistence(timeout: 5))
        zoomSurface.pinch(withScale: 2.0, velocity: 1.0)
        UITestHarness.requireLabelNotEqual(
            .interactionMediaZoom,
            to: "Zoom: 1.00",
            in: app
        )
        zoomSurface.swipeLeft()
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )

        zoomSurface.tap()
        UITestHarness.waitUntilAbsent(.interactionMediaClose, in: app)
        zoomSurface.tap()
        UITestHarness.requirePresent(.interactionMediaClose, in: app)
        UITestHarness.tap(.interactionMediaClose, in: app)
    }

    @MainActor
    func testMediaFiveOpenCloseCyclesLeaveNoPresentedOverlay() {
        let app = launchMediaLab()

        for _ in 0..<5 {
            UITestHarness.tap(.interactionMediaOpenSingle, in: app)
            UITestHarness.requireLabel(
                .interactionMediaCurrent,
                equals: "Current: small",
                in: app
            )
            UITestHarness.tap(.interactionMediaClose, in: app)
            UITestHarness.requireLabel(
                .interactionMediaOverlayState,
                equals: "Overlay: absent",
                in: app
            )
        }
    }

    @MainActor
    private func verifySingleMediaPresentation(in app: XCUIApplication) {
        UITestHarness.tap(.interactionMediaOpenSingle, in: app)
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: small",
            in: app
        )
        UITestHarness.tap(.interactionMediaClose, in: app)
        UITestHarness.requireLabel(
            .interactionMediaOverlayState,
            equals: "Overlay: absent",
            in: app
        )
    }

    @MainActor
    private func verifyMultipleMediaPresentation(in app: XCUIApplication) {
        UITestHarness.tap(.interactionMediaOpenMultiple, in: app)
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )
        verifyAccessibleMediaPaging(in: app)

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
        zoomSurface.swipeLeft()
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )

        verifyAccessibleMediaPaging(in: app)
        UITestHarness.requireLabel(
            .interactionMediaZoom,
            equals: "Zoom: 1.00",
            in: app
        )
        zoomSurface.swipeLeft()
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: delayed",
            in: app
        )
        UITestHarness.requirePresent(.interactionMediaLoading, in: app)

        app.swipeLeft()
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: failure",
            in: app
        )
        UITestHarness.requirePresent(.interactionMediaFailure, in: app)
        UITestHarness.tap(.interactionMediaRetryFailure, in: app)
        UITestHarness.waitUntilAbsent(.interactionMediaFailure, in: app)

        app.swipeRight()
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: delayed",
            in: app
        )
        UITestHarness.tap(.interactionMediaReleaseDelayed, in: app)
        UITestHarness.waitUntilAbsent(.interactionMediaLoading, in: app)

        app.swipeRight()
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
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
        UITestHarness.requireLabel(
            .interactionMediaOverlayState,
            equals: "Overlay: absent",
            in: app
        )
    }

    @MainActor
    private func verifyAccessibleMediaPaging(in app: XCUIApplication) {
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
    }

    @MainActor
    private func launchMediaLab() -> XCUIApplication {
        let app = UITestHarness.launch(scenario: .emptyShell)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenInteractionLab, in: app)
        UITestHarness.tap(.debugOpenInteractionLab, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.tap(.interactionSectionMedia, in: app)
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
        return app
    }
}
