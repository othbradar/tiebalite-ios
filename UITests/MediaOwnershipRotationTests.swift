import XCTest

extension InteractionLabTests {
    @MainActor
    func testMediaFixedOwnersAndTenZoomPanRotationCycles() throws {
        let app = launchMediaOwnershipLab()
        let device = XCUIDevice.shared
        device.orientation = .portrait
        UITestHarness.tap(.interactionMediaOpenMultiple, in: app)
        let zoomSurface = mediaZoomSurface(in: app)
        _ = try MediaInteractionAssertions.stableLayout(in: app)
        try exerciseTenPagerRoundTrips(in: app, zoomSurface: zoomSurface)
        try exerciseTenMediaPans(in: app, zoomSurface: zoomSurface)
        try exerciseTenRotationCycles(in: app, device: device)
        UITestHarness.tap(.interactionMediaClose, in: app)
        requireViewerClosed(in: app)
        device.orientation = .portrait
    }

    @MainActor
    func testMediaDarkAccessibilityTypeAndReduceMotionMatrix() throws {
        let app = launchMediaOwnershipLab(
            displayProfile: .darkAccessibilityMaximumReduced
        )
        let device = XCUIDevice.shared
        device.orientation = .portrait
        UITestHarness.tap(.interactionMediaOpenMultiple, in: app)
        let zoomSurface = mediaZoomSurface(in: app)
        requireViewerValue("appearance=dark", in: app)
        requireViewerValue("dynamicType=accessibility5", in: app)
        requireViewerValue("reduceMotion=true", in: app)
        _ = try MediaInteractionAssertions.stableLayout(
            in: app,
            context: "initial"
        )
        try exerciseProfilePagerRoundTrip(
            in: app,
            zoomSurface: zoomSurface
        )
        _ = try MediaInteractionAssertions.stableLayout(
            in: app,
            context: "after-pager"
        )
        try exerciseProfileZoomPanRotation(
            in: app,
            zoomSurface: zoomSurface,
            device: device
        )
        UITestHarness.tap(.interactionMediaClose, in: app)
        requireViewerClosed(in: app)
    }

    @MainActor
    private func exerciseProfileZoomPanRotation(
        in app: XCUIApplication,
        zoomSurface: XCUIElement,
        device: XCUIDevice
    ) throws {
        zoomSurface.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        UITestHarness.requireLabel(
            .interactionMediaZoom,
            equals: "Zoom: 2.50",
            in: app
        )
        let expectedZoomScale = try MediaInteractionAssertions.zoomScale(
            in: app
        )
        let previous = try MediaInteractionAssertions.sessionSnapshot(in: app)
        panInsideZoomSurface(zoomSurface, towardLeft: true)
        _ = try MediaInteractionAssertions.requireSessionAdvance(
            in: app,
            after: previous,
            owner: "media-pan",
            mediaID: "large",
            requireMediaPanCounters: true
        )
        var layout = try MediaInteractionAssertions.stableLayout(
            in: app,
            context: "after-media-pan"
        )
        let expectedFocalPoint = layout.retainedFocalPoint
        MediaFocalAssertions.requireNonCenteredRetainedFocalPoint(
            layout,
            context: "profile-before-rotation"
        )
        try requireMediaRotationInvariant(
            in: app,
            expectedZoomScale: expectedZoomScale
        )
        device.orientation = .landscapeRight
        layout = try MediaInteractionAssertions.requireLayoutTransition(
            in: app,
            after: layout,
            landscape: true
        )
        MediaFocalAssertions.requireFocalPointPreserved(
            in: layout,
            expectedRetained: expectedFocalPoint,
            context: "profile-landscape"
        )
        try requireMediaRotationInvariant(
            in: app,
            expectedZoomScale: expectedZoomScale
        )
        device.orientation = .portrait
        layout = try MediaInteractionAssertions.requireLayoutTransition(
            in: app,
            after: layout,
            landscape: false
        )
        MediaFocalAssertions.requireFocalPointPreserved(
            in: layout,
            expectedRetained: expectedFocalPoint,
            context: "profile-portrait"
        )
        try requireMediaRotationInvariant(
            in: app,
            expectedZoomScale: expectedZoomScale
        )
    }

    @MainActor
    private func exerciseProfilePagerRoundTrip(
        in app: XCUIApplication,
        zoomSurface: XCUIElement
    ) throws {
        var pagerSession = try MediaInteractionAssertions.sessionSnapshot(
            in: app
        )
        zoomSurface.swipeLeft()
        pagerSession = try MediaInteractionAssertions.requireSessionAdvance(
            in: app,
            after: pagerSession,
            owner: "pager",
            mediaID: "large",
            requireMediaPanCounters: false
        )
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: delayed",
            in: app
        )
        swipePagerRight(in: app)
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )
        _ = try MediaInteractionAssertions.requireSessionAdvance(
            in: app,
            after: pagerSession,
            owner: "pager",
            mediaID: "delayed",
            requireMediaPanCounters: false
        )
    }

    @MainActor
    private func launchMediaOwnershipLab(
        displayProfile: UITestDisplayProfile = .system
    ) -> XCUIApplication {
        let app = UITestHarness.launch(
            scenario: .emptyShell,
            displayProfile: displayProfile
        )
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenInteractionLab, in: app)
        UITestHarness.tap(.debugOpenInteractionLab, in: app)
        UITestHarness.requirePresent(.interactionLabTitle, in: app)
        UITestHarness.tap(.interactionSectionMedia, in: app)
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
        return app
    }

    @MainActor
    private func mediaZoomSurface(in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any)[
            "interaction.media.zoom-surface.large"
        ]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        return element
    }

    @MainActor
    private func exerciseTenPagerRoundTrips(
        in app: XCUIApplication,
        zoomSurface: XCUIElement
    ) throws {
        var session = try MediaInteractionAssertions.sessionSnapshot(in: app)
        for _ in 0..<10 {
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
            requirePosition("Position: 3/4", in: app)
            session = try MediaInteractionAssertions.requireSessionAdvance(
                in: app,
                after: session,
                owner: "pager",
                mediaID: "large",
                requireMediaPanCounters: false
            )

            swipePagerRight(in: app)
            UITestHarness.requireLabel(
                .interactionMediaCurrent,
                equals: "Current: large",
                in: app
            )
            requirePosition("Position: 2/4", in: app)
            session = try MediaInteractionAssertions.requireSessionAdvance(
                in: app,
                after: session,
                owner: "pager",
                mediaID: "delayed",
                requireMediaPanCounters: false
            )
        }
        XCTAssertGreaterThan(session.sessionID, 0)
    }

    @MainActor
    private func exerciseTenMediaPans(
        in app: XCUIApplication,
        zoomSurface: XCUIElement
    ) throws {
        zoomSurface.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        UITestHarness.requireLabel(
            .interactionMediaZoom,
            equals: "Zoom: 2.50",
            in: app
        )
        let singleTapCount = try MediaInteractionAssertions.integerMetric(
            named: "single",
            from: .interactionMediaZoom,
            in: app
        )

        for cycle in 0..<10 {
            let previous = try MediaInteractionAssertions.sessionSnapshot(in: app)
            let towardLeft = cycle == 9 || cycle.isMultiple(of: 2)
            panInsideZoomSurface(zoomSurface, towardLeft: towardLeft)
            _ = try MediaInteractionAssertions.requireSessionAdvance(
                in: app,
                after: previous,
                owner: "media-pan",
                mediaID: "large",
                requireMediaPanCounters: true
            )
            UITestHarness.requireLabel(
                .interactionMediaCurrent,
                equals: "Current: large",
                in: app
            )
            requirePosition("Position: 2/4", in: app)
            UITestHarness.requirePresent(.interactionMediaChrome, in: app)
            XCTAssertEqual(
                try MediaInteractionAssertions.integerMetric(
                    named: "single",
                    from: .interactionMediaZoom,
                    in: app
                ),
                singleTapCount
            )
        }
    }

    @MainActor
    private func exerciseTenRotationCycles(
        in app: XCUIApplication,
        device: XCUIDevice
    ) throws {
        var layout = try MediaInteractionAssertions.stableLayout(in: app)
        let expectedZoomScale = try MediaInteractionAssertions.zoomScale(
            in: app
        )
        let expectedFocalPoint = layout.retainedFocalPoint
        MediaFocalAssertions.requireNonCenteredRetainedFocalPoint(
            layout,
            context: "stress-before-rotation"
        )
        XCTAssertGreaterThan(layout.coordinatorSequence, 0)
        attachScreenshot(app, name: "phase06ca-before-ten-rotation-cycles")
        for _ in 0..<10 {
            device.orientation = .landscapeLeft
            layout = try MediaInteractionAssertions.requireLayoutTransition(
                in: app,
                after: layout,
                landscape: true
            )
            MediaFocalAssertions.requireFocalPointPreserved(
                in: layout,
                expectedRetained: expectedFocalPoint,
                context: "stress-landscape"
            )
            try requireMediaRotationInvariant(
                in: app,
                expectedZoomScale: expectedZoomScale
            )
            device.orientation = .portrait
            layout = try MediaInteractionAssertions.requireLayoutTransition(
                in: app,
                after: layout,
                landscape: false
            )
            MediaFocalAssertions.requireFocalPointPreserved(
                in: layout,
                expectedRetained: expectedFocalPoint,
                context: "stress-portrait"
            )
            try requireMediaRotationInvariant(
                in: app,
                expectedZoomScale: expectedZoomScale
            )
        }
        attachScreenshot(app, name: "phase06ca-after-ten-rotation-cycles")
    }

    @MainActor
    private func panInsideZoomSurface(
        _ surface: XCUIElement,
        towardLeft: Bool
    ) {
        let startX = towardLeft ? 0.58 : 0.42
        let endX = towardLeft ? 0.42 : 0.58
        let start = surface.coordinate(
            withNormalizedOffset: CGVector(dx: startX, dy: 0.52)
        )
        let end = surface.coordinate(
            withNormalizedOffset: CGVector(dx: endX, dy: 0.52)
        )
        start.press(
            forDuration: 0.1,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0.05
        )
    }

    @MainActor
    private func swipePagerRight(in app: XCUIApplication) {
        let start = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.25, dy: 0.6)
        )
        let end = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6)
        )
        start.press(
            forDuration: 0.1,
            thenDragTo: end,
            withVelocity: .fast,
            thenHoldForDuration: 0.05
        )
    }

    @MainActor
    private func requireViewerClosed(in app: XCUIApplication) {
        UITestHarness.requireLabel(
            .interactionMediaOverlayState,
            equals: "Overlay: absent",
            in: app
        )
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
    }

    @MainActor
    private func requireMediaRotationInvariant(
        in app: XCUIApplication,
        expectedZoomScale: Double
    ) throws {
        UITestHarness.requireLabel(
            .interactionMediaCurrent,
            equals: "Current: large",
            in: app
        )
        XCTAssertEqual(
            try MediaInteractionAssertions.zoomScale(in: app),
            expectedZoomScale,
            accuracy: 0.01
        )
        UITestHarness.requireLabel(
            .interactionMediaOwner,
            equals: "Owner: media-pan",
            in: app
        )
        requirePosition("Position: 2/4", in: app)
        MediaInteractionAssertions.requireChromeControlsInsideChrome(in: app)
    }

    @MainActor
    private func requirePosition(_ label: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)[
            "interaction.media.position"
        ]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertEqual(element.label, label)
    }

    @MainActor
    private func requireViewerValue(_ fragment: String, in app: XCUIApplication) {
        let viewer = UITestHarness.element(.interactionMediaViewer, in: app)
        XCTAssertTrue(viewer.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value CONTAINS %@", fragment)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: viewer
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        let actualValue = viewer.value as? String ?? "nil"
        XCTAssertEqual(
            result,
            .completed,
            "Expected \(fragment), actual: \(actualValue)"
        )
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
