import XCTest

final class R05ReadingShellSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPhoneReadingRemovesRootBarAndRestoresItOnBackThreeTimes() {
        executionTimeAllowance = 150
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        var readingBars: [Bool] = []
        var forumBottomGaps: [CGFloat] = []
        for iteration in 0..<3 {
            UITestHarness.tap(.followedForumsFirstRow, in: app)
            UITestHarness.requirePresent(.forumHomeHeader, in: app)
            let list = app.tables["forum-home.list"].firstMatch
            XCTAssertTrue(list.waitForExistence(timeout: 5))
            readingBars.append(rootBarVisible(app))
            forumBottomGaps.append(app.frame.maxY - list.frame.maxY)
            if iteration == 0 {
                UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 revision phone forum")
            }
            let thread = app.buttons["forum-home.row.t140003"]
            XCTAssertTrue(thread.waitForExistence(timeout: 5))
            thread.tap()
            XCTAssertTrue(app.descendants(matching: .any)["thread-reader.screen.t140003"]
                .waitForExistence(timeout: 5))
            readingBars.append(rootBarVisible(app))
            if iteration == 0 {
                UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 revision phone thread")
            }
            UITestHarness.tapSystemBack(in: app, returningTo: .forumHomeHeader)
            readingBars.append(rootBarVisible(app))
            UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
            XCTAssertTrue(rootBarVisible(app))
        }
        for (tab, root) in [
            (UITestAppTab.recommendations, UITestElementID.recommendationsRoot),
            (.notifications, .notificationsRoot), (.settings, .personalRoot),
            (.followedForums, .followedForumsRoot)
        ] {
            UITestHarness.tapTab(tab, in: app)
            UITestHarness.requirePresent(root, in: app)
            UITestHarness.requireTabSelected(tab, in: app)
        }
        XCTAssertEqual(readingBars, Array(repeating: false, count: 9), "Forum, thread and return-to-forum")
        XCTAssertTrue(forumBottomGaps.allSatisfy { abs($0) <= 1 }, "Reading bottom gaps: \(forumBottomGaps)")
    }

    @MainActor
    func testIPadPortraitUsesFullWidthAndLandscapeKeepsSplitThreeTimes() {
        executionTimeAllowance = 150
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        defer { device.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        app.buttons["forum-home.tab.good"].tap()
        let header = UITestHarness.element(.forumHomeHeader, in: app)
        var portraitWidths: [CGFloat] = []
        var portraitBars: [Bool] = []
        for iteration in 0..<3 {
            device.orientation = .portrait
            requireOrientation(landscape: false, app: app)
            UITestHarness.requirePresent(.forumHomeHeader, in: app)
            portraitWidths.append(header.frame.width / app.frame.width)
            portraitBars.append(rootBarVisible(app))
            XCTAssertTrue(app.buttons["forum-home.tab.good"].isSelected)
            if iteration == 0 {
                UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 revision iPad portrait")
            }
            device.orientation = .landscapeLeft
            requireOrientation(landscape: true, app: app)
            UITestHarness.requirePresent(.layoutRegular, in: app)
            XCTAssertTrue(rootBarVisible(app))
            XCTAssertLessThan(header.frame.width / app.frame.width, 0.8)
            XCTAssertTrue(app.buttons["forum-home.tab.good"].isSelected)
        }
        XCTAssertEqual(portraitBars, Array(repeating: false, count: 3), "Portrait width ratios: \(portraitWidths)")
        XCTAssertTrue(portraitWidths.allSatisfy { $0 > 0.9 }, "Portrait width ratios: \(portraitWidths)")
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 revision iPad landscape")
        app.buttons["forum-home.tab.latest"].tap()
        let thread = app.buttons["forum-home.row.t140003"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"), object: thread
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        thread.tap()
        let reader = app.descendants(matching: .any)["thread-reader.screen.t140003"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        device.orientation = .portrait
        requireOrientation(landscape: false, app: app)
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        portraitBars.append(rootBarVisible(app))
        portraitWidths.append(reader.frame.width / app.frame.width)
        UITestHarness.tapSystemBack(in: app, returningTo: .forumHomeHeader)
        XCTAssertTrue(app.buttons["forum-home.tab.latest"].isSelected)
        XCTAssertEqual(portraitBars, Array(repeating: false, count: 4))
        XCTAssertTrue(portraitWidths.allSatisfy { $0 > 0.9 }, "Portrait width ratios: \(portraitWidths)")
        UITestHarness.requirePresent(.layoutCompact, in: app)
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        XCTAssertTrue(rootBarVisible(app))
        app.buttons["home.search"].tap()
        UITestHarness.requirePresent(.searchRoot, in: app)
        let searchField = UITestHarness.element(.searchField, in: app)
        searchField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        searchField.typeText("Swift")
        UITestHarness.requirePresent(.layoutCompact, in: app)
        XCTAssertGreaterThan(UITestHarness.element(.searchRoot, in: app).frame.width / app.frame.width, 0.9)
    }

    @MainActor
    private func rootBarVisible(_ app: XCUIApplication) -> Bool {
        let button = app.buttons["app.tab.notifications"]
        return button.exists && button.isHittable
    }

    @MainActor
    private func requireOrientation(landscape: Bool, app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.frame.width > app.frame.height) == landscape
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
