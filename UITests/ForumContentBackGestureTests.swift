import XCTest

final class ForumContentBackGestureTests: XCTestCase {
    @MainActor
    func testOtherTabsStillPageAndCancelledBackPreservesScroll() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        // The first visit adds the existing recent-forum row. Compare like-for-like root content.
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        XCTAssertTrue(app.buttons["home.recent.f13001"].waitForExistence(timeout: 5))
        let rootY = forum.frame.midY
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        let list = app.tables["forum-home.list"].firstMatch
        list.swipeLeft()
        requireSelected("good", app: app)
        list.swipeRight()
        requireSelected("latest", app: app)
        list.swipeUp()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "forum-home.row.t"))
            .allElementsBoundByIndex.first { $0.isHittable && $0.frame.midY > list.frame.minY }
        XCTAssertNotNil(row)
        let rowID = row?.identifier ?? ""
        let rowY = row?.frame.midY ?? 0
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.6))
        let shortTravel = list.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: shortTravel, withVelocity: .slow, thenHoldForDuration: 0.1)
        requireSelected("latest", app: app)
        XCTAssertTrue(app.buttons[rowID].isHittable)
        XCTAssertEqual(app.buttons[rowID].frame.midY, rowY, accuracy: 2)
        list.swipeRight()
        UITestHarness.requirePresent(.followedForumsFirstRow, in: app)
        XCTAssertFalse(app.buttons["forum-home.tab.latest"].exists)
        XCTAssertEqual(forum.frame.midY, rootY, accuracy: 2)
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        app.buttons["forum-home.tab.good"].tap()
        requireSelected("good", app: app)
        UITestHarness.swipeSystemBack(in: app, returningTo: .followedForumsFirstRow)
        XCTAssertFalse(app.buttons["forum-home.tab.good"].exists)
    }

    @MainActor
    func testFirstTabContentSwipeReturnsToFollowedForumsThreeTimes() {
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        for iteration in 1...3 {
            if forum.isHittable { forum.tap() }
            UITestHarness.requirePresent(.forumHomeHeader, in: app)
            XCTAssertTrue(app.buttons["forum-home.tab.latest"].isSelected)
            let list = app.tables["forum-home.list"].firstMatch
            XCTAssertTrue(list.waitForExistence(timeout: 5))
            list.swipeRight()
            let returned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                forum.isHittable && !app.buttons["forum-home.tab.latest"].exists
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed, "Content back attempt \(iteration)")
            UITestHarness.attachSafeVisualEvidence(app: app, name: "Forum content back attempt \(iteration)")
        }
    }

    @MainActor
    private func requireSelected(_ id: String, app: XCUIApplication) {
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"),
            object: app.buttons["forum-home.tab.\(id)"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }
}
