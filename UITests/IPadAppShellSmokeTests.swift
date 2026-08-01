import XCTest

final class IPadAppShellSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRegularSplitRouteSurvivesOrientationAndRootSwitch() {
        let app = UITestHarness.launch(scenario: .emptyShell)
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft

        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.tap(.openForum, in: app)
        UITestHarness.requirePresent(.routeForum, in: app)
        UITestHarness.tap(.openThread, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        device.orientation = .portrait
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsRoot, in: app)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        device.orientation = .portrait
    }

    @MainActor
    func testCanonicalStateSurvivesRegularCompactRegularProjection() {
        let app = UITestHarness.launch(scenario: .emptyShell)

        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requireTabSelected(.recommendations, in: app)
        UITestHarness.tap(.openForum, in: app)
        UITestHarness.tap(.openThread, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        UITestHarness.tap(.layoutControlCompact, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requireTabSelected(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)

        UITestHarness.tapTab(.settings, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requireTabSelected(.settings, in: app)
        UITestHarness.requirePresent(.galleryRoot, in: app)

        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.requirePresent(.routeThread, in: app)
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
}
