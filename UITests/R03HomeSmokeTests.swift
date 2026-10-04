import XCTest

final class R03HomeSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeSearchThreeSuccessfulVisitsCollapseAndReturnPosition() {
        executionTimeAllowance = 120
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture, startingTab: .followedForums)
        XCTAssertTrue(app.staticTexts["home.title"].isHittable)
        XCTAssertEqual(recentButtons(in: app).count, 0)
        tap("home.search", in: app)
        UITestHarness.requirePresent(.searchRoot, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsRoot)
        for forumID in 13_001...13_003 {
            tap("followed-forums.row.f\(forumID)", in: app)
            UITestHarness.requirePresent(.forumHomeHeader, in: app)
            UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsRoot)
            XCTAssertTrue(app.buttons["home.recent.f\(forumID)"].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(recentButtons(in: app).count, 3)
        // Use the existing forum business ID, independent of list row positions.
        let first = app.buttons["followed-forums.row.f13001"]
        let firstFrame = first.frame
        XCTAssertTrue(first.isHittable)
        first.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsRoot)
        XCTAssertTrue(first.isHittable)
        XCTAssertEqual(first.frame.midY, firstFrame.midY, accuracy: 12)
        XCTAssertEqual(recentButtons(in: app).count, 3)
        XCTAssertTrue(recentButtons(in: app).element(boundBy: 0).identifier == "home.recent.f13001")
        tap("home.recent.toggle", in: app)
        XCTAssertEqual(app.buttons["home.recent.toggle"].value as? String, "已收起")
        XCTAssertEqual(recentButtons(in: app).count, 0)
        tap("home.recent.toggle", in: app)
        XCTAssertEqual(recentButtons(in: app).count, 3)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R03 iPhone home recent followed")
    }

    @MainActor
    func testRecentForumsLongPressTogglesRemovalWithoutUnfollowing() {
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .sessionSignedInFixture, startingTab: .followedForums)
        for forumID in 13_001...13_002 {
            tap("followed-forums.row.f\(forumID)", in: app)
            UITestHarness.requirePresent(.forumHomeHeader, in: app)
            UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsRoot)
        }
        let first = app.buttons["home.recent.f13001"]
        let remove = app.buttons["home.recent.remove.f13001"]
        XCTAssertFalse(remove.exists)
        first.press(forDuration: 0.8)
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.recent.remove.f13002"].exists)
        XCTAssertFalse(app.buttons["forum-home.search"].exists)
        first.press(forDuration: 0.8)
        XCTAssertTrue(remove.waitForNonExistence(timeout: 3))
        first.press(forDuration: 0.8)
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        remove.tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.recent.f13002"].exists)
        XCTAssertTrue(app.buttons["followed-forums.row.f13001"].exists)
        app.buttons["home.recent.f13002"].press(forDuration: 0.8)
        tap("home.recent.f13002", in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsRoot)
        XCTAssertFalse(first.exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "Recent forum removal preserves followed list")
    }

    @MainActor
    func testIPadHomeRecentForumsSurviveDarkWidthChange() {
        executionTimeAllowance = 90
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(
            scenario: .sessionSignedInFixture, displayProfile: .darkAccessibilityReduced, startingTab: .followedForums
        )
        for forumID in 13_001...13_003 {
            tap("followed-forums.row.f\(forumID)", in: app)
            UITestHarness.requirePresent(.forumHomeHeader, in: app)
            XCTAssertTrue(app.buttons["home.recent.f\(forumID)"].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(recentButtons(in: app).count, 3)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R03 iPad dark landscape")
        device.orientation = .portrait
        XCTAssertTrue(app.buttons["home.search"].isHittable)
        XCTAssertTrue(app.buttons["followed-forums.row.f13001"].isHittable)
        XCTAssertEqual(recentButtons(in: app).count, 3)
        tap("home.search", in: app)
        UITestHarness.requirePresent(.searchRoot, in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R03 iPad dark portrait search route")
    }

    @MainActor
    private func recentButtons(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.recent.f"))
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5), identifier)
        XCTAssertTrue(button.isHittable, identifier)
        button.tap()
    }
}
