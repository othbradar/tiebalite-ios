import XCTest

final class U14ContentActionUITests: XCTestCase {
    @MainActor
    func testLikesAndOwnThreadDeleteConfirmationUseExistingControls() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        let like = app.buttons["content.like.thread:100001:0"].firstMatch
        XCTAssertTrue(like.waitForExistence(timeout: 5))
        like.tap()
        expectValue("1", on: like)
        like.tap()
        expectValue("0", on: like)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let more = app.buttons["thread-reader.compose.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let delete = app.buttons["content.delete.thread:100001:0"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let alert = app.alerts["删除主题"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U14 own thread confirmation")
        alert.buttons["取消"].tap()
        XCTAssertTrue(list.exists)
        more.tap(); delete.tap()
        app.alerts["删除主题"].buttons["content.delete.confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["content.deleted.thread"].waitForExistence(timeout: 5))
        XCTAssertFalse(list.exists)
        XCTAssertFalse(app.buttons["thread-reader.compose"].exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U14 confirmed removal keeps navigation")
        app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch.tap()
        XCTAssertTrue(app.buttons["content.like.thread:100002:0"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["content.like.thread:100001:0"].exists)
    }
    @MainActor private func expectValue(_ value: String, on element: XCUIElement) {
        let condition = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [condition], timeout: 5), .completed)
    }
}
