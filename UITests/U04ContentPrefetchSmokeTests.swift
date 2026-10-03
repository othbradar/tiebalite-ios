import XCTest

final class U04ContentPrefetchSmokeTests: XCTestCase {
    @MainActor
    func testPreloadedThreadOpenAndReadingReentry() {
        continueAfterFailure = false
        executionTimeAllowance = 100
        let app = UITestHarness.launch(scenario: .forumContentCache, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        let thread = app.buttons["forum-home.row.t140001"]
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        let list = app.tables["thread-reader.scroll.t140001"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let screen = app.descendants(matching: .any)["thread-reader.screen.t140001"].firstMatch
        XCTAssertEqual(screen.value as? String, "content-source:cache")
        list.swipeUp(velocity: .slow)
        let visible = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "thread-reader.post.t140001."))
            .allElementsBoundByIndex.filter { !$0.frame.isEmpty && $0.frame.intersects(list.frame) && $0.isHittable }
        let anchor = visible.min { $0.frame.minY < $1.frame.minY }?.identifier ?? "missing-anchor"
        XCTAssertNotEqual(anchor, "missing-anchor")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        let restored = app.descendants(matching: .any)[anchor].firstMatch
        let restoredVisible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            restored.exists && restored.isHittable && restored.frame.intersects(list.frame)
                && list.value as? String == "initial-restoration:idle"
        }, object: restored)
        XCTAssertEqual(XCTWaiter.wait(for: [restoredVisible], timeout: 5), .completed)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U04 preloaded thread reentry")
    }

}
