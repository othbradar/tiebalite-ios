import XCTest

final class U03ThreadCacheSmokeTests: XCTestCase {
    @MainActor
    func testReaderReentryKeepsDeepRowAndMediaRoundTripDoesNotRestoreAgain() {
        _ = checkReentryAndNewPosition()
    }

    // Keep the original rotation regression and exact restored-row assertion.
    @MainActor
    func testIPadRotationKeepsNewReadingPosition() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        let restored = checkReentryAndNewPosition()
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        requireVisible(restored, in: app)
        XCUIDevice.shared.orientation = .portrait
        requireVisible(restored, in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P4 same floor portrait landscape portrait")
    }

    @MainActor
    func testIPadWindowResizeKeepsNewReadingPosition() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        let restored = checkReentryAndNewPosition()
        let app = XCUIApplication()
        let list = app.tables["thread-reader.scroll.t140001"].firstMatch
        // Resize the same compact projection, then return to the full viewport.
        app.buttons["app.harness.layout.narrow"].tap()
        requireVisible(restored, in: app)
        app.buttons["app.harness.layout.regular"].tap()
        requireVisible(restored, in: app)
        list.swipeUp()
        let newAnchor = visibleAnchor(in: app, list: list)
        XCTAssertNotEqual(newAnchor, restored)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let thread = app.buttons["forum-home.row.t140001"]
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        requireVisible(newAnchor, in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P4 rotation resize and new reading position")
    }

    @MainActor
    private func checkReentryAndNewPosition() -> String {
        continueAfterFailure = false
        executionTimeAllowance = 180
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .forumContentCache, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        let thread = app.buttons["forum-home.row.t140001"]
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        let list = app.tables["thread-reader.scroll.t140001"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let image = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "thread-reader.content.image.")).firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        let imageY = image.frame.midY
        image.tap()
        UITestHarness.requirePresent(.mediaViewerClose, in: app)
        UITestHarness.tap(.mediaViewerClose, in: app)
        XCTAssertEqual(image.frame.midY, imageY, accuracy: 12)
        // Each fixture page has 15 compact floors; reach the third page through the production prefetch path.
        let thirdPage = app.descendants(matching: .any)["thread-reader.post.t140001.p470001.spost"].firstMatch
        for _ in 0..<24 {
            if thirdPage.exists, thirdPage.frame.intersects(list.frame), thirdPage.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(thirdPage.exists && thirdPage.frame.intersects(list.frame))
        if UIDevice.current.userInterfaceIdiom == .phone { positionOriginalTarget(in: app, list: list) }
        let anchor = visibleAnchor(in: app, list: list)
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertEqual(anchor, "thread-reader.post.t140001.p430001.spost")
        }
        print("U03 saved target: \(anchor)")
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U03 third page before leaving")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        let restored = list.descendants(matching: .any)[anchor].firstMatch
        requireVisible(anchor, in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U03 restored third page")
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "initial-restoration:idle"), object: list)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 5), .completed)
        XCTAssertTrue(restored.isHittable && restored.frame.intersects(list.frame))
        let before = restored.frame.minY
        list.swipeUp()
        XCTAssertTrue(!restored.isHittable || restored.frame.minY < before)
        let newAnchor = visibleAnchor(in: app, list: list)
        XCTAssertNotEqual(newAnchor, anchor)
        print("U03 saved new target: \(newAnchor)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        requireVisible(newAnchor, in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U03 newly saved position restored")
        return newAnchor
    }

    @MainActor
    private func requireVisible(_ rowID: String, in app: XCUIApplication) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            // A projection can replace both the table and hosting element. Resolve the
            // stable ID inside the current table on each observation, not a cached element.
            let table = app.tables["thread-reader.scroll.t140001"].firstMatch
            let row = table.descendants(matching: .any)[rowID].firstMatch
            return row.exists && row.isHittable && row.frame.intersects(table.frame) &&
                table.value as? String == "initial-restoration:idle"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                       "Expected same business floor after layout: \(rowID)")
    }

    @MainActor
    private func positionOriginalTarget(in app: XCUIApplication, list: XCUIElement) {
        let original = app.descendants(matching: .any)["thread-reader.post.t140001.p430001.spost"].firstMatch
        // Natural swipe velocity can stop on either side of this exact regression target.
        // Move the real list with bounded gestures, then verify the saved first-visible ID.
        for _ in 0..<4 {
            let rect = original.frame
            if rect.isEmpty {
                list.swipeDown(velocity: .slow)
                continue
            }
            if original.isHittable, rect.minY <= list.frame.minY,
               rect.maxY > list.frame.minY + rect.height / 2 { return }
            let distance = rect.minY - list.frame.minY + rect.height / 4
            let bounded = min(list.frame.height * 0.4, max(-list.frame.height * 0.4, distance))
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -bounded)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        }
    }

    @MainActor
    private func visibleAnchor(in app: XCUIApplication, list: XCUIElement) -> String {
        list.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "thread-reader.post.t140001."))
            .allElementsBoundByIndex.filter { !$0.frame.isEmpty && $0.frame.intersects(list.frame) && $0.isHittable }
            .min { $0.frame.minY < $1.frame.minY }?.identifier ?? "missing-reader-anchor"
    }
}
