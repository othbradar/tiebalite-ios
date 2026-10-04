import XCTest

final class U02ForumCacheSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testReenterRetainsSecondPageAndSortThenPullToRefresh() {
        executionTimeAllowance = 100
        let app = UITestHarness.launch(scenario: .forumContentCache, startingTab: .followedForums)
        tap("followed-forums.row.f13001", in: app)
        let list = app.tables["forum-home.list"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let secondPage = app.buttons["forum-home.row.t140103"]
        for _ in 0..<12 {
            if secondPage.exists, secondPage.frame.intersects(list.frame), secondPage.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(secondPage.isHittable)
        let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "forum-home.row.t"))
            .allElementsBoundByIndex.filter { !$0.frame.isEmpty && $0.frame.intersects(list.frame) && $0.isHittable }
            .sorted { $0.frame.minY < $1.frame.minY }
        let anchor = visible.first?.identifier ?? "missing-anchor"
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 deep position before leaving")
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        tap("followed-forums.row.f13001", in: app)
        let restored = app.buttons[anchor]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        let restoredVisible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            restored.isHittable && restored.frame.intersects(list.frame)
        }, object: restored)
        let restorationResult = XCTWaiter.wait(for: [restoredVisible], timeout: 5)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 restored position check")
        XCTAssertEqual(restorationResult, .completed, "row=\(restored.frame), list=\(list.frame)")
        XCTAssertFalse(app.descendants(matching: .any)["forum-home.state.initial-loading"].exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 cached second page reentry")
        tap("forum-home.sort", in: app)
        tap("forum-home.sort.1", in: app)
        let firstRow = app.buttons["forum-home.row.t140001"]
        let created = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "发帖排序"), object: firstRow)
        XCTAssertEqual(XCTWaiter.wait(for: [created], timeout: 5), .completed)
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            .press(forDuration: 0, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U06P1 full pull after sort")
        waitForRefresh(2, row: firstRow)
        XCTAssertTrue(firstRow.isHittable)
        XCTAssertTrue(firstRow.label.contains("发帖排序"))
        let topInset = firstRow.frame.minY - list.frame.minY
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        tap("followed-forums.row.f13001", in: app)
        waitForRefresh(3, row: firstRow)
        XCTAssertEqual(firstRow.frame.minY - list.frame.minY, topInset, accuracy: 12)
        XCTAssertFalse(app.buttons["forum-home.cache.new-content"].exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 creation sort after pull refresh")
    }

    @MainActor
    func testScrollingBackToTopReplacesRememberedPosition() {
        executionTimeAllowance = 100
        let app = UITestHarness.launch(scenario: .forumContentCache, startingTab: .followedForums)
        tap("followed-forums.row.f13001", in: app)
        let list = app.tables["forum-home.list"].firstMatch
        let firstRow = app.buttons["forum-home.row.t140001"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        let initialInset = firstRow.frame.minY - list.frame.minY
        for _ in 0..<2 {
            list.swipeUp()
            XCTAssertFalse(firstRow.exists && firstRow.frame.intersects(list.frame))
            for _ in 0..<8 {
                if firstRow.exists, abs(firstRow.frame.minY - list.frame.minY - initialInset) < 12 { break }
                list.swipeDown(velocity: .slow)
            }
            XCTAssertTrue(firstRow.isHittable)
            XCTAssertEqual(firstRow.frame.minY - list.frame.minY, initialInset, accuracy: 12)
            UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
            tap("followed-forums.row.f13001", in: app)
            XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
            XCTAssertTrue(firstRow.isHittable)
            XCTAssertEqual(firstRow.frame.minY - list.frame.minY, initialInset, accuracy: 12)
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 returned to top then reopened")
    }

    @MainActor
    func testReentryAndPullRefreshShowNewPostsWithoutUpdateBanner() throws {
        let app = UITestHarness.launch(scenario: .forumContentCache, startingTab: .followedForums)
        tap("followed-forums.row.f13001", in: app)
        let first = app.buttons["forum-home.row.t140001"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        // Home prefetch may finish before the tap. Check one new request per user
        // action relative to the displayed source revision, not a fixed initial count.
        let range = try XCTUnwrap(first.label.range(of: "刷新[0-9]+", options: .regularExpression))
        let initial = try XCTUnwrap(Int(first.label[range].dropFirst(2)))
        XCTAssertGreaterThan(initial, 0)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        tap("followed-forums.row.f13001", in: app)
        waitForRefresh(initial + 1, row: first)
        XCTAssertFalse(app.buttons["forum-home.cache.new-content"].exists)
        XCTAssertFalse(app.staticTexts["forum-home.cache.update-failed"].exists)
        let list = app.tables["forum-home.list"]
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            .press(forDuration: 0, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 after full pull gesture")
        waitForRefresh(initial + 2, row: first)
        XCTAssertTrue(first.isHittable)
        XCTAssertFalse(app.buttons["forum-home.cache.new-content"].exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U02 automatic and pull refresh without banner")
    }

    @MainActor
    private func waitForRefresh(_ count: Int, row: XCUIElement) {
        let updated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "刷新\(count)"), object: row
        )
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed, "Expected refresh \(count), row: \(row.label)")
    }

    @MainActor
    private func tap(_ id: String, in app: XCUIApplication) {
        let element = app.buttons[id]
        XCTAssertTrue(element.waitForExistence(timeout: 5), id)
        XCTAssertTrue(element.isHittable, id)
        element.tap()
    }
}
