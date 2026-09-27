import XCTest

final class R12BackButtonSmokeTests: XCTestCase {
    @MainActor
    func testThreadContentBackKeepsForumNavigationButtonThreeTimes() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        app.buttons["followed-forums.row.f13001"].tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        let thread = app.buttons["forum-home.row.t140003"]
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        let initialY = thread.frame.minY
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R12-back-before")
        for iteration in 1...3 {
            thread.tap()
            let reader = app.tables["thread-reader.scroll.t140003"]
            XCTAssertTrue(reader.waitForExistence(timeout: 5))
            reader.swipeRight()
            let returned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !reader.exists && thread.isHittable
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
            XCTAssertTrue(app.buttons["forum-home.tab.latest"].isSelected)
            XCTAssertEqual(thread.frame.minY, initialY, accuracy: 2)
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.isHittable)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R12-back-return-\(iteration)")
        }
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
    }
}
