import XCTest

extension AppShellSmokeTests {
    @MainActor
    func testStage18ThreadImageAndMediaViewerExposeOneClearSemanticPath() {
        let app = UITestHarness.launch(
            scenario: .fixtureReadingFlow,
            displayProfile: .darkAccessibilityReduced
        )

        UITestHarness.scrollToHittable(
            .recommendationsSelectedRow,
            inside: .recommendationsList,
            in: app
        )
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        UITestHarness.scrollToHittable(
            .threadReaderImageSecondAction,
            inside: .threadReaderScreen,
            in: app
        )

        UITestHarness.requireLabel(
            .threadReaderImageSecondAction,
            equals: "Fixture 图片 2，第 2 张，共 3 张",
            in: app
        )
        UITestHarness.requireValue(
            .threadReaderImageSecondAction,
            equals: "已加载",
            in: app
        )
        UITestHarness.tap(.threadReaderImageSecondAction, in: app)

        UITestHarness.requirePresent(.mediaViewerPager, in: app)
        UITestHarness.requireLabel(
            .mediaViewerPager,
            equals: "图片查看器",
            in: app
        )
        assertValue(
            of: .mediaViewerPager,
            beginsWith: "2 / 3",
            in: app
        )
        UITestHarness.requireLabel(
            .mediaViewerClose,
            equals: "关闭图片查看器",
            in: app
        )
        UITestHarness.requireLabel(
            .mediaViewerPrevious,
            equals: "上一张图片",
            in: app
        )
        UITestHarness.requireLabel(
            .mediaViewerNext,
            equals: "下一张图片",
            in: app
        )

        XCTAssertFalse(
            app.descendants(matching: .any)["media-viewer.root"].exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["media-viewer.position"].exists
        )
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerPager, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
    }

    @MainActor
    private func assertValue(
        of identifier: UITestElementID,
        beginsWith expectedPrefix: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("Missing Stage 18 accessibility element", file: file, line: line)
            return
        }
        let value = element.value as? String
        XCTAssertTrue(
            value?.hasPrefix(expectedPrefix) == true,
            "Unexpected accessibility value: \(value ?? "<nil>")",
            file: file,
            line: line
        )
    }
}

extension LaunchSmokeTests {
    @MainActor
    func testStage18OfflineRecommendationsFailureRetriesWithoutLiveNetwork() {
        let app = UITestHarness.launch(scenario: .networkOffline)

        UITestHarness.requirePresent(.recommendationsFailure, in: app)
        UITestHarness.requirePresent(.componentFullPageErrorRetry, in: app)
        UITestHarness.tap(.componentFullPageErrorRetry, in: app)
        UITestHarness.requirePresent(.recommendationsList, in: app)
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
        UITestHarness.requireAbsent(.recommendationsFailure, in: app)
    }
}
