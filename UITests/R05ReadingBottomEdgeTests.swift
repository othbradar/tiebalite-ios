import XCTest

final class R05ReadingBottomEdgeTests: XCTestCase {
    @MainActor
    func testReadingViewportReachesBottomEdge() {
        continueAfterFailure = false
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        XCUIDevice.shared.orientation = isPad ? .landscapeLeft : .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        UITestHarness.tap(.followedForumsFirstRow, in: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        var gaps = [bottomGap(app.tables["forum-home.list"].firstMatch, app: app)]
        let thread = app.buttons["forum-home.row.t140003"]
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        let reader = app.tables["thread-reader.scroll.t140003"].firstMatch
        gaps.append(bottomGap(reader, app: app))
        if isPad {
            XCUIDevice.shared.orientation = .portrait
            UITestHarness.requirePresent(.layoutCompact, in: app)
            gaps.append(bottomGap(reader, app: app))
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 reading bottom edge")
        UITestHarness.tapSystemBack(in: app, returningTo: .forumHomeHeader)
        gaps.append(bottomGap(app.tables["forum-home.list"].firstMatch, app: app))
        UITestHarness.tapSystemBack(in: app, returningTo: .followedForumsFirstRow)
        UITestHarness.requireTabSelected(.followedForums, in: app)
        XCTAssertTrue(gaps.allSatisfy { abs($0) <= 1 }, "Reading viewport bottom gaps: \(gaps)")
    }

    @MainActor
    private func bottomGap(_ list: XCUIElement, app: XCUIApplication) -> CGFloat {
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        if list.identifier.hasPrefix("thread-reader.") {
            let composer = app.descendants(matching: .any)["thread-reader.reply-bar"]
            XCTAssertTrue(composer.waitForExistence(timeout: 5))
            return composer.frame.minY - list.frame.maxY
        }
        return app.frame.maxY - list.frame.maxY
    }
}
