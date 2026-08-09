import XCTest

final class AppShellSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testIndependentRootPathsAndCurrentTabReselection() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        UITestHarness.requireTabSelected(.recommendations, in: app)
        openFixtureThread(in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsRoot, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)

        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requireTabSelected(.recommendations, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
    }

    @MainActor
    func testSystemBackReturnsToThePreviousFixtureRoute() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        pushForumRoute(in: app)
        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .followedForumsFirstRow
        )
    }

    @MainActor
    func testSystemEdgeSwipeReturnsToThePreviousFixtureRoute() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        pushForumRoute(in: app)
        UITestHarness.swipeSystemBack(
            in: app,
            returningTo: .followedForumsFirstRow
        )
    }

    @MainActor
    func testComponentGalleryInDarkLargeTypeReducedMotionProfile() {
        let app = UITestHarness.launch(
            scenario: .emptyShell,
            displayProfile: .darkAccessibilityReduced
        )

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenGallery, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)
        UITestHarness.requirePresent(
            .galleryAppearance,
            in: app,
            expectedLabel: "Appearance: Dark"
        )
        UITestHarness.requirePresent(
            .galleryDynamicType,
            in: app,
            expectedLabel: "Dynamic Type: Accessibility"
        )
        UITestHarness.requirePresent(
            .galleryReduceMotion,
            in: app,
            expectedLabel: "Reduce Motion: On"
        )
        UITestHarness.attachSafeVisualEvidence(
            app: app,
            name: "Dark large type reduced motion gallery environment"
        )
        UITestHarness.scrollToHittable(.componentInitialLoading, in: app)
        UITestHarness.scrollToHittable(.componentInlineLoading, in: app)
        UITestHarness.scrollToHittable(.componentEmpty, in: app)
        UITestHarness.scrollToHittable(
            .componentFullPageErrorRetry,
            in: app
        )
        UITestHarness.requirePresent(.componentFullPageError, in: app)
        UITestHarness.tap(.componentFullPageErrorRetry, in: app)
        UITestHarness.scrollToHittable(
            .componentInlineErrorRetry,
            in: app
        )
        UITestHarness.requirePresent(.componentInlineError, in: app)
        UITestHarness.tap(.componentInlineErrorRetry, in: app)
        UITestHarness.scrollToHittable(.componentPagination, in: app)
        UITestHarness.attachSafeVisualEvidence(
            app: app,
            name: "Dark large type reduced motion component gallery"
        )
    }

    @MainActor
    func testThreadContentRendererLabUsesDomainFixturesAndStableIntents() {
        let app = UITestHarness.launch(
            scenario: .threadContentRenderer,
            displayProfile: .darkAccessibilityReduced
        )

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(
            .debugOpenThreadContentRenderer,
            in: app
        )
        UITestHarness.tap(.debugOpenThreadContentRenderer, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)
        requireThreadContentAccessibilityProfile(in: app)

        UITestHarness.scrollToHittable(.threadContentLink, in: app)
        UITestHarness.tap(.threadContentLink, in: app)
        UITestHarness.requireLabelNotEqual(
            .threadContentExternalIntent,
            to: "External intent: none",
            in: app
        )
        UITestHarness.requirePresent(
            .threadContentMediaIntent,
            in: app,
            expectedLabel: "Media intent: none"
        )

        let nonRenderedFrames = requireNonRenderedImageStates(in: app)

        UITestHarness.scrollBackToHittable(
            .threadContentImageSuccessAction,
            in: app
        )
        UITestHarness.requireValue(
            .threadContentImageSuccessAction,
            equals: "已加载",
            in: app
        )
        let successFrame = UITestHarness.element(
            .threadContentImageSuccessAction,
            in: app
        ).frame

        for frame in nonRenderedFrames {
            XCTAssertEqual(successFrame.width, frame.width, accuracy: 1)
            XCTAssertEqual(successFrame.height, frame.height, accuracy: 1)
        }

        UITestHarness.tap(.threadContentImageSuccessAction, in: app)
        UITestHarness.requireLabelNotEqual(
            .threadContentMediaIntent,
            to: "Media intent: none",
            in: app
        )
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        UITestHarness.requireLabel(
            .mediaViewerPosition,
            equals: "1 / 5",
            in: app
        )
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerRoot, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)

        UITestHarness.scrollToHittable(.threadContentUnknown, in: app)
        UITestHarness.requirePresent(.threadContentUnknown, in: app)
        UITestHarness.scrollToHittable(.threadContentAfterUnknown, in: app)
        UITestHarness.requirePresent(.threadContentAfterUnknown, in: app)
        UITestHarness.attachSafeVisualEvidence(
            app: app,
            name: "Thread content dark large type reduced motion fixture"
        )
    }

    @MainActor
    func testProductionMediaViewerSingleZoomPanAndFiveCloseCycles() {
        let app = UITestHarness.launch(
            scenario: .threadContentRenderer,
            displayProfile: .darkAccessibilityReduced
        )
        MediaViewerProductionAssertions.openRendererLab(in: app)

        for cycle in 0..<5 {
            MediaViewerProductionAssertions.openSingle(in: app)
            if cycle == 0 {
                let image = MediaViewerProductionAssertions.requireImage(
                    at: 0,
                    in: app
                )
                image.doubleTap()
                MediaViewerProductionAssertions.requireZoomed(image)
                image.doubleTap()
                MediaViewerProductionAssertions.requireOriginalSize(image)
                image.pinch(withScale: 2, velocity: 2)
                MediaViewerProductionAssertions.requireZoomed(image)
                let start = image.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)
                )
                let end = image.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)
                )
                start.press(forDuration: 0.1, thenDragTo: end)
                MediaViewerProductionAssertions.requirePosition(
                    "1 / 1",
                    in: app
                )
            }
            MediaViewerProductionAssertions.close(in: app)
        }
    }

    @MainActor
    func testProductionMediaViewerPagesResetsZoomAndCoversFailures() {
        let app = UITestHarness.launch(
            scenario: .threadContentRenderer,
            displayProfile: .darkAccessibilityReduced
        )
        MediaViewerProductionAssertions.openRendererLab(in: app)
        MediaViewerProductionAssertions.openMultiple(in: app)

        UITestHarness.element(.mediaViewerPager, in: app).swipeLeft()
        MediaViewerProductionAssertions.requirePosition("2 / 6", in: app)
        _ = MediaViewerProductionAssertions.requireImage(at: 1, in: app)
        UITestHarness.element(.mediaViewerPager, in: app).swipeLeft()
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)

        let third = MediaViewerProductionAssertions.requireImage(at: 2, in: app)
        third.pinch(withScale: 2, velocity: 2)
        MediaViewerProductionAssertions.requireZoomed(third)
        third.swipeLeft()
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)

        UITestHarness.tap(.mediaViewerPrevious, in: app)
        MediaViewerProductionAssertions.requirePosition("2 / 6", in: app)
        UITestHarness.tap(.mediaViewerNext, in: app)
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)
        let revisited = MediaViewerProductionAssertions.requireImage(
            at: 2,
            in: app
        )
        MediaViewerProductionAssertions.requireOriginalSize(revisited)

        revisited.tap()
        UITestHarness.waitUntilAbsent(.mediaViewerClose, in: app)
        revisited.swipeLeft()
        MediaViewerProductionAssertions.requireChromeVisible(in: app)
        MediaViewerProductionAssertions.requirePosition("4 / 6", in: app)
        let loading = MediaViewerProductionAssertions.requireState(
            at: 3,
            component: "loading",
            in: app
        )
        assertFullMediaCoverage(loading, in: app)

        UITestHarness.tap(.mediaViewerNext, in: app)
        MediaViewerProductionAssertions.requirePosition("5 / 6", in: app)
        let fetchFailure = MediaViewerProductionAssertions.requireState(
            at: 4,
            component: "fetch-failure",
            in: app
        )
        assertFullMediaCoverage(fetchFailure, in: app)

        UITestHarness.tap(.mediaViewerNext, in: app)
        MediaViewerProductionAssertions.requirePosition("6 / 6", in: app)
        let decodeFailure = MediaViewerProductionAssertions.requireState(
            at: 5,
            component: "decode-failure",
            in: app
        )
        assertFullMediaCoverage(decodeFailure, in: app)
        UITestHarness.attachSafeVisualEvidence(
            app: app,
            name: "Production MediaViewer opaque decode failure"
        )
        MediaViewerProductionAssertions.close(in: app)
    }

    @MainActor
    private func requireThreadContentAccessibilityProfile(
        in app: XCUIApplication
    ) {
        UITestHarness.requirePresent(
            .threadContentLabAppearance,
            in: app,
            expectedLabel: "Appearance: Dark"
        )
        UITestHarness.requirePresent(
            .threadContentLabDynamicType,
            in: app,
            expectedLabel: "Dynamic Type: Accessibility"
        )
        UITestHarness.requirePresent(
            .threadContentLabReduceMotion,
            in: app,
            expectedLabel: "Reduce Motion: On"
        )
    }

    @MainActor
    private func assertFullMediaCoverage(
        _ state: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pager = UITestHarness.element(.mediaViewerPager, in: app)
        XCTAssertEqual(state.frame.minX, pager.frame.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(state.frame.minY, pager.frame.minY, accuracy: 1, file: file, line: line)
        XCTAssertEqual(state.frame.width, pager.frame.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(state.frame.height, pager.frame.height, accuracy: 1, file: file, line: line)
    }

    @MainActor
    private func requireNonRenderedImageStates(
        in app: XCUIApplication
    ) -> [CGRect] {
        [
            requireNonRenderedImageState(
                state: .threadContentImageLoadingState,
                action: .threadContentImageLoadingAction,
                label: "合成图片",
                value: "正在加载",
                in: app
            ),
            requireNonRenderedImageState(
                state: .threadContentImageFailureState,
                action: .threadContentImageFailureAction,
                label: "合成图片",
                value: "加载失败",
                in: app
            ),
            requireNonRenderedImageState(
                state: .threadContentImageDecodeFailureState,
                action: .threadContentImageDecodeFailureAction,
                label: "不可解码图片",
                value: "加载失败",
                in: app
            )
        ]
    }

    @MainActor
    private func requireNonRenderedImageState(
        state: UITestElementID,
        action: UITestElementID,
        label: String,
        value: String,
        in app: XCUIApplication
    ) -> CGRect {
        UITestHarness.scrollToHittable(state, in: app)
        UITestHarness.requirePresent(
            state,
            in: app,
            expectedLabel: label
        )
        UITestHarness.requireValue(state, equals: value, in: app)
        UITestHarness.requireAbsent(action, in: app)
        UITestHarness.requirePresent(
            .threadContentMediaIntent,
            in: app,
            expectedLabel: "Media intent: none"
        )
        return UITestHarness.element(state, in: app).frame
    }

}

extension AppShellSmokeTests {
    @MainActor
    func testFixtureRecommendationsLoadThreePagesAndPreservePosition() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        UITestHarness.scrollToHittable(
            .recommendationsLastPageRow,
            inside: .recommendationsList,
            gestureAnchor: .recommendationsSelectedRow,
            in: app
        )
        let before = UITestHarness.element(
            .recommendationsLastPageRow,
            in: app
        ).frame
        UITestHarness.tap(.recommendationsLastPageRow, in: app)
        UITestHarness.requirePresent(
            .recommendationsLastPageThreadScreen,
            in: app
        )
        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .recommendationsLastPageRow
        )

        let returned = UITestHarness.element(
            .recommendationsLastPageRow,
            in: app
        )
        XCTAssertTrue(returned.isHittable)
        XCTAssertEqual(returned.frame.midY, before.midY, accuracy: 12)
    }

    @MainActor
    func testDebugSettingsPathSurvivesTabSwitch() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.scrollToHittable(.debugOpenGallery, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)
    }

    @MainActor
    func testFollowedForumsSignedOutShowsLoginPrompt() {
        let app = UITestHarness.launch(scenario: .sessionSignedOut)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsSignedOut, in: app)
        UITestHarness.requirePresent(.followedForumsLogin, in: app)
        UITestHarness.requireAbsent(.followedForumsFirstRow, in: app)
    }

    @MainActor
    private func pushForumRoute(in app: XCUIApplication) {
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsRoot, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
    }

    @MainActor
    private func openFixtureThread(in app: XCUIApplication) {
        UITestHarness.requirePresent(.recommendationsRoot, in: app)
        UITestHarness.scrollToHittable(
            .recommendationsSelectedRow,
            inside: .recommendationsList,
            in: app
        )
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
    }

    @MainActor
    func testFixtureReadingFlowPreservesThreadAndRecommendationPositions() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        UITestHarness.scrollToHittable(
            .recommendationsSelectedRow,
            inside: .recommendationsList,
            in: app
        )
        let recommendationFrame = UITestHarness.element(
            .recommendationsSelectedRow,
            in: app
        ).frame
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)

        UITestHarness.scrollToHittable(
            .threadReaderImageSecondAction,
            inside: .threadReaderScreen,
            in: app
        )
        UITestHarness.requireValue(
            .threadReaderImageSecondAction,
            equals: "已加载",
            in: app
        )
        let threadFrame = UITestHarness.element(
            .threadReaderImageSecondAction,
            in: app
        ).frame

        UITestHarness.tap(.threadReaderImageSecondAction, in: app)
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        MediaViewerProductionAssertions.requirePosition("2 / 3", in: app)
        UITestHarness.tap(.mediaViewerNext, in: app)
        MediaViewerProductionAssertions.requirePosition("3 / 3", in: app)
        UITestHarness.tap(.mediaViewerPrevious, in: app)
        MediaViewerProductionAssertions.requirePosition("2 / 3", in: app)
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerRoot, in: app)

        let returnedThreadImage = UITestHarness.element(
            .threadReaderImageSecondAction,
            in: app
        )
        XCTAssertTrue(returnedThreadImage.waitForExistence(timeout: 5))
        XCTAssertTrue(returnedThreadImage.isHittable)
        XCTAssertEqual(
            returnedThreadImage.frame.midY,
            threadFrame.midY,
            accuracy: 8
        )

        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .recommendationsRoot
        )
        let returnedRecommendation = UITestHarness.element(
            .recommendationsSelectedRow,
            in: app
        )
        XCTAssertTrue(returnedRecommendation.waitForExistence(timeout: 5))
        XCTAssertTrue(returnedRecommendation.isHittable)
        XCTAssertEqual(
            returnedRecommendation.frame.midY,
            recommendationFrame.midY,
            accuracy: 12
        )
    }
}
