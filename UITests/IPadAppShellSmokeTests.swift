import XCTest

final class IPadAppShellSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRegularSplitRouteSurvivesOrientationAndRootSwitch() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft

        UITestHarness.requirePresent(.layoutRegular, in: app)
        pushForumRoute(in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)

        device.orientation = .portrait
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.recommendationsRoot, in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)

        device.orientation = .portrait
    }

    @MainActor
    func testCanonicalStateSurvivesRegularCompactRegularProjection() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        UITestHarness.requirePresent(.layoutRegular, in: app)
        pushForumRoute(in: app)

        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
    }

    @MainActor
    func testFixtureReadingFlowOpensAndClosesMediaOnIPad() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft

        UITestHarness.requirePresent(.layoutRegular, in: app)
        openFixtureThread(in: app)
        let recommendationFrame = UITestHarness.element(
            .recommendationsSelectedRow,
            in: app
        ).frame

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
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerRoot, in: app)

        let returnedImage = UITestHarness.element(
            .threadReaderImageSecondAction,
            in: app
        )
        XCTAssertTrue(returnedImage.waitForExistence(timeout: 5))
        XCTAssertTrue(returnedImage.isHittable)
        XCTAssertEqual(
            returnedImage.frame.midY,
            threadFrame.midY,
            accuracy: 8
        )
        let returnedRecommendation = UITestHarness.element(
            .recommendationsSelectedRow,
            in: app
        )
        XCTAssertTrue(returnedRecommendation.exists)
        XCTAssertTrue(returnedRecommendation.isHittable)
        XCTAssertEqual(
            returnedRecommendation.frame.midY,
            recommendationFrame.midY,
            accuracy: 12
        )

        device.orientation = .portrait
    }

    @MainActor
    func testFixtureForumThreadShowsSubpostsPaginationAndMediaOnIPad() {
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft

        pushForumRoute(in: app)
        UITestHarness.scrollToHittable(
            .forumHomeSelectedRow,
            inside: .forumHomeList,
            in: app
        )
        UITestHarness.tap(.forumHomeSelectedRow, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        UITestHarness.scrollToHittable(
            .forumThreadSubpost,
            inside: .forumThreadReaderScroll,
            in: app
        )
        UITestHarness.scrollToHittable(
            .forumThreadLastPagePost,
            inside: .forumThreadReaderScroll,
            in: app
        )
        UITestHarness.scrollBackToHittable(
            .forumThreadImageAction,
            inside: .forumThreadReaderScroll,
            in: app
        )
        UITestHarness.requireValue(
            .forumThreadImageAction,
            equals: "已加载",
            in: app
        )
        UITestHarness.tap(.forumThreadImageAction, in: app)
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        MediaViewerProductionAssertions.requirePosition("1 / 1", in: app)
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerRoot, in: app)

        device.orientation = .portrait
    }

    @MainActor
    func testThreadContentRendererLabSurvivesIPadProjectionAndRotation() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.scrollToHittable(
            .debugOpenThreadContentRenderer,
            in: app
        )
        UITestHarness.tap(.debugOpenThreadContentRenderer, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)
        UITestHarness.scrollToHittable(.threadContentImageSuccessAction, in: app)
        UITestHarness.requireValue(
            .threadContentImageSuccessAction,
            equals: "已加载",
            in: app
        )
        UITestHarness.requirePresent(
            .threadContentMediaIntent,
            in: app,
            expectedLabel: "Media intent: none"
        )

        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)
        UITestHarness.scrollToHittable(.threadContentImageLoadingState, in: app)
        UITestHarness.requireValue(
            .threadContentImageLoadingState,
            equals: "正在加载",
            in: app
        )
        UITestHarness.requireAbsent(.threadContentImageLoadingAction, in: app)

        UITestHarness.tap(.layoutControlRegular, in: app)
        device.orientation = .portrait
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.threadContentLabRoot, in: app)
        UITestHarness.requireValue(
            .threadContentImageLoadingState,
            equals: "正在加载",
            in: app
        )
        UITestHarness.scrollRendererToHittable(
            .threadContentImageFailureState,
            in: app
        )
        UITestHarness.requireValue(
            .threadContentImageFailureState,
            equals: "加载失败",
            in: app
        )
        UITestHarness.requireAbsent(.threadContentImageFailureAction, in: app)
        UITestHarness.scrollRendererToHittable(
            .threadContentImageDecodeFailureState,
            in: app
        )
        UITestHarness.requireValue(
            .threadContentImageDecodeFailureState,
            equals: "加载失败",
            in: app
        )
        UITestHarness.requireAbsent(
            .threadContentImageDecodeFailureAction,
            in: app
        )
        UITestHarness.requirePresent(
            .threadContentMediaIntent,
            in: app,
            expectedLabel: "Media intent: none"
        )
        UITestHarness.requirePresent(.threadContentUnknown, in: app)

        device.orientation = .portrait
    }

    @MainActor
    func testProductionMediaViewerPagesZoomRotationAndCloseOnIPad() {
        let app = UITestHarness.launch(
            scenario: .threadContentRenderer,
            displayProfile: .darkAccessibilityReduced
        )
        let device = XCUIDevice.shared
        device.orientation = .portrait
        MediaViewerProductionAssertions.openRendererLab(in: app)
        MediaViewerProductionAssertions.openMultiple(in: app)

        UITestHarness.tap(.mediaViewerNext, in: app)
        MediaViewerProductionAssertions.requirePosition("2 / 6", in: app)
        UITestHarness.tap(.mediaViewerNext, in: app)
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)
        let image = MediaViewerProductionAssertions.requireImage(at: 2, in: app)
        image.doubleTap()
        MediaViewerProductionAssertions.requireZoomed(image)
        image.swipeRight()
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)

        device.orientation = .landscapeLeft
        UITestHarness.requirePresent(.mediaViewerRoot, in: app)
        UITestHarness.requirePresent(.mediaViewerChrome, in: app)
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)
        _ = MediaViewerProductionAssertions.requireImage(at: 2, in: app)

        device.orientation = .portrait
        UITestHarness.requirePresent(.mediaViewerClose, in: app)
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)
        MediaViewerProductionAssertions.close(in: app)
        device.orientation = .portrait
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
    private func pushForumRoute(in app: XCUIApplication) {
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsRoot, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
    }
}
