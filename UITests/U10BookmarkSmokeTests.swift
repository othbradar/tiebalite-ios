import XCTest

final class U10BookmarkSmokeTests: XCTestCase {
    @MainActor
    func testEmptyBookmarksKeepTabBarAtBottom() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tapTab(.settings, in: app)
        let tab = app.buttons["app.tab.settings"]
        let originalY = tab.frame.midY
        app.buttons["personal.bookmarks"].tap()
        let empty = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "暂无本机书签")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        let remainsAtBottom = NSPredicate { _, _ in abs(tab.frame.midY - originalY) < 1 }
        expectation(for: remainsAtBottom, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(tab.frame.midY, originalY, accuracy: 1)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U10 empty bookmarks")
    }

    @MainActor
    func testFloorBookmarkFromReaderToMyListAndBack() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let table = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        let author = app.buttons["thread-reader.author.100004"]
        for _ in 0..<8 {
            if author.exists, author.isHittable, table.frame.contains(author.frame) { break }
            table.swipeUp()
        }
        XCTAssertTrue(author.isHittable)
        author.press(forDuration: 1)
        let add = app.buttons["bookmark.floor.130001"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        add.tap()
        XCTAssertTrue(app.alerts["已保存到本机书签"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].firstMatch.tap()
        UITestHarness.tapSystemBack(in: app, returningTo: .recommendationsFirstRow)
        UITestHarness.tapTab(.notifications, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["app.root.notifications"].firstMatch.waitForExistence(timeout: 5))
        UITestHarness.tapTab(.settings, in: app)
        app.buttons["personal.bookmarks"].tap()
        let row = app.buttons["bookmarks.row.100001"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("第 3 楼"))
        row.tap()
        let target = app.textViews["thread-reader.content.node.t100001.p130001.spost.n0"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(target.isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U10 saved floor")
        let back = app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch
        if back.exists { back.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let remove = app.buttons["移除"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.alerts["已移除本机书签"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].firstMatch.tap()
        XCTAssertFalse(row.exists)
    }
    @MainActor
    func testCloudFloorFavoriteSyncNavigationAndCancel() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let table = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        let author = app.buttons["thread-reader.author.100004"]
        for _ in 0..<8 {
            if author.exists, author.isHittable, table.frame.contains(author.frame) { break }
            table.swipeUp()
        }
        XCTAssertTrue(author.isHittable)
        author.press(forDuration: 1)
        let add = app.buttons["favorite.floor.130001"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), app.debugDescription)
        add.tap()
        XCTAssertTrue(app.alerts["已收藏"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].firstMatch.tap()
        UITestHarness.tapSystemBack(in: app, returningTo: .recommendationsFirstRow)
        UITestHarness.tapTab(.notifications, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["app.root.notifications"].firstMatch.waitForExistence(timeout: 5))
        UITestHarness.tapTab(.settings, in: app)
        app.buttons["personal.favorites"].tap()
        let row = app.buttons["favorites.row.100001"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["favorites.share.t100001"].exists)
        XCTAssertTrue(app.buttons["favorites.reply.t100001"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["favorites.author.t100001"].firstMatch.exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U10 favorites forum feed style")
        row.tap()
        let target = app.textViews["thread-reader.content.node.t100001.p130001.spost.n0"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(target.isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U10 cloud saved floor")
        let back = app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch
        if back.exists { back.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let remove = app.buttons["取消收藏"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.alerts["已取消收藏"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].firstMatch.tap()
        XCTAssertFalse(row.exists)
        let empty = app.staticTexts["favorites.empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        XCTAssertEqual(empty.label, "暂无收藏")
        XCTAssertLessThan(empty.frame.height, 80)
        XCTAssertFalse(app.images["star"].exists)
    }
}
