import XCTest

final class R08SubpostsSmokeTests: XCTestCase {
    @MainActor
    func testFullRepliesPaginateOpenProfileAndReturnToOriginalFloor() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let parentList = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(parentList.waitForExistence(timeout: 5))
        let all = app.buttons["thread-reader.subposts.all.p120001"]
        reveal(all, in: parentList)
        let originalY = all.frame.midY
        all.tap()
        let list = app.tables["subposts.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["30 条回复"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["subposts.parent"].exists)
        XCTAssertFalse(app.buttons[UITestElementID.tabRecommendations.rawValue].exists)
        let emoticons = app.textViews["thread-reader.content.node.t100001.p10001.ssubPost.n0"]
        XCTAssertTrue(emoticons.waitForExistence(timeout: 5))
        for name in ["大笑", "笑哭", "赞同", "滑稽", "捂脸"] {
            XCTAssertTrue(emoticons.label.contains(name + "表情"))
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R08 parent and first replies")

        let middle = app.buttons["subposts.reply.10018.author"]
        reveal(middle, in: list)
        XCTAssertEqual(app.buttons.matching(identifier: "subposts.reply.10015.author").count, 1)
        let middleY = middle.frame.midY
        middle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["user-profile.screen.108"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(middle.isHittable)
        XCTAssertEqual(middle.frame.midY, middleY, accuracy: 12)
        let reply = app.buttons["subposts.reply.10018.action"]
        reveal(reply, in: list)
        reply.tap()
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 样本回复者18")
        app.buttons["composer.cancel"].tap()
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R08 middle of second page")
        let last = app.buttons["subposts.reply.10030.author"]
        reveal(last, in: list)
        reveal(app.staticTexts["subposts.end"], in: list)
        XCTAssertTrue(app.staticTexts["已经到底了"].exists)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            XCTAssertTrue(list.isHittable)
            XCTAssertGreaterThan(list.frame.width, 200)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R08 iPad landscape replies")
            XCUIDevice.shared.orientation = .portrait
            UITestHarness.requirePresent(.layoutCompact, in: app)
            XCTAssertTrue(list.isHittable)
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(parentList.waitForExistence(timeout: 5))
        XCTAssertTrue(all.isHittable)
        XCTAssertEqual(all.frame.midY, originalY, accuracy: 12)
        all.tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        reveal(app.buttons["subposts.reply.10018.author"], in: list)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R08 final middle")
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in list: XCUIElement) {
        for _ in 0..<16 {
            if element.exists, !element.frame.isEmpty, list.frame.contains(element.frame), element.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
