import XCTest

final class U01ForumSortSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testSortSurvivesReentryAndFollowsGlobalOnlyAfterReset() {
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        tap("followed-forums.row.f13001", in: app)
        choose("forum-home.sort.1", in: app)
        requireSort("最新发布", marker: "发帖排序", in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        UITestHarness.tapTab(.settings, in: app)
        tap("personal.open-settings", in: app)
        XCTAssertTrue(app.buttons["settings.forum-default-sort"].waitForExistence(timeout: 5))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U01 default sort settings")
        UITestHarness.tapTab(.followedForums, in: app)
        tap("followed-forums.row.f13001", in: app)
        requireSort("最新发布", marker: "发帖排序", in: app)
        choose("forum-home.sort.follow-global", in: app)
        requireSort("最新回复", marker: "回复排序", in: app)
        tap("forum-home.sort", in: app)
        XCTAssertFalse(app.buttons["forum-home.sort.follow-global"].isEnabled)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U01 forum sort menu")
    }

    @MainActor
    private func choose(_ identifier: String, in app: XCUIApplication) {
        tap("forum-home.sort", in: app)
        tap(identifier, in: app)
    }

    @MainActor
    private func tap(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5), identifier)
        XCTAssertTrue(button.isHittable, identifier)
        button.tap()
    }

    @MainActor
    private func requireSort(_ title: String, marker: String, in app: XCUIApplication) {
        let menu = app.buttons["forum-home.sort"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertEqual(menu.value as? String, title)
        let row = app.buttons["forum-home.row.t140001"]
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", marker), object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 5), .completed)
    }
}
