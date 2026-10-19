import XCTest

final class U12ProfileSmokeTests: XCTestCase {
    @MainActor
    func testUnavailableForumsShowNeutralTextAndAllowBack() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .dynamicFeedParity, startingTab: .settings)
        let account = app.buttons["personal.open-profile"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        app.buttons["profile.open.threads"].tap()
        let thread = app.buttons["profile.post.100001"]
        XCTAssertTrue(thread.waitForExistence(timeout: 5))
        thread.tap()
        let author = app.buttons["thread-reader.author.1100001"]
        XCTAssertTrue(author.waitForExistence(timeout: 5))
        author.tap()
        let forums = app.buttons["profile.open.forums"]
        XCTAssertTrue(forums.waitForExistence(timeout: 5))
        forums.tap()
        let message = app.staticTexts["profile.forums.unavailable"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "暂无可查看的关注吧")
        XCTAssertFalse(app.staticTexts["加载失败"].exists)
        XCTAssertFalse(app.buttons["重试"].exists)
        XCTAssertFalse(app.buttons["profile.load-more"].exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U12 unavailable forums neutral state")
        back(app)
        XCTAssertTrue(forums.waitForExistence(timeout: 5))
    }

    @MainActor
    func testOwnProfileSubpagesAndThreadReturnKeepPosition() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .dynamicFeedParity, startingTab: .settings)
        let account = app.buttons["personal.open-profile"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        account.tap()
        let threadsButton = app.buttons["profile.open.threads"]
        XCTAssertTrue(threadsButton.waitForExistence(timeout: 5))
        threadsButton.tap()
        let list = app.tables["profile.threads.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let row = list.buttons["profile.post.100005"]
        for _ in 0..<5 {
            if row.exists && row.isHittable { break }
            list.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        let y = row.frame.midY
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["thread-reader.screen.t100005"].firstMatch.waitForExistence(timeout: 5))
        back(app)
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        XCTAssertEqual(row.frame.midY, y, accuracy: 12)
        back(app)
        app.buttons["profile.open.replies"].tap()
        XCTAssertTrue(app.tables["profile.replies.list"].waitForExistence(timeout: 5))
        let reply = app.buttons["profile.post.130001"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reply.tap()
        XCTAssertTrue(app.textViews["thread-reader.content.node.t100001.p130001.spost.n0"].waitForExistence(timeout: 5))
        back(app)
        back(app)
        app.buttons["profile.open.forums"].tap()
        let forum = app.buttons["profile.forum.13001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        XCTAssertTrue(app.tables["forum-home.list"].firstMatch.waitForExistence(timeout: 5))
        back(app)
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U12 profile lists and existing destinations")
    }
    @MainActor private func back(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.matching(identifier: "BackButton").firstMatch
        if back.exists { back.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
    }
}
