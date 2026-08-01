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
        for cancellationCount in 1...5 {
            let start = page.coordinate(
                withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5)
            )
            let halfTravel = page.coordinate(
                withNormalizedOffset: CGVector(dx: 0.44, dy: 0.5)
            )
            start.press(
                forDuration: 0.1,
                thenDragTo: halfTravel,
                withVelocity: .slow,
                thenHoldForDuration: 0.1
            )

            UITestHarness.requireLabel(
                .interactionCurrentPage,
                equals: "Current ID: p2",
                in: app
            )
            UITestHarness.requireLabel(
                .interactionPagerTransition,
                equals: "Transition: idle-cancelled",
                in: app
            )
            UITestHarness.requireLabel(
                .interactionPagerCompletion,
                equals: "Resolved: \(cancellationCount)",
                in: app
            )
        }

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
    func testPagerCoordinatorSurvivesRotationWithTheSelectedBusinessID() {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        let app = launchPagerLab()

        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )
        let sequence = UITestHarness.element(
            .interactionPagerCoordinatorSequence,
            in: app
        )
        XCTAssertTrue(sequence.waitForExistence(timeout: 5))
        let sequenceBeforeRotation = sequence.label

        device.orientation = .landscapeLeft
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

        XCTAssertEqual(sequence.label, sequenceBeforeRotation)
        device.orientation = .portrait
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )
        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )
        XCTAssertEqual(sequence.label, sequenceBeforeRotation)
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
