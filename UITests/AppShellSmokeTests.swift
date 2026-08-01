import XCTest

final class AppShellSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testIndependentRootPathsAndCurrentTabReselection() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        UITestHarness.requireTabSelected(.recommendations, in: app)
        pushForumAndThread(in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsRoot, in: app)
        UITestHarness.tap(.openForum, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)

        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requireTabSelected(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
    }

    @MainActor
    func testSystemBackReturnsToThePreviousFixtureRoute() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        pushForumAndThread(in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .routeForum)
    }

    @MainActor
    func testSystemEdgeSwipeReturnsToThePreviousFixtureRoute() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        pushForumAndThread(in: app)
        UITestHarness.swipeSystemBack(in: app, returningTo: .routeForum)
    }

    @MainActor
    func testDebugSettingsPathSurvivesTabSwitch() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)
    }

    @MainActor
    func testComponentGalleryInDarkLargeTypeReducedMotionProfile() {
        let app = UITestHarness.launch(
            scenario: .emptyShell,
            displayProfile: .darkAccessibilityReduced
        )

        UITestHarness.tapTab(.settings, in: app)
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

        UITestHarness.scrollToHittable(.threadContentImageSuccessAction, in: app)
        UITestHarness.requireValue(
            .threadContentImageSuccessAction,
            equals: "已加载",
            in: app
        )
        let successFrame = UITestHarness.element(
            .threadContentImageSuccessAction,
            in: app
        ).frame
        UITestHarness.tap(.threadContentImageSuccessAction, in: app)
        UITestHarness.requireLabelNotEqual(
            .threadContentMediaIntent,
            to: "Media intent: none",
            in: app
        )
        UITestHarness.requireAbsent(.interactionMediaViewer, in: app)

        UITestHarness.scrollToHittable(.threadContentImageLoadingAction, in: app)
        UITestHarness.requireValue(
            .threadContentImageLoadingAction,
            equals: "正在加载",
            in: app
        )
        let loadingFrame = UITestHarness.element(
            .threadContentImageLoadingAction,
            in: app
        ).frame

        UITestHarness.scrollToHittable(.threadContentImageFailureAction, in: app)
        UITestHarness.requireValue(
            .threadContentImageFailureAction,
            equals: "加载失败",
            in: app
        )
        let failureFrame = UITestHarness.element(
            .threadContentImageFailureAction,
            in: app
        ).frame

        XCTAssertEqual(successFrame.width, loadingFrame.width, accuracy: 1)
        XCTAssertEqual(successFrame.height, loadingFrame.height, accuracy: 1)
        XCTAssertEqual(successFrame.width, failureFrame.width, accuracy: 1)
        XCTAssertEqual(successFrame.height, failureFrame.height, accuracy: 1)

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
    private func pushForumAndThread(in app: XCUIApplication) {
        UITestHarness.requirePresent(.recommendationsRoot, in: app)
        UITestHarness.tap(.openForum, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.tap(.openThread, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)
    }
}
