import XCTest

extension InteractionLabTests {
    @MainActor
    func testPagerBoundaryPageSettlesToOpaqueFullGeometry() {
        let app = launch06CBPagerLab()
        let viewport = UITestHarness.element(
            .interactionPagerAdjustable,
            in: app
        )
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        viewport.swipeLeft(velocity: .fast)
        viewport.swipeLeft(velocity: .fast)
        require06CBVisualSelection(
            id: "p4",
            position: "5/5",
            page: .interactionPagerPageP4,
            in: app
        )
    }

    @MainActor
    func testPagerRuntimeDistanceAndVelocityPolicyEvidence() throws {
        let app = launch06CBPagerLab()
        var belowThresholdVelocities: [Double] = []
        var aboveThresholdVelocities: [Double] = []

        for _ in 0..<5 {
            reset06CBPager(in: app)
            drag06CBPager(
                distance: 0.49,
                velocity: .slow,
                hold: 0.20,
                in: app
            )
            require06CBResolution(
                currentID: "p2",
                reason: "system-bailout",
                visualID: "p2",
                traceProgress: 0.49,
                in: app
            )
            belowThresholdVelocities.append(
                try require06CBVelocity(in: app)
            )
        }
        require06CBVisualSelection(
            id: "p2",
            position: "3/5",
            page: .interactionPagerPageP2,
            in: app
        )

        for _ in 0..<5 {
            reset06CBPager(in: app)
            drag06CBPager(
                distance: 0.51,
                velocity: .slow,
                hold: 0.20,
                in: app
            )
            require06CBResolution(
                currentID: "p3",
                reason: "committed",
                visualID: "p3",
                traceProgress: 0.51,
                in: app
            )
            aboveThresholdVelocities.append(
                try require06CBVelocity(in: app)
            )
        }
        require06CBVisualSelection(
            id: "p3",
            position: "4/5",
            page: .interactionPagerPageP3,
            in: app
        )

        XCTAssertLessThan(
            belowThresholdVelocities.map(abs).max() ?? .infinity,
            0.50
        )
        XCTAssertLessThan(
            aboveThresholdVelocities.map(abs).max() ?? .infinity,
            0.50
        )
        XCTAssertLessThanOrEqual(
            abs(
                (belowThresholdVelocities.map(abs).max() ?? 0)
                    - (aboveThresholdVelocities.map(abs).max() ?? 0)
            ),
            0.25
        )

        try verify06CBVelocityBranch(in: app)
    }

    @MainActor
    func testPagerRapidBurstAndBoundaryKeepVisualSelectionAligned() {
        let app = launch06CBPagerLab()
        let viewport = UITestHarness.element(
            .interactionPagerAdjustable,
            in: app
        )
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        let settledSnapshotCount = UITestHarness.element(
            .interactionPagerSettledSnapshotCount,
            in: app
        )
        XCTAssertTrue(settledSnapshotCount.waitForExistence(timeout: 5))
        let initialP2Sequence = controllerSequence(for: "p2", in: app)

        for index in 0..<20 {
            if index.isMultiple(of: 2) {
                viewport.swipeLeft(velocity: .fast)
            } else {
                viewport.swipeRight(velocity: .fast)
            }
        }
        require06CBVisualSelection(
            id: "p2",
            position: "3/5",
            page: .interactionPagerPageP2,
            in: app
        )
        XCTAssertEqual(controllerSequence(for: "p2", in: app), initialP2Sequence)
        UITestHarness.requireLabel(
            .interactionPagerCompletion,
            equals: "Resolved: 20",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerInputCount,
            equals: "Inputs: 20",
            in: app
        )
        require06CBInputAudit(in: app)

        exercise06CBBoundaryBurst(
            expectation: PagerBoundaryExpectation(
                towardLeft: true,
                id: "p4",
                position: "5/5",
                page: .interactionPagerPageP4,
                resolvedCount: 22
            ),
            viewport: viewport,
            settledSnapshotCount: settledSnapshotCount,
            in: app
        )
        exercise06CBBoundaryBurst(
            expectation: PagerBoundaryExpectation(
                towardLeft: false,
                id: "p0",
                position: "1/5",
                page: .interactionPagerPageP0,
                resolvedCount: 24
            ),
            viewport: viewport,
            settledSnapshotCount: settledSnapshotCount,
            in: app
        )
        XCTAssertLessThanOrEqual(
            require06CBDimension(
                .interactionPagerSettledSnapshotCount,
                prefix: "Settled snapshots: ",
                in: app
            ),
            100
        )
    }

    @MainActor
    func testPagerRetainedStateMatrixKeepsGeometryIdentityAndHitTesting() {
        let app = launch06CBPagerLab()
        let baselineFrame = require06CBFullPageGeometry(in: app)
        let controllerLabel = UITestHarness.element(
            .interactionPagerPageP2ControllerSequence,
            in: app
        ).label

        exercise06CBRetainedStates(
            in: app,
            baselineFrame: baselineFrame,
            controllerLabel: controllerLabel
        )
        exercise06CBInitialStates(
            in: app,
            baselineFrame: baselineFrame,
            controllerLabel: controllerLabel
        )

        UITestHarness.tap(.interactionPagerStaleResponse, in: app)
        UITestHarness.requireLabel(
            .interactionPagerRefresh,
            equals: "State: refresh-failure",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerStaleRejections,
            equals: "Stale rejected: 1",
            in: app
        )
        XCTAssertEqual(
            UITestHarness.element(
                .interactionPagerPageP2ControllerSequence,
                in: app
            ).label,
            controllerLabel
        )
        require06CBPageFrame(baselineFrame, in: app)
    }

    @MainActor
    func testPagerPartialDragRetainedRefreshKeepsHostFiveTimes() {
        let app = launch06CBPagerLab()
        let baselineFrame = require06CBFullPageGeometry(in: app)
        let controllerLabel = UITestHarness.element(
            .interactionPagerPageP2ControllerSequence,
            in: app
        ).label

        for attempt in 1...5 {
            UITestHarness.tap(.interactionPagerArmRefresh, in: app)
            drag06CBPager(
                distance: 0.34,
                velocity: .slow,
                hold: 0.15,
                in: app
            )
            require06CBResolution(
                currentID: "p2",
                reason: "system-bailout",
                visualID: "p2",
                traceProgress: 0.34,
                in: app
            )
            UITestHarness.requireLabel(
                .interactionPagerRefresh,
                equals: "State: refreshing",
                in: app
            )
            let inFlight = UITestHarness.element(
                .interactionPagerInFlightRefresh,
                in: app
            )
            XCTAssertTrue(inFlight.waitForExistence(timeout: 5))
            XCTAssertTrue(
                inFlight.label.contains("In-flight: \(attempt), state refreshing"),
                "Unexpected in-flight projection: \(inFlight.label)"
            )
            XCTAssertTrue(
                inFlight.label.contains("committed p2, visible p2")
            )
            XCTAssertTrue(
                inFlight.label.contains("opaque 1"),
                "Interactive hosts must not expose a default background: "
                    + inFlight.label
            )
            XCTAssertTrue(
                inFlight.label.hasSuffix("callbacks 1"),
                "Unexpected callback depth: \(inFlight.label)"
            )
            XCTAssertEqual(
                UITestHarness.element(
                    .interactionPagerPageP2ControllerSequence,
                    in: app
                ).label,
                controllerLabel
            )
            require06CBPageFrame(baselineFrame, in: app)
            UITestHarness.tap(
                .interactionPagerPageP2ContentAction,
                in: app
            )
            UITestHarness.requireLabel(
                .interactionPagerPageP2ContentAction,
                equals: "Content hits: \(attempt)",
                in: app
            )
        }
    }
}

extension InteractionLabTests {
    @MainActor
    func launch06CBPagerLab() -> XCUIApplication {
        let app = UITestHarness.launch(scenario: .emptyShell)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(
            .debugOpenInteractionLab,
            in: app
        )
        UITestHarness.tap(.debugOpenInteractionLab, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )
        return app
    }

    @MainActor
    func reset06CBPager(in app: XCUIApplication) {
        UITestHarness.tap(.interactionPagerReset, in: app)
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: p2",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerInputResolution,
            equals: "Resolution: none",
            in: app
        )
    }

    @MainActor
    func drag06CBPager(
        distance: CGFloat,
        velocity: XCUIGestureVelocity,
        hold: TimeInterval,
        in app: XCUIApplication
    ) {
        let page = UITestHarness.element(.interactionPagerPageP2, in: app)
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        let startX: CGFloat = 0.78
        let runtimeTranslationScale: CGFloat = 0.94
        let coordinateDistance = distance / runtimeTranslationScale
        let start = page.coordinate(
            withNormalizedOffset: CGVector(dx: startX, dy: 0.5)
        )
        let end = page.coordinate(
            withNormalizedOffset: CGVector(
                dx: startX - coordinateDistance,
                dy: 0.5
            )
        )
        start.press(
            forDuration: 0.10,
            thenDragTo: end,
            withVelocity: velocity,
            thenHoldForDuration: hold
        )
    }

    @MainActor
    func require06CBResolution(
        currentID: String,
        reason: String,
        visualID: String,
        traceProgress: Double,
        in app: XCUIApplication
    ) {
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: \(currentID)",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerInputResolution,
            equals: "Resolution: \(reason), visual \(visualID)",
            in: app
        )
        let trace = UITestHarness.element(
            .interactionPagerInputTrace,
            in: app
        )
        XCTAssertTrue(trace.waitForExistence(timeout: 5))
        let measuredProgress = traceMetric(named: "end", in: trace.label)
        let measuredPeak = traceMetric(named: "peak", in: trace.label)
        let reversalCount = traceMetric(named: "reversals", in: trace.label)
        XCTAssertEqual(
            measuredProgress ?? .nan,
            traceProgress,
            accuracy: 0.015,
            "Unexpected runtime trace: \(trace.label)"
        )
        XCTAssertEqual(
            measuredPeak ?? .nan,
            traceProgress,
            accuracy: 0.025,
            "Unexpected runtime peak: \(trace.label)"
        )
        XCTAssertEqual(reversalCount, 0, "Unexpected direct-path reversal")
        XCTAssertTrue(trace.label.hasSuffix("ended"))
    }

    @MainActor
    func verify06CBVelocityBranch(in app: XCUIApplication) throws {
        reset06CBPager(in: app)
        drag06CBPager(
            distance: 0.18,
            velocity: .slow,
            hold: 0.20,
            in: app
        )
        require06CBResolution(
            currentID: "p2",
            reason: "system-bailout",
            visualID: "p2",
            traceProgress: 0.18,
            in: app
        )
        require06CBVisualSelection(
            id: "p2",
            position: "3/5",
            page: .interactionPagerPageP2,
            in: app
        )
        let slowVelocity = try require06CBVelocity(in: app)

        reset06CBPager(in: app)
        drag06CBPager(
            distance: 0.18,
            velocity: .fast,
            hold: 0,
            in: app
        )
        require06CBResolution(
            currentID: "p3",
            reason: "committed",
            visualID: "p3",
            traceProgress: 0.18,
            in: app
        )
        require06CBVisualSelection(
            id: "p3",
            position: "4/5",
            page: .interactionPagerPageP3,
            in: app
        )
        let fastVelocity = try require06CBVelocity(in: app)
        XCTAssertGreaterThan(abs(fastVelocity), abs(slowVelocity) + 0.25)
    }

    @MainActor
    func require06CBVelocity(in app: XCUIApplication) throws -> Double {
        let label = UITestHarness.element(
            .interactionPagerInputTrace,
            in: app
        ).label
        return try XCTUnwrap(traceMetric(named: "velocity", in: label))
    }

    func traceMetric(named name: String, in label: String) -> Double? {
        guard let marker = label.range(of: "\(name) ") else {
            return nil
        }
        let value = label[marker.upperBound...].split(separator: ",").first
        return value.flatMap { Double($0) }
    }

    @MainActor
    func require06CBVisualSelection(
        id: String,
        position: String,
        page: UITestElementID,
        in app: XCUIApplication
    ) {
        UITestHarness.requireLabel(
            .interactionCurrentPage,
            equals: "Current ID: \(id)",
            in: app
        )
        UITestHarness.requireLabel(
            .interactionPagerPosition,
            equals: "Position: \(position)",
            in: app
        )
        let pageElement = UITestHarness.element(page, in: app)
        XCTAssertTrue(pageElement.waitForExistence(timeout: 5))
        let viewportSize = require06CBViewportSize(in: app)
        XCTAssertEqual(
            pageElement.frame.width,
            viewportSize.width,
            accuracy: 1
        )
        XCTAssertEqual(
            pageElement.frame.height,
            viewportSize.height,
            accuracy: 1
        )
        let viewportFrame = UITestHarness.element(
            .interactionPagerAdjustable,
            in: app
        ).frame
        XCTAssertEqual(pageElement.frame.minX, viewportFrame.minX, accuracy: 1)
        XCTAssertEqual(pageElement.frame.minY, viewportFrame.minY, accuracy: 1)
        let sequence = controllerSequence(for: id, in: app)
        let settled = UITestHarness.element(
            .interactionPagerSettledProjection,
            in: app
        )
        XCTAssertTrue(settled.waitForExistence(timeout: 5))
        let expectedProjection = "Settled: committed \(id), visible \(id), "
            + "controller \(sequence), cached \(sequence), callbacks 0, "
            + "overlaps 0, sentinel 0"
        let predicate = NSPredicate(format: "label == %@", expectedProjection)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: settled
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            "Unexpected settled projection: \(settled.label)"
        )
        let geometry = UITestHarness.element(
            .interactionPagerGeometry,
            in: app
        )
        XCTAssertTrue(geometry.waitForExistence(timeout: 5))
        XCTAssertTrue(
            geometry.label.contains("Geometry: covered, opaque"),
            "Unexpected settled geometry: \(geometry.label)"
        )
    }

    @MainActor
    func require06CBFullPageGeometry(in app: XCUIApplication) -> CGRect {
        let page = UITestHarness.element(.interactionPagerPageP2, in: app)
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        let viewportSize = require06CBViewportSize(in: app)
        XCTAssertGreaterThan(page.frame.height, 44)
        XCTAssertEqual(page.frame.width, viewportSize.width, accuracy: 1)
        XCTAssertEqual(page.frame.height, viewportSize.height, accuracy: 1)
        return page.frame
    }

    @MainActor
    func require06CBViewportSize(in app: XCUIApplication) -> CGSize {
        let width = require06CBDimension(
            .interactionPagerViewportWidth,
            prefix: "Viewport width: ",
            in: app
        )
        let height = require06CBDimension(
            .interactionPagerViewportHeight,
            prefix: "Viewport height: ",
            in: app
        )
        return CGSize(width: width, height: height)
    }

    @MainActor
    func require06CBDimension(
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
    func require06CBPageFrame(
        _ baseline: CGRect,
        in app: XCUIApplication
    ) {
        let frame = UITestHarness.element(
            .interactionPagerPageP2,
            in: app
        ).frame
        XCTAssertEqual(frame.minX, baseline.minX, accuracy: 1)
        XCTAssertEqual(frame.minY, baseline.minY, accuracy: 1)
        XCTAssertEqual(frame.width, baseline.width, accuracy: 1)
        XCTAssertEqual(frame.height, baseline.height, accuracy: 1)
    }

}
