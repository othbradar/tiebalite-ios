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
    func testMediaZoomPagingRotationAndCloseOnIPad() throws {
        let app = UITestHarness.launch(scenario: .emptyShell)
        let device = XCUIDevice.shared
        device.orientation = .portrait

        let zoomSurface = openZoomedMedia(in: app)
        let expectedZoomScale = try MediaInteractionAssertions.zoomScale(
            in: app
        )

        try exerciseFiveMediaPanRotationCycles(
            in: app,
            zoomSurface: zoomSurface,
            device: device,
            expectedZoomScale: expectedZoomScale
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
        UITestHarness.requirePresent(.interactionMediaSource, in: app)
        device.orientation = .portrait
    }

    @MainActor
    private func exerciseFiveMediaPanRotationCycles(
        in app: XCUIApplication,
        zoomSurface: XCUIElement,
        device: XCUIDevice,
        expectedZoomScale: Double
    ) throws {
        var session = try MediaInteractionAssertions.sessionSnapshot(in: app)
        var layout = try MediaInteractionAssertions.stableLayout(in: app)
        for cycle in 0..<5 {
            pan(
                zoomSurface,
                towardLeft: cycle.isMultiple(of: 2)
            )
            session = try MediaInteractionAssertions.requireSessionAdvance(
                in: app,
                after: session,
                owner: "media-pan",
                mediaID: "large",
                requireMediaPanCounters: true
            )
            let focalLayout = try MediaInteractionAssertions.stableLayout(
                in: app,
                context: "ipad-before-rotation-\(cycle)"
            )
            layout = focalLayout
            let expectedFocalPoint = focalLayout.retainedFocalPoint
            if cycle == 0 {
                MediaFocalAssertions
                    .requireNonCenteredRetainedFocalPoint(
                        focalLayout,
                        context: "ipad-first-rotation"
                    )
            }
            try requireMediaRotationInvariant(
                in: app,
                expectedZoomScale: expectedZoomScale
            )
            device.orientation = .landscapeLeft
            layout = try MediaInteractionAssertions.requireLayoutTransition(
                in: app,
                after: layout,
                landscape: true
            )
            MediaFocalAssertions.requireFocalPointPreserved(
                in: layout,
                expectedRetained: expectedFocalPoint,
                context: "ipad-landscape-\(cycle)"
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
                context: "ipad-portrait-\(cycle)"
            )
            try requireMediaRotationInvariant(
                in: app,
                expectedZoomScale: expectedZoomScale
            )
        }
    }

    @MainActor
    private func openZoomedMedia(in app: XCUIApplication) -> XCUIElement {
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
        UITestHarness.requireLabel(
            .interactionMediaZoom,
            equals: "Zoom: 2.50",
            in: app
        )
        return zoomSurface
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
        UITestHarness.requirePresent(.interactionMediaChrome, in: app)
        MediaInteractionAssertions.requireChromeControlsInsideChrome(in: app)
    }

    @MainActor
    private func pan(
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
    private func requirePosition(_ label: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)[
            "interaction.media.position"
        ]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertEqual(element.label, label)
    }
}
