import XCTest

extension IPadAppShellSmokeTests {
    @MainActor
    func testIPadSwitchingFromThreadToPersonalDoesNotRetainOtherRootDetail() {
        defer { XCUIDevice.shared.orientation = .portrait }
        var retainedThread: [Bool] = []
        for attempt in 1...3 {
            XCUIDevice.shared.orientation = .portrait
            let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
            app.buttons["followed-forums.row.f13001"].tap()
            let thread = app.buttons["forum-home.row.t140003"]
            XCTAssertTrue(thread.waitForExistence(timeout: 5))
            thread.tap()
            let reader = app.tables["thread-reader.scroll.t140003"]
            XCTAssertTrue(reader.waitForExistence(timeout: 5))
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            UITestHarness.tapTab(.settings, in: app)
            UITestHarness.requireTabSelected(.settings, in: app)
            XCTAssertTrue(app.buttons["personal.open-profile"].waitForExistence(timeout: 5))
            let cleared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !reader.exists || !reader.isHittable
            }, object: app)
            retainedThread.append(XCTWaiter.wait(for: [cleared], timeout: 5) != .completed)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R13 personal after thread \(attempt)")
            UITestHarness.tapTab(.followedForums, in: app)
            XCTAssertTrue(reader.waitForExistence(timeout: 5), "Returning must retain the forum's thread path")
            XCTAssertTrue(reader.isHittable)
        }
        XCTAssertEqual(retainedThread, [false, false, false], "Personal must not display another root's thread")
    }
}
