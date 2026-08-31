import XCTest

extension AppShellSmokeTests {
    @MainActor
    func testStage17IPhoneRotationKeepsForumThreadAndReturnAnchor() {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        openStage17ForumThread(in: app)
        UITestHarness.scrollToHittable(
            .forumThreadLastPagePost,
            inside: .forumThreadReaderScroll,
            in: app
        )

        device.orientation = .landscapeLeft
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        UITestHarness.requirePresent(.forumThreadLastPagePost, in: app)
        device.orientation = .portrait
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        UITestHarness.requirePresent(.forumThreadLastPagePost, in: app)

        Stage17UITestSupport.tapDetailBack(
            in: app,
            returningTo: .forumHomeSelectedRow
        )
    }

    @MainActor
    private func openStage17ForumThread(in app: XCUIApplication) {
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.scrollToHittable(
            .forumHomeSelectedRow,
            inside: .forumHomeList,
            in: app
        )
        UITestHarness.tap(.forumHomeSelectedRow, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
    }
}

extension IPadAppShellSmokeTests {
    @MainActor
    func testStage17ForumThreadSurvivesFullNarrowFullResize() {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture)

        Stage17UITestSupport.require(.viewportFull, in: app)
        openStage17ForumThread(in: app)
        UITestHarness.scrollToHittable(
            .forumThreadLastPagePost,
            inside: .forumThreadReaderScroll,
            in: app
        )
        let fullWidth = UITestHarness.element(
            .forumThreadReaderScroll,
            in: app
        ).frame.width

        Stage17UITestSupport.tap(.controlNarrow, in: app)
        Stage17UITestSupport.require(.viewportNarrow, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        UITestHarness.requirePresent(.forumThreadLastPagePost, in: app)
        let narrowWidth = UITestHarness.element(
            .forumThreadReaderScroll,
            in: app
        ).frame.width
        XCTAssertLessThan(narrowWidth, fullWidth)

        UITestHarness.tap(.layoutControlRegular, in: app)
        Stage17UITestSupport.require(.viewportFull, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
        UITestHarness.requirePresent(.forumThreadLastPagePost, in: app)
        Stage17UITestSupport.tapDetailBack(
            in: app,
            returningTo: .forumHomeSelectedRow
        )
    }

    @MainActor
    func testStage17SettingsRouteSurvivesNarrowProjection() {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        UITestHarness.tapTab(.settings, in: app)
        let openHistory = Stage16BUITestSupport.scrollToHittable(
            Stage16BUITestID.openHistory,
            inside: UITestElementID.settingsRoot.rawValue,
            in: app
        )
        openHistory.tap()
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.historyScreen,
            in: app
        )

        Stage17UITestSupport.tap(.controlNarrow, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.historyScreen,
            in: app
        )
        UITestHarness.requireTabSelected(.settings, in: app)

        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.historyScreen,
            in: app
        )
        UITestHarness.requireTabSelected(.settings, in: app)
    }

    @MainActor
    func testStage17MediaRotationClosesToTheSameNarrowThread() {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        Stage17UITestSupport.tap(.controlNarrow, in: app)
        UITestHarness.requirePresent(.layoutCompact, in: app)
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
        UITestHarness.requireValue(
            .threadReaderImageSecondAction,
            equals: "已加载",
            in: app
        )
        UITestHarness.tap(.threadReaderImageSecondAction, in: app)
        UITestHarness.requirePresent(.mediaViewerPager, in: app)
        MediaViewerProductionAssertions.requirePosition("2 / 3", in: app)

        device.orientation = .portrait
        UITestHarness.requirePresent(.mediaViewerChrome, in: app)
        MediaViewerProductionAssertions.requirePosition("2 / 3", in: app)
        UITestHarness.tap(.mediaViewerClose, in: app)
        UITestHarness.waitUntilAbsent(.mediaViewerPager, in: app)

        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        UITestHarness.requirePresent(.threadReaderImageSecondAction, in: app)
        UITestHarness.tap(.layoutControlRegular, in: app)
        UITestHarness.requirePresent(.layoutRegular, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
    }

    @MainActor
    private func openStage17ForumThread(in app: XCUIApplication) {
        UITestHarness.tapTab(.followedForums, in: app)
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.scrollToHittable(
            .forumHomeSelectedRow,
            inside: .forumHomeList,
            in: app
        )
        UITestHarness.tap(.forumHomeSelectedRow, in: app)
        UITestHarness.requirePresent(.forumThreadReaderScreen, in: app)
    }
}

private enum Stage17UITestID: String {
    case controlNarrow = "app.harness.layout.narrow"
    case viewportFull = "app.harness.viewport.full"
    case viewportNarrow = "app.harness.viewport.narrow"
}

@MainActor
private enum Stage17UITestSupport {
    static func tap(
        _ identifier: Stage17UITestID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5), element.isHittable else {
            XCTFail(
                "Missing Stage 17 control: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
        element.tap()
    }

    static func require(
        _ identifier: Stage17UITestID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        XCTAssertTrue(
            element.waitForExistence(timeout: 5),
            "Missing Stage 17 marker: \(identifier.rawValue)",
            file: file,
            line: line
        )
    }

    static func tapDetailBack(
        in app: XCUIApplication,
        returningTo identifier: UITestElementID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let backButton = app.buttons["BackButton"]
        guard backButton.waitForExistence(timeout: 5), backButton.isHittable else {
            XCTFail("System detail back is unavailable", file: file, line: line)
            return
        }
        backButton.tap()
        UITestHarness.requirePresent(
            identifier,
            in: app,
            file: file,
            line: line
        )
    }
}
