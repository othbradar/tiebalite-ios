import XCTest

final class P03ForumSearchSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testScopedSearchPagesReturnToResultsAndOriginalForumPosition() {
        executionTimeAllowance = 120
        XCUIDevice.shared.orientation = .portrait
        Self.verifyForumSearch()
    }

    @MainActor
    func testIPadScopedSearchPagesReturnToOriginalForum() {
        executionTimeAllowance = 120
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        Self.verifyForumSearch()
    }

    @MainActor
    func testScopedSearchSupportsSystemEdgeBack() {
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        app.buttons["forum-home.search"].tap()
        UITestHarness.requirePresent(.searchRoot, in: app)
        Self.verifySearchBoxFitsNavigationBar(app)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.buttons["forum-home.search"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["forum-home.search.close"].exists)
    }

    @MainActor
    private static func verifyForumSearch() {
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        app.buttons["forum-home.sort"].tap()
        app.buttons["forum-home.sort.1"].tap()
        let list = app.tables["forum-home.list"].firstMatch
        list.swipeUp()
        let visible = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "forum-home.row.t"))
            .allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(visible)
        let rowID = visible?.identifier ?? ""
        let originalY = visible?.frame.midY ?? 0
        app.buttons["forum-home.search"].tap()
        UITestHarness.requirePresent(.searchRoot, in: app)
        XCTAssertFalse(app.sheets.firstMatch.exists, "Forum search must push in the existing navigation stack")
        XCTAssertTrue(app.staticTexts["搜索历史"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search.history.clear"].exists)
        XCTAssertFalse(app.buttons["search.type.forums"].exists)
        XCTAssertFalse(app.buttons["search.type.users"].exists)
        let field = UITestHarness.element(.searchField, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        verifySearchBoxFitsNavigationBar(app)
        XCTAssertTrue((field.value as? String ?? "").contains("吧内搜索"))
        field.tap()
        field.typeText("Fixture")
        UITestHarness.tap(.searchSubmit, in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5),
                      "Submitting the toolbar search field must dismiss the keyboard before paging")
        XCTAssertTrue(app.buttons["search.forum-mode.comments"].waitForExistence(timeout: 5))
        app.buttons["search.forum-mode.comments"].tap()
        app.buttons["search.forum-sort"].tap()
        XCTAssertTrue(app.buttons["search.forum-sort.2"].waitForExistence(timeout: 5))
        app.buttons["search.forum-sort.2"].tap()
        XCTAssertEqual(app.buttons["search.forum-sort"].value as? String, "相关在前")
        app.buttons["search.forum-mode.topics"].tap()
        XCTAssertEqual(app.buttons["search.forum-sort"].value as? String, "相关在前")
        let result = app.buttons["search.thread.100011"]
        let results = app.tables["search.list"]
        XCTAssertTrue(results.waitForExistence(timeout: 5))
        for _ in 0..<8 where !result.isHittable { results.swipeUp() }
        XCTAssertTrue(result.isHittable)
        let resultY = result.frame.midY
        XCTAssertTrue(app.buttons["search.forum-mode.topics"].isSelected)
        result.tap()
        XCTAssertTrue(app.descendants(matching: .any)["thread-reader.screen.t100011"].waitForExistence(timeout: 5))
        // Use the visible system back action in the current detail navigation stack.
        let back = app.navigationBars.buttons.matching(identifier: "BackButton")
            .allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(back)
        back?.tap()
        UITestHarness.requirePresent(.searchRoot, in: app)
        XCTAssertTrue(result.isHittable)
        XCTAssertEqual(result.frame.midY, resultY, accuracy: 14)
        XCTAssertEqual(field.value as? String, "Fixture")
        XCTAssertTrue(app.buttons["search.forum-mode.topics"].isSelected)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P03 scoped second page returned")
        app.buttons["forum-home.search.close"].tap()
        XCTAssertTrue(app.buttons[rowID].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[rowID].isHittable)
        XCTAssertEqual(app.buttons[rowID].frame.midY, originalY, accuracy: 14)
        XCTAssertEqual(app.buttons["forum-home.sort"].value as? String, "最新发布")
        app.buttons["forum-home.search"].tap()
        let history = app.buttons["search.history.word.0"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        XCTAssertEqual(history.label, "Fixture")
        history.tap()
        XCTAssertTrue(app.tables["search.list"].waitForExistence(timeout: 5))
        app.buttons["search.clear"].tap()
        XCTAssertTrue(app.buttons["search.history.clear"].waitForExistence(timeout: 5))
        app.buttons["search.history.clear"].tap()
        XCTAssertFalse(app.buttons["search.history.word.0"].exists)
    }

    @MainActor
    private static func verifySearchBoxFitsNavigationBar(_ app: XCUIApplication) {
        let box = app.descendants(matching: .any).matching(identifier: "search.box").firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        let bar = app.navigationBars.allElementsBoundByIndex.first {
            $0.textFields["search.field"].exists
        }
        XCTAssertNotNil(bar)
        guard let bar else { return }
        XCTAssertGreaterThanOrEqual(box.frame.minY, bar.frame.minY,
                                    "The search surface must not extend above the navigation transition's clipping bounds")
        XCTAssertLessThanOrEqual(box.frame.maxY, bar.frame.maxY)
    }
}
