import XCTest

final class P01ReplyFilterTests: XCTestCase {
    @MainActor
    func testReplyFilterBarReplacesCountAndRemembersAcrossThreads() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        let all = app.buttons["thread-reader.filter.all"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if all.exists && all.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(all.exists && all.isHittable)
        XCTAssertFalse(app.staticTexts["回复 88"].exists)
        let author = app.buttons["thread-reader.filter.author"]
        let hot = app.buttons["thread-reader.order.hot"]
        let reverse = app.buttons["thread-reader.order.descending"]
        XCTAssertTrue(author.isHittable && hot.isHittable && reverse.isHittable)
        author.tap()
        waitMode("author-ascending", app: app)
        reveal(reverse, in: list)
        reverse.tap()
        waitMode("author-descending", app: app)
        reveal(all, in: list)
        all.tap()
        waitMode("all-descending", app: app)
        reveal(hot, in: list)
        hot.tap()
        waitMode("all-hot", app: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P01 reply filters")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        UITestHarness.tap(.recommendationsSelectedRow, in: app)
        waitMode("all-hot", app: app)
    }

    @MainActor private func reveal(_ element: XCUIElement, in list: XCUIElement) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    @MainActor private func waitMode(_ query: String, app: XCUIApplication) {
        let predicate = NSPredicate(format: "value BEGINSWITH %@ AND enabled == true", query + ";page:")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons["thread-reader.compose.more"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
