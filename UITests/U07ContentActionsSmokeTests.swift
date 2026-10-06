import XCTest

final class U07ContentActionsSmokeTests: XCTestCase {
    @MainActor
    func testFeedForumTagAndAbstractLinkUseIndependentNativeRoutes() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .dynamicFeedParity)
        let forum = app.buttons["recommendations.forum.t100001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        UITestHarness.requirePresent(.routeForum, in: app)
        XCTAssertFalse(app.tables["thread-reader.scroll.t100001"].exists)
        UITestHarness.tapSystemBack(in: app, returningTo: .recommendationsFirstRow)
        let link = app.textViews["recommendations.content.t100001"].links.firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.tables["thread-reader.scroll.t100002"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tables["thread-reader.scroll.t100001"].exists)
        UITestHarness.tapSystemBack(in: app, returningTo: .recommendationsFirstRow)
        app.buttons["recommendations.share.t100001"].tap()
        requireShareSheet(in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U07 feed share system anchor")
    }

    @MainActor
    func testBodyAndSubpostLinksReachProductionRoutesAndMoreShares() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let bodyLink = list.links["打开关联帖子"].firstMatch
        XCTAssertTrue(bodyLink.waitForExistence(timeout: 5))
        bodyLink.tap()
        XCTAssertTrue(app.tables["thread-reader.scroll.t100002"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.links["@固定用户"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["user-profile.screen.91"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        app.buttons["thread-reader.open-forum"].tap()
        UITestHarness.requirePresent(.routeForum, in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let allReplies = app.buttons["thread-reader.subposts.all.p120001"]
        for _ in 0..<8 where !allReplies.isHittable { list.swipeUp() }
        XCTAssertTrue(allReplies.isHittable)
        allReplies.tap()
        let subposts = app.tables["subposts.list"]
        XCTAssertTrue(subposts.waitForExistence(timeout: 5))
        let replyLink = subposts.links["打开关联帖子"].firstMatch
        XCTAssertTrue(replyLink.waitForExistence(timeout: 5))
        replyLink.tap()
        XCTAssertTrue(app.tables["thread-reader.scroll.t100002"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(subposts.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(allReplies.isHittable)
        XCTAssertFalse(app.buttons["thread-reader.compose.agree"].exists)
        app.buttons["thread-reader.compose.more"].tap()
        XCTAssertTrue(app.buttons["thread-reader.compose.more.copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["thread-reader.compose.more.reload"].exists)
        app.buttons["thread-reader.compose.more.share"].tap()
        requireShareSheet(in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U07 reader share system anchor")
    }

    @MainActor
    private func requireShareSheet(in app: XCUIApplication) {
        let copy = app.cells.matching(NSPredicate(format: "label == 'Copy' OR label == '拷贝' OR label == '复制'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(copy.isHittable)
    }
}
