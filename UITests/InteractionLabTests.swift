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
            equals: "State: refreshing",
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
        defer { device.orientation = .portrait }
        let app = launchPagerLab()
        let coordinatorSequence = UITestHarness.element(
            .interactionPagerCoordinatorSequence,
            in: app
        )
        let childSequence = UITestHarness.element(
            .interactionPagerPageP2ControllerSequence,
            in: app
        )
        XCTAssertTrue(coordinatorSequence.waitForExistence(timeout: 5))
        XCTAssertTrue(childSequence.waitForExistence(timeout: 5))
        UITestHarness.requireLabelNotEqual(
            .interactionPagerCoordinatorSequence,
            to: "Coordinator: 0",
            in: app
        )
        let settledSnapshots = UITestHarness.element(
            .interactionPagerSettledSnapshotCount,
            in: app
        )
        XCTAssertTrue(settledSnapshots.waitForExistence(timeout: 5))
        let coordinatorBeforeRotation = coordinatorSequence.label
        let childBeforeRotation = childSequence.label

        for _ in 0..<5 {
            let beforeLandscape = settledSnapshots.label
            device.orientation = .landscapeLeft
            UITestHarness.requireLabelNotEqual(
                .interactionPagerSettledSnapshotCount,
                to: beforeLandscape,
                in: app
            )
            requirePagerP2IdentityAndCoverage(
                childSequence: childBeforeRotation,
                in: app
            )
            XCTAssertEqual(
                coordinatorSequence.label,
                coordinatorBeforeRotation
            )
            let beforePortrait = settledSnapshots.label
            device.orientation = .portrait
            UITestHarness.requireLabelNotEqual(
                .interactionPagerSettledSnapshotCount,
                to: beforePortrait,
                in: app
            )
            requirePagerP2IdentityAndCoverage(
                childSequence: childBeforeRotation,
                in: app
            )
            XCTAssertEqual(
                coordinatorSequence.label,
                coordinatorBeforeRotation
            )
        }

        swipePagerPage(.interactionPagerPageP2, left: true, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p3",
            in: app
        )
        swipePagerPage(.interactionPagerPageP3, left: false, in: app)
        requirePagerP2IdentityAndCoverage(
            childSequence: childBeforeRotation,
            in: app
        )
        XCTAssertEqual(
            coordinatorSequence.label,
            coordinatorBeforeRotation
        )
    }

}

private extension InteractionLabTests {
    @MainActor
    func requirePagerP2IdentityAndCoverage(
        childSequence: String,
        in app: XCUIApplication
    ) {
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerPosition,
            equals: "Position: 3/5",
            in: app
        )
        let page = UITestHarness.element(.interactionPagerPageP2, in: app)
        let width = pagerDimension(
            .interactionPagerViewportWidth,
            prefix: "Viewport width: ",
            in: app
        )
        let height = pagerDimension(
            .interactionPagerViewportHeight,
            prefix: "Viewport height: ",
            in: app
        )
        let sequence = UITestHarness.element(
            .interactionPagerPageP2ControllerSequence,
            in: app
        )
        let hostBounds = Pager06CBHostGeometryAssertions
            .requireOpaqueBoundsCoverage(in: app)
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        XCTAssertEqual(sequence.label, childSequence)
        XCTAssertGreaterThan(width, 0)
        XCTAssertGreaterThan(height, 0)
        XCTAssertGreaterThan(page.frame.width, 44)
        XCTAssertGreaterThan(page.frame.height, 44)
        XCTAssertEqual(hostBounds.width, width, accuracy: 1)
        XCTAssertEqual(hostBounds.height, height, accuracy: 1)
        let sequenceValue = childSequence.replacingOccurrences(
            of: "Controller: ",
            with: ""
        )
        let settled = UITestHarness.element(
            .interactionPagerSettledProjection,
            in: app
        )
        XCTAssertTrue(settled.waitForExistence(timeout: 5))
        XCTAssertEqual(
            settled.label,
            "Settled: committed p2, visible p2, controller "
                + "\(sequenceValue), cached \(sequenceValue), callbacks 0, "
                + "overlaps 0, sentinel 0"
        )
    }

    @MainActor
    func pagerDimension(
        _ identifier: UITestElementID,
        prefix: String,
        in app: XCUIApplication
    ) -> CGFloat {
        let element = UITestHarness.element(identifier, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let value = Double(
            element.label.replacingOccurrences(of: prefix, with: "")
        )
        XCTAssertNotNil(value)
        return CGFloat(value ?? 0)
    }

    @MainActor
    func launchPagerLab(
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
