import XCTest

extension AppShellSmokeTests {
    @MainActor
    func testStage16BHistoryReopensAndClearsAReadThread() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        openStage16BFixtureThread(in: app)
        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .recommendationsSelectedRow
        )
        UITestHarness.tapTab(.settings, in: app)
        scrollSettingsTo(Stage16BUITestID.openHistory, in: app).tap()
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.historyScreen,
            in: app
        )
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.threadHistoryRow,
            in: app
        )

        Stage16BUITestSupport.tap(
            Stage16BUITestID.threadHistoryRow,
            in: app
        )
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        Stage16BUITestSupport.tapSystemBack(
            returningTo: Stage16BUITestID.historyScreen,
            in: app
        )
        UITestHarness.tapSystemBack(in: app, returningTo: .settingsRoot)

        scrollSettingsTo(Stage16BUITestID.settingsClearHistory, in: app).tap()
        let destructive = app.alerts.buttons["清空"]
        XCTAssertTrue(destructive.waitForExistence(timeout: 5))
        destructive.tap()
        scrollSettingsTo(
            Stage16BUITestID.openHistory,
            direction: .down,
            in: app
        ).tap()
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.historyScreen,
            in: app
        )
        Stage16BUITestSupport.requireAbsent(
            Stage16BUITestID.threadHistoryRow,
            in: app
        )
        Stage16BUITestSupport.requireAbsent(
            Stage16BUITestID.historyClear,
            in: app
        )
    }

    @MainActor
    func testStage16BSettingsApplyDarkThemeAndReadingSize() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        openStage16BFixtureThread(in: app)
        let standardText = Stage16BUITestSupport.scrollToHittable(
            Stage16BUITestID.threadFirstText,
            inside: UITestElementID.threadReaderScroll.rawValue,
            in: app
        )
        let standardHeight = standardText.frame.height
        UITestHarness.tapSystemBack(
            in: app,
            returningTo: .recommendationsSelectedRow
        )

        UITestHarness.tapTab(.settings, in: app)
        Stage16BUITestSupport.selectSegment(
            "深色",
            pickerIdentifier: Stage16BUITestID.appearancePicker,
            in: app
        )
        Stage16BUITestSupport.selectSegment(
            "大",
            pickerIdentifier: Stage16BUITestID.readingSizePicker,
            in: app
        )
        UITestHarness.scrollToHittable(.debugOpenGallery, in: app)
        UITestHarness.tap(.debugOpenGallery, in: app)
        UITestHarness.requirePresent(
            .galleryAppearance,
            in: app,
            expectedLabel: "Appearance: Dark"
        )
        UITestHarness.tapSystemBack(in: app, returningTo: .settingsRoot)

        UITestHarness.tapTab(.recommendations, in: app)
        openStage16BFixtureThread(in: app)
        let largeText = Stage16BUITestSupport.scrollToHittable(
            Stage16BUITestID.threadFirstText,
            inside: UITestElementID.threadReaderScroll.rawValue,
            in: app
        )
        XCTAssertGreaterThan(largeText.frame.height, standardHeight)
    }

    @MainActor
    func testStage16BThreadAuthorOpensFixtureProfile() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        openStage16BFixtureThread(in: app)
        Stage16BUITestSupport.tap(Stage16BUITestID.threadAuthor, in: app)
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.userProfile,
            in: app
        )
    }

    @MainActor
    private func openStage16BFixtureThread(in app: XCUIApplication) {
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
    private func scrollSettingsTo(
        _ identifier: String,
        direction: Stage16BUITestSupport.ScrollDirection = .up,
        in app: XCUIApplication
    ) -> XCUIElement {
        Stage16BUITestSupport.scrollToHittable(
            identifier,
            inside: UITestElementID.settingsRoot.rawValue,
            direction: direction,
            in: app
        )
    }
}

extension IPadAppShellSmokeTests {
    @MainActor
    func testStage16BHistorySettingsAndProfileOnIPad() {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }

        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)

        UITestHarness.scrollToHittable(
            .recommendationsSelectedRow,
            inside: .recommendationsList,
            in: app
        )
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        UITestHarness.requirePresent(.threadReaderScreen, in: app)
        Stage16BUITestSupport.tap(Stage16BUITestID.threadAuthor, in: app)
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.userProfile,
            in: app
        )

        revealRecommendationsSidebarIfNeeded(in: app)
        UITestHarness.tapTab(.settings, in: app)
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.appearancePicker,
            in: app
        )
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
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.threadHistoryRow,
            in: app
        )
        _ = Stage16BUITestSupport.requirePresent(
            Stage16BUITestID.userHistoryRow,
            in: app
        )
    }

    @MainActor
    private func revealRecommendationsSidebarIfNeeded(
        in app: XCUIApplication
    ) {
        let settingsTab = app.descendants(matching: .any)[
            UITestElementID.tabSettings.rawValue
        ]
        guard !settingsTab.exists else { return }

        let sidebarButton = app.navigationBars["推荐"]
            .buttons
            .element(boundBy: 0)
        XCTAssertTrue(sidebarButton.waitForExistence(timeout: 5))
        XCTAssertTrue(sidebarButton.isHittable)
        sidebarButton.tap()
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
    }
}
