import XCTest

final class P02UserSearchSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testUserResultOpensProfileAndRestoresSearchPosition() {
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .followedForums)
        let search = app.buttons["home.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        let field = UITestHarness.element(.searchField, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Swift")
        UITestHarness.tap(.searchSubmit, in: app)
        Self.verifyUserSearch(in: app)
    }

    @MainActor
    static func verifyUserSearch(in app: XCUIApplication) {
        let tab = app.buttons["search.type.users"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(app.buttons["search.user.14001"].waitForExistence(timeout: 5))
        XCTAssertTrue(tab.isSelected)
        XCTAssertFalse(app.buttons["search.thread.100003"].exists)
        let target = app.buttons["search.user.14018"]
        let list = app.tables["search.list"]
        for _ in 0..<8 where !target.isHittable { list.swipeUp() }
        XCTAssertTrue(target.isHittable)
        XCTAssertFalse(app.buttons["search.user.14001"].isHittable)
        target.tap()
        XCTAssertTrue(app.descendants(matching: .any)["user-profile.screen.14018"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture 用户 18"].firstMatch.exists)
        XCTAssertFalse(app.buttons["profile.relationship-retry"].exists)
        app.buttons["profile.open.threads"].tap()
        XCTAssertTrue(app.tables["profile.threads.list"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch.tap()
        let forums = app.buttons["profile.open.forums"]
        XCTAssertTrue(forums.waitForExistence(timeout: 5))
        forums.tap()
        XCTAssertTrue(app.buttons["profile.forum.13001"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch.tap()
        XCTAssertTrue(forums.waitForExistence(timeout: 5))
        UITestHarness.tapSystemBack(in: app, returningTo: .searchRoot)
        XCTAssertTrue(target.isHittable)
        app.buttons["search.type.forums"].tap()
        XCTAssertTrue(app.buttons["search.forum.13001"].waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(target.isHittable)
        XCTAssertFalse(app.buttons["search.user.14001"].isHittable)
        XCTAssertEqual(UITestHarness.element(.searchField, in: app).value as? String, "Swift")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P02 user search restored")
    }
}
