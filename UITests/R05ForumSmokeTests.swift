import XCTest

final class R05ForumSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testForumTabsSortMediaPagingAndReturnPosition() {
        executionTimeAllowance = 150
        let app = openForum()
        requireSelected("latest", app: app)
        requireLoaded("forum-home.avatar", app: app)
        requireLoaded("forum-home.author.t140003", app: app)
        for index in 1...3 {
            requireLoaded("tieba.media-grid.forum.t140003.media.\(index)", app: app)
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 header pinned multi-photo")
        let target = app.buttons["forum-home.row.t140003"]
        let before = target.frame.midY
        target.tap()
        XCTAssertTrue(app.descendants(matching: .any)["thread-reader.screen.t140003"].waitForExistence(timeout: 5))
        UITestHarness.tapSystemBack(in: app, returningTo: .forumHomeHeader)
        XCTAssertTrue(target.isHittable)
        XCTAssertEqual(target.frame.midY, before, accuracy: 12)
        tap("forum-home.tab.good", app: app)
        requireSelected("good", app: app)
        XCTAssertTrue(app.buttons["forum-home.good.7"].waitForExistence(timeout: 5))
        tap("forum-home.good.7", app: app)
        XCTAssertTrue(app.buttons["forum-home.row.t140001"].label.contains("精华7"))
        let goodList = app.tables["forum-home.list"].firstMatch
        goodList.swipeUp()
        let goodRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "forum-home.row.t"))
            .allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(goodRow)
        let goodID = goodRow?.identifier ?? ""
        let goodY = goodRow?.frame.midY ?? 0
        goodList.swipeLeft()
        requireSelected("category.21", app: app)
        XCTAssertTrue(app.buttons["forum-home.row.t140001"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["forum-home.row.t140001"].label.contains("吧友互助"))
        app.tables["forum-home.list"].firstMatch.swipeRight()
        requireSelected("good", app: app)
        XCTAssertTrue(app.buttons[goodID].isHittable)
        XCTAssertEqual(app.buttons[goodID].frame.midY, goodY, accuracy: 12)
        tap("forum-home.tab.latest", app: app)
        tap("forum-home.sort", app: app)
        tap("forum-home.sort.1", app: app)
        let created = app.buttons["forum-home.row.t140001"]
        XCTAssertTrue(created.waitForExistence(timeout: 5))
        XCTAssertTrue(created.label.contains("发帖排序"))
        let list = app.tables["forum-home.list"].firstMatch
        let thirdPage = app.buttons["forum-home.row.t140208"]
        for _ in 0..<20 {
            if thirdPage.exists, thirdPage.frame.intersects(list.frame), thirdPage.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(thirdPage.isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 latest third page")
        tap("forum-home.compose", app: app)
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        tap("composer.cancel", app: app)
        tap("forum-home.search", app: app)
        UITestHarness.requirePresent(.searchRoot, in: app)
        tap("forum-home.search.close", app: app)
        XCTAssertTrue(thirdPage.isHittable)
    }

    @MainActor
    func testIPadForumTabsAndWidthChange() {
        executionTimeAllowance = 100
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = openForum()
        requireLandscape(app)
        requireSelected("latest", app: app)
        app.tables["forum-home.list"].firstMatch.swipeLeft()
        requireSelected("good", app: app)
        app.tables["forum-home.list"].firstMatch.swipeLeft()
        requireSelected("category.21", app: app)
        app.tables["forum-home.list"].firstMatch.swipeUp()
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 iPad landscape category")
        XCUIDevice.shared.orientation = .portrait
        requireSelected("category.21", app: app)
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.height > app.frame.width
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 5), .completed)
        XCTAssertTrue(app.tables["forum-home.list"].firstMatch.isHittable)
        tap("forum-home.tab.latest", app: app)
        requireSelected("latest", app: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R05 iPad portrait header")
    }

    @MainActor
    private func requireLandscape(_ app: XCUIApplication) {
        let header = app.descendants(matching: .any)["forum-home.header"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height && header.frame.maxX <= app.frame.maxX + 1
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed)
    }

    @MainActor
    private func openForum() -> XCUIApplication {
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        tap("followed-forums.row.f13001", app: app)
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        return app
    }

    @MainActor
    private func tap(_ id: String, app: XCUIApplication) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        XCTAssertTrue(button.isHittable, id)
        button.tap()
    }

    @MainActor
    private func requireSelected(_ id: String, app: XCUIApplication) {
        let button = app.buttons["forum-home.tab.\(id)"]
        let predicate = NSPredicate(format: "isSelected == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: button)], timeout: 5), .completed)
    }

    @MainActor
    private func requireLoaded(_ id: String, app: XCUIApplication) {
        let element = app.descendants(matching: .any)[id]
        let predicate = NSPredicate(format: "value == %@", "已加载")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 5), .completed, id)
    }
}
