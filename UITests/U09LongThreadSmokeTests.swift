import XCTest

final class U09LongThreadSmokeTests: XCTestCase {
    @MainActor
    func testModesJumpAndFirstPostUseExistingMenu() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let menu = app.buttons["thread-reader.compose.more"]
        choose("thread-reader.only-author", app: app)
        waitMode("author-ascending;page:1", menu: menu)
        XCTAssertTrue(app.textViews["thread-reader.content.node.t100001.p150001.spost.n0"].exists)
        choose("thread-reader.only-author", app: app)
        waitMode("all-ascending;page:1", menu: menu)
        choose("thread-reader.reverse", app: app)
        waitMode("all-descending;page:1", menu: menu)
        choose("thread-reader.reverse", app: app)
        waitMode("all-ascending;page:1", menu: menu)
        choose("thread-reader.jump-page", app: app)
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("4")
        app.alerts.buttons["thread-reader.jump-confirm"].firstMatch.tap()
        waitMode("all-ascending;page:4", menu: menu)
        let target = app.textViews["thread-reader.content.node.t100001.p570001.spost.n0"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(target.isHittable, "menu=\(menu.value ?? "none"); target=\(target.frame); list=\(list.frame)")
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U09 nonadjacent page")
        choose("thread-reader.first-post", app: app)
        waitMode("all-ascending;page:1", menu: menu)
        let first = app.textViews["thread-reader.content.node.t100001.p110001.sfirstPost.n0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isHittable)
        choose("thread-reader.jump-page", app: app)
        app.alerts.textFields.firstMatch.typeText("999")
        app.alerts.buttons["thread-reader.jump-confirm"].firstMatch.tap()
        XCTAssertTrue(app.alerts["无法跳转"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].firstMatch.tap()
        XCTAssertTrue(first.isHittable)
    }

    @MainActor private func choose(_ identifier: String, app: XCUIApplication) {
        let menu = app.buttons["thread-reader.compose.more"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let action = app.buttons[identifier]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.tap()
    }

    @MainActor private func waitMode(_ value: String, menu: XCUIElement) {
        let predicate = NSPredicate(format: "value BEGINSWITH %@ AND enabled == true", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: menu)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
