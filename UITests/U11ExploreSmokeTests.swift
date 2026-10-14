import XCTest

final class U11ExploreSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testIndependentFeedsKeepPositionAcrossTabsAndThreadReturn() {
        let app = UITestHarness.launch(scenario: .rootNavigationMixedMedia)
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
        app.buttons["explore.tab.following"].tap()
        let following = app.tables["explore.following.list"]
        XCTAssertTrue(following.waitForExistence(timeout: 5))
        let target = following.buttons["recommendations.row.t100008"]
        for _ in 0..<6 {
            if target.exists && target.isHittable { break }
            following.swipeUp()
        }
        XCTAssertTrue(target.isHittable)
        let before = target.frame
        app.buttons["explore.tab.hot"].tap()
        let hot = app.tables["explore.hot.list"]
        XCTAssertTrue(hot.waitForExistence(timeout: 5))
        XCTAssertTrue(hot.buttons["recommendations.row.t100021"].isHittable)
        app.buttons["explore.tab.following"].tap()
        assertRestored(target, frame: before)
        target.tap()
        XCTAssertTrue(app.descendants(matching: .any)["thread-reader.screen.t100008"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(following.waitForExistence(timeout: 5))
        assertRestored(target, frame: before)
        following.swipeLeft()
        let selected = app.buttons["explore.tab.recommendations"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: selected)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
        for tab in [UITestAppTab.followedForums, .notifications, .settings, .recommendations] {
            UITestHarness.tapTab(tab, in: app)
            UITestHarness.requireTabSelected(tab, in: app)
        }
        UITestHarness.requirePresent(.recommendationsFirstRow, in: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "U11 independent feeds and return (fixture)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor
    private func assertRestored(_ element: XCUIElement, frame: CGRect) {
        let predicate = NSPredicate { _, _ in
            MainActor.assumeIsolated { element.exists && element.isHittable && abs(element.frame.midY - frame.midY) <= 12 }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5), .completed)
        XCTAssertEqual(element.frame.midY, frame.midY, accuracy: 12)
    }
}
