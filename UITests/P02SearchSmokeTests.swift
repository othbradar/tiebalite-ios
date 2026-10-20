import XCTest

final class P02SearchSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testTypesKeepIndependentMiddlePositionsAcrossNavigation() {
        executionTimeAllowance = 150
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .followedForums)
        let homeSearch = app.buttons["home.search"]
        XCTAssertTrue(homeSearch.waitForExistence(timeout: 5))
        let homeFrame = homeSearch.frame
        homeSearch.tap()
        let field = UITestHarness.element(.searchField, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.frame.midY, homeFrame.midY, accuracy: 2)
        XCTAssertEqual(field.frame.minX, homeFrame.minX + 52, accuracy: 3)
        field.tap()
        field.typeText("Swift")
        UITestHarness.tap(.searchSubmit, in: app)
        UITestHarness.requirePresent(.searchList, in: app)
        Self.verifySortMenu(in: app)
        XCTAssertTrue(app.buttons["search.type.threads"].isSelected)
        let thread = app.buttons["search.thread.100004"]
        scrollTo(thread, in: app)
        XCTAssertFalse(app.buttons["search.thread.100003"].isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P02 phone threads middle")

        app.buttons["search.type.forums"].tap()
        XCTAssertTrue(app.buttons["search.type.forums"].isSelected)
        XCTAssertFalse(thread.exists)
        let forum = app.buttons["search.forum.13008"]
        scrollTo(forum, in: app)
        XCTAssertFalse(app.buttons["search.forum.13001"].isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P02 phone forums middle")

        app.buttons["search.type.threads"].tap()
        requireHittable(thread)
        XCTAssertFalse(app.buttons["search.thread.100003"].isHittable)
        thread.tap()
        XCTAssertTrue(app.descendants(matching: .any)["thread-reader.screen.t100004"].waitForExistence(timeout: 5))
        UITestHarness.tapSystemBack(in: app, returningTo: .searchRoot)
        requireHittable(thread)
        XCTAssertTrue(app.buttons["search.type.threads"].isSelected)

        app.buttons["search.type.forums"].tap()
        requireHittable(forum)
        XCTAssertFalse(app.buttons["search.forum.13001"].isHittable)
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .searchRoot)
        requireHittable(forum)
        XCTAssertTrue(app.buttons["search.type.forums"].isSelected)
        XCTAssertEqual(field.value as? String, "Swift")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    @MainActor
    static func verifySortMenu(in app: XCUIApplication) {
        let threads = app.buttons["search.type.threads"]
        threads.tap()
        let oldest = app.buttons["search.sort.0"]
        XCTAssertTrue(oldest.waitForExistence(timeout: 3))
        oldest.tap()
        XCTAssertTrue(app.buttons["search.thread.100011"].waitForExistence(timeout: 5))
        XCTAssertEqual(threads.value as? String, "旧帖在前")
        threads.tap()
        app.buttons["search.sort.2"].tap()
        XCTAssertTrue(app.buttons["search.thread.100006"].waitForExistence(timeout: 5))
        XCTAssertEqual(threads.value as? String, "相关度")
        app.buttons["search.type.forums"].tap()
        app.buttons["search.type.threads"].tap()
        XCTAssertEqual(threads.value as? String, "相关度")
        threads.tap()
        app.buttons["search.sort.5"].tap()
        XCTAssertTrue(app.buttons["search.thread.100003"].waitForExistence(timeout: 5))
        XCTAssertEqual(threads.value as? String, "新帖在前")
    }

    @MainActor
    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) {
        let list = app.tables["search.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<8 where !target.isHittable { list.swipeUp() }
        requireHittable(target)
    }

    @MainActor
    private func requireHittable(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }
}
