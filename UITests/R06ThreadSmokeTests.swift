import XCTest

final class R06ThreadSmokeTests: XCTestCase {
    @MainActor
    func testForumChipStaysBesideBackAboveScrollingFloors() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .threadReaderParity)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let chip = app.navigationBars.descendants(matching: .any)
            .matching(identifier: "thread-reader.header.t100001").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        let avatar = chip.descendants(matching: .any)["thread-reader.forum-avatar"]
        XCTAssertEqual(avatar.value as? String, "已加载")
        XCTAssertGreaterThan(chip.staticTexts["组件验收吧"].frame.width, 20)
        XCTAssertLessThanOrEqual(chip.frame.maxY, list.frame.minY)
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertGreaterThan(chip.frame.minX, back.frame.midX)
        XCTAssertFalse(list.descendants(matching: .any)["thread-reader.header.t100001"].exists)
        let initialFrame = chip.frame
        let firstImage = image(1, postID: 60_001, app: app)
        let beforeY = firstImage.frame.minY
        list.swipeUp()
        XCTAssertTrue(chip.isHittable)
        XCTAssertEqual(chip.frame, initialFrame)
        XCTAssertTrue(!firstImage.isHittable || firstImage.frame.minY < beforeY - 30)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R06 fixed forum toolbar after scroll")
    }

    @MainActor
    func testFloorGridViewerSubpostsAndReplyBar() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .threadReaderParity)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let bar = app.descendants(matching: .any)["thread-reader.reply-bar"]
        XCTAssertTrue(bar.exists)
        XCTAssertEqual(list.frame.maxY, bar.frame.minY, accuracy: 1)
        XCTAssertFalse(app.buttons[UITestElementID.tabRecommendations.rawValue].exists)
        XCTAssertTrue(app.buttons["thread-reader.author.1"].label.contains("用户等级 14"))
        XCTAssertEqual(app.descendants(matching: .any)["thread-reader.avatar.p60001"].value as? String, "已加载")
        let images = (1...4).map { image($0, postID: 60_001, app: app) }
        XCTAssertTrue(images[3].waitForExistence(timeout: 5))
        XCTAssertEqual(images[0].frame.minY, images[1].frame.minY, accuracy: 1)
        XCTAssertEqual(images[2].frame.minY, images[3].frame.minY, accuracy: 1)
        XCTAssertGreaterThan(images[2].frame.minY, images[0].frame.minY)
        let before = images[3].frame.midY
        images[3].tap()
        XCTAssertTrue(app.staticTexts["4 / 4"].waitForExistence(timeout: 5))
        UITestHarness.tap(.mediaViewerClose, in: app)
        XCTAssertEqual(images[3].frame.midY, before, accuracy: 12)
        let all = app.buttons["thread-reader.subposts.all.p60001"]
        reveal(all, in: list)
        XCTAssertTrue(all.isHittable)
        XCTAssertEqual(all.label, "查看全部 7 条回复")
        XCTAssertFalse(app.descendants(matching: .any)["thread-reader.subpost.t100001.p600013.ssubPost"].exists)
        let originalY = all.frame.midY
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R06 four images three previews")
        all.tap()
        UITestHarness.requirePresent(.routeSubposts, in: app)
        XCTAssertEqual(app.descendants(matching: .any)[UITestElementID.routeSubposts.rawValue].value as? String,
                       "帖子 \(100_001.formatted())，楼层 \(60_001.formatted())")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertEqual(all.frame.midY, originalY, accuracy: 12)
        app.buttons["thread-reader.compose"].tap()
        XCTAssertTrue(app.alerts["功能暂未开放"].waitForExistence(timeout: 5))
        app.alerts.buttons["知道了"].tap()
        let fifth = image(5, postID: 60_002, app: app)
        reveal(fifth, in: list)
        XCTAssertTrue(fifth.isHittable)
        let fourth = image(4, postID: 60_002, app: app)
        XCTAssertEqual(fourth.frame.minY, fifth.frame.minY, accuracy: 1)
        XCTAssertFalse(app.buttons["thread-reader.subposts.all.p60002"].exists)
        fifth.tap()
        XCTAssertTrue(app.staticTexts["5 / 5"].waitForExistence(timeout: 5))
        UITestHarness.tap(.mediaViewerClose, in: app)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            UITestHarness.requirePresent(.layoutRegular, in: app)
            XCTAssertTrue(list.isHittable)
            XCTAssertEqual(list.frame.maxY, bar.frame.minY, accuracy: 1)
        }
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R06 five images and reader")
        for (floor, count) in [(3, 1), (4, 2), (5, 3), (6, 8)] {
            let last = image(count, postID: 60_000 + floor, app: app)
            reveal(last, in: list)
            XCTAssertTrue(last.isHittable)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R06 grid \(count) photos")
        }
    }

    @MainActor
    private func image(_ index: Int, postID: Int, app: XCUIApplication) -> XCUIElement {
        let scope = postID == 60_001 ? "firstPost" : "post"
        return app.buttons["thread-reader.content.image.t100001.p\(postID).s\(scope).n\(index).action"]
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in list: XCUIElement) {
        for _ in 0..<6 {
            if element.exists, element.frame.intersects(list.frame), element.isHittable { return }
            list.swipeUp()
        }
    }
}
