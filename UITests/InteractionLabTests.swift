import XCTest

final class InteractionLabTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUIKitPagerCompletesTwentyAlternatingStableIDTransitions() {
        let app = launchPagerLab()

        UITestHarness.requireLabel(
            .interactionCandidate,
            equals: "Candidate: UIPageViewController",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )

        for _ in 0..<10 {
            swipePagerPage(.interactionPagerPageP2, left: true, in: app)
            UITestHarness.requireLabel(
                .interactionCurrentPage,
                equals: "Current ID: p3",
                in: app
            )
            swipePagerPage(.interactionPagerPageP3, left: false, in: app)
            UITestHarness.requireLabel(
                .interactionCurrentPage,
                equals: "Current ID: p2",
                in: app
            )
        }

        UITestHarness.requireLabel(
            .interactionPagerCompletion,
            equals: "Resolved: 20",
            in: app
        )
        assertControllerCountIsBounded(in: app)
        UITestHarness.attachSafeVisualEvidence(
            app: app,
            name: "UIKit pager after twenty alternating swipes"
        )
    }

    @MainActor
    func testUIKitPagerCancellationAndMidTransitionMutationsKeepBusinessID() {
        let app = launchPagerLab()
        let page = UITestHarness.element(.interactionPagerPageP2, in: app)
        let start = page.coordinate(
            withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5)
        )
        let shortEnd = page.coordinate(
            withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)
        )
        start.press(
            forDuration: 0.5,
            thenDragTo: shortEnd,
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )

        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )

        UITestHarness.tap(.interactionPagerArmInsert, in: app)
        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerPosition,
            equals: "Position: 5/6",
            in: app
        )

        UITestHarness.tap(.interactionPagerReset, in: app)
        UITestHarness.tap(.interactionPagerArmDelete, in: app)
        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerPosition,
            equals: "Position: 3/4",
            in: app
        )

        UITestHarness.tap(.interactionPagerReset, in: app)
        UITestHarness.tap(.interactionPagerArmReorder, in: app)
        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )

        UITestHarness.tap(.interactionPagerReset, in: app)
        UITestHarness.tap(.interactionPagerArmRefresh, in: app)
        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionPagerRefresh,
            equals: "Refresh: idle",
            in: app
        )
    }

    @MainActor
    func testPagerKeepsIDAcrossRotationReduceMotionAndSystemEdgeBack() {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        let app = launchPagerLab(
            displayProfile: .darkAccessibilityReduced
        )

        UITestHarness.tap(.interactionPagerAccessibilityNext, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )
        UITestHarness.tap(.interactionPagerAccessibilityPrevious, in: app)
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
        let visiblePage = UITestHarness.element(
            .interactionPagerPageP2,
            in: app
        )
        XCTAssertTrue(visiblePage.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(
            visiblePage.frame.height,
            44,
            "The current pager page must retain a visible landscape frame."
        )
        let viewportHeight = UITestHarness.element(
            .interactionPagerViewportHeight,
            in: app
        )
        XCTAssertTrue(viewportHeight.waitForExistence(timeout: 5))
        let measuredHeight = Double(
            viewportHeight.label.replacingOccurrences(
                of: "Viewport height: ",
                with: ""
            )
        )
        XCTAssertNotNil(measuredHeight)
        XCTAssertGreaterThan(
            measuredHeight ?? 0,
            80,
            "The pager viewport must not collapse in landscape."
        )
        device.orientation = .portrait
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )

        UITestHarness.swipeSystemBack(
            in: app,
            returningTo: .settingsRoot
        )
        device.orientation = .portrait
    }

    @MainActor
    func testMediaSingleAndMultipleLoadingFailureZoomAndClose() {
        let app = launchMediaLab()
        verifySingleMediaPresentation(in: app)
        verifyMultipleMediaPresentation(in: app)
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

        zoomSurface.tap(withNumberOfTaps: 2, numberOfTouches: 1)
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
    private func launchPagerLab(
        displayProfile: UITestDisplayProfile = .system
    ) -> XCUIApplication {
        let app = UITestHarness.launch(
            scenario: .emptyShell,
            displayProfile: displayProfile
        )
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(
            .debugOpenInteractionLab,
            in: app
        )
        UITestHarness.tap(.debugOpenInteractionLab, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        return app
    }

    @MainActor
    private func launchMediaLab() -> XCUIApplication {
        let app = launchPagerLab()
        UITestHarness.tap(.interactionSectionMedia, in: app)
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
        return app
    }

    @MainActor
    private func swipePagerPage(
        _ identifier: UITestElementID,
        left: Bool,
        in app: XCUIApplication
    ) {
        let element = UITestHarness.element(identifier, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        if left {
            element.swipeLeft()
        } else {
            element.swipeRight()
        }
    }

}

private extension InteractionLabTests {
    @MainActor
    func assertControllerCountIsBounded(in app: XCUIApplication) {
        let element = UITestHarness.element(
            .interactionPagerControllerCount,
            in: app
        )
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let count = Int(
            element.label.replacingOccurrences(
                of: "Controllers: ",
                with: ""
            )
        )
        XCTAssertNotNil(count)
        XCTAssertLessThanOrEqual(count ?? .max, 4)
    }
}
