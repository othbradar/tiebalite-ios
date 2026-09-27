import XCTest

final class R12VisualParitySmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPersonalAccountThemeDestinationsAndRootReturn() {
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .dynamicFeedParity, startingTab: .followedForums)
        XCTAssertTrue(app.tables["followed-forums.list"].waitForExistence(timeout: 5))
        shot(app, "01-home")
        UITestHarness.tapTab(.recommendations, in: app)
        XCTAssertTrue(app.tables["recommendations.list"].waitForExistence(timeout: 5))
        shot(app, "02-dynamic")
        UITestHarness.tapTab(.notifications, in: app)
        XCTAssertTrue(app.tables["notifications.list.replies"].waitForExistence(timeout: 5))
        shot(app, "03-notifications")
        UITestHarness.tapTab(.settings, in: app)
        let header = app.buttons["personal.open-profile"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(header.label.contains("示例账户"))
        let replies = app.descendants(matching: .any)["personal.stat.回贴"]
        XCTAssertTrue(replies.exists)
        XCTAssertTrue(replies.label.contains("12511"))
        shot(app, "04-personal")
        header.tap()
        XCTAssertTrue(app.scrollViews["user-profile.screen.12001"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["personal.account.name"].label, "示例账户")
        XCTAssertTrue(app.staticTexts["user-profile.facts.12001"].label.contains("56"))
        shot(app, "personal-profile")
        back(app)
        app.buttons["settings.open-history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 5))
        back(app)
        app.buttons["personal.theme"].tap()
        app.buttons["深色"].tap()
        XCTAssertTrue(app.buttons["personal.theme"].label.contains("深色"))
        shot(app, "personal-dark")
        app.buttons["personal.theme"].tap()
        app.buttons["跟随系统"].tap()
        app.buttons["personal.open-settings"].tap()
        XCTAssertTrue(app.segmentedControls["settings.appearance"].waitForExistence(timeout: 5))
        shot(app, "settings")
        back(app)
        app.buttons["settings.open-about"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.about"].waitForExistence(timeout: 5))
        back(app)
        for tab in [UITestAppTab.followedForums, .recommendations, .notifications, .settings] {
            UITestHarness.tapTab(tab, in: app)
            UITestHarness.requireTabSelected(tab, in: app)
        }
        XCTAssertTrue(header.isHittable && header.label.contains("示例账户"))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            XCTAssertTrue(header.isHittable)
            shot(app, "ipad-personal-landscape")
            XCUIDevice.shared.orientation = .portrait
            UITestHarness.requirePresent(.layoutCompact, in: app)
            XCTAssertTrue(header.isHittable)
        }
    }

    @MainActor
    func testReadingScreensAndComposerMatrix() {
        XCUIDevice.shared.orientation = .portrait
        var app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        app.buttons["followed-forums.row.f13001"].tap()
        XCTAssertTrue(app.tables["forum-home.list"].firstMatch.waitForExistence(timeout: 5))
        shot(app, "05-forum")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            shot(app, "ipad-forum-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
        app = UITestHarness.launch(scenario: .threadReaderParity)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let reader = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        shot(app, "06-thread")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            shot(app, "ipad-thread-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
        app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let all = app.buttons["thread-reader.subposts.all.p120001"]
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        reveal(all, in: list)
        all.tap()
        XCTAssertTrue(app.tables["subposts.list"].waitForExistence(timeout: 5))
        shot(app, "07-subposts")
        let reply = app.buttons["subposts.reply.10001.action"]
        reveal(reply, in: app.tables["subposts.list"])
        reply.tap()
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["composer.send"].isEnabled)
        shot(app, "08-composer")
        app.buttons["composer.cancel"].tap()
        XCTAssertTrue(app.tables["subposts.list"].isHittable)
    }

    @MainActor
    func testPersonalDarkLargeTypeAndSignedOutEntry() {
        XCUIDevice.shared.orientation = .portrait
        var app = UITestHarness.launch(scenario: .dynamicFeedParity,
                                       displayProfile: .darkAccessibilityReduced, startingTab: .settings)
        XCTAssertTrue(app.buttons["personal.open-profile"].waitForExistence(timeout: 5))
        shot(app, "personal-dark-large")
        let settings = app.buttons["personal.open-settings"]
        reveal(settings, in: app.scrollViews.firstMatch)
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        XCTAssertTrue(app.segmentedControls["settings.appearance"].waitForExistence(timeout: 5))
        app = UITestHarness.launch(scenario: .sessionSignedOut, startingTab: .settings)
        XCTAssertFalse(app.descendants(matching: .any)["personal.stat.回贴"].exists)
        let header = app.buttons["personal.open-profile"]
        XCTAssertTrue(header.label.contains("登录贴吧"))
        header.tap()
        XCTAssertTrue(app.buttons["session.login.cancel"].waitForExistence(timeout: 5))
    }

    @MainActor private func reveal(_ element: XCUIElement, in list: XCUIElement) {
        for _ in 0..<8 {
            if element.exists, !element.frame.isEmpty, element.frame.intersects(list.frame), element.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func back(_ app: XCUIApplication) { app.navigationBars.buttons.element(boundBy: 0).tap() }

    @MainActor private func shot(_ app: XCUIApplication, _ name: String) {
        let family = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R12-\(family)-\(name)")
    }
}
