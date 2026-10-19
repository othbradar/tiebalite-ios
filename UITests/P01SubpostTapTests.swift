import XCTest

final class P01SubpostTapTests: XCTestCase {
    @MainActor
    func testFloorAndSubreplyMetadataFollowContentWithoutEmptyHeaderLine() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        let body = app.textViews["thread-reader.content.node.t100001.p120001.spost.n0"]
        reveal(body, in: list)
        let footer = app.staticTexts["thread-reader.metadata.p120001"]
        XCTAssertTrue(footer.waitForExistence(timeout: 5))
        XCTAssertEqual(footer.label, "第2楼 09-24 湖南")
        let author = app.buttons["thread-reader.author.100003"]
        XCTAssertEqual(body.frame.minY, author.frame.maxY, accuracy: 1)
        XCTAssertFalse(author.label.contains("09-24"))
        let lastPreview = app.textViews["thread-reader.subpost.t100001.p120003.ssubPost"]
        XCTAssertGreaterThan(footer.frame.minY, lastPreview.frame.maxY)
        XCTAssertEqual(footer.frame.minX, body.frame.minX, accuracy: 1)
        lastPreview.tap()
        let subposts = app.tables["subposts.list"]
        XCTAssertTrue(subposts.waitForExistence(timeout: 5))
        let parentBody = app.textViews["thread-reader.content.node.t100001.p120001.spost.n0"]
        let parentFooter = app.staticTexts["subposts.parent.metadata"]
        XCTAssertEqual(parentFooter.label, "第2楼 09-24")
        XCTAssertGreaterThan(parentFooter.frame.minY, parentBody.frame.maxY)
        let child = app.textViews["thread-reader.content.node.t100001.p10002.ssubPost.n0"]
        reveal(child, in: subposts)
        let childFooter = app.staticTexts["subposts.reply.10002.metadata"]
        XCTAssertEqual(childFooter.label, "09-24 辽宁")
        XCTAssertGreaterThan(childFooter.frame.minY, child.frame.maxY)
        XCTAssertEqual(childFooter.frame.minX, child.frame.minX, accuracy: 1)
        XCTAssertEqual(child.frame.minY, app.buttons["subposts.reply.10002.author"].frame.maxY, accuracy: 1)
        child.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 样本回复者2")
    }

    @MainActor
    func testFloorBodyOpensItsComposerWithoutGreyReplyLabels() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        let body = app.textViews["thread-reader.content.node.t100001.p120001.spost.n0"]
        reveal(body, in: list)
        let originalY = body.frame.midY
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 Fixture 读者 1")
        app.buttons["composer.cancel"].tap()
        XCTAssertEqual(body.frame.midY, originalY, accuracy: 12)
        XCTAssertFalse(app.buttons["thread-reader.reply.p120001"].exists)
        XCTAssertFalse(list.buttons.matching(NSPredicate(format: "label == %@", "回复")).firstMatch.exists)
        let preview = app.textViews["thread-reader.subpost.t100001.p120002.ssubPost"]
        reveal(preview, in: list)
        preview.tap()
        let subposts = app.tables["subposts.list"]
        XCTAssertTrue(subposts.waitForExistence(timeout: 5))
        XCTAssertFalse(editor.exists)
        let subBody = app.textViews["thread-reader.content.node.t100001.p10002.ssubPost.n0"]
        reveal(subBody, in: subposts)
        XCTAssertFalse(app.buttons["subposts.reply.10002.action"].exists)
        XCTAssertFalse(subposts.buttons.matching(NSPredicate(format: "label == %@", "回复")).firstMatch.exists)
        subBody.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 样本回复者2")
    }

    @MainActor
    func testSmallPreviewTextOpensThirdLevelThenSpecificBodyOpensComposer() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let parent = app.tables["thread-reader.scroll.t100001"]
        let preview = app.textViews["thread-reader.subpost.t100001.p130002.ssubPost"]
        reveal(preview, in: parent)
        preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: preview.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 0, dy: -180)))
        XCTAssertFalse(app.tables["subposts.list"].exists)
        parent.swipeDown()
        reveal(preview, in: parent)
        let originalY = preview.frame.midY
        preview.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
        let list = app.tables["subposts.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        let body = app.textViews["thread-reader.content.node.t100001.p10002.ssubPost.n0"]
        reveal(body, in: list)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 样本回复者2")
        let editor = app.textViews["composer.body"]
        editor.tap()
        editor.typeText("P01 retained draft")
        app.buttons["composer.cancel"].tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let firstBody = app.textViews["thread-reader.content.node.t100001.p10001.ssubPost.n0"]
        reveal(firstBody, in: list)
        firstBody.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.1)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 样本回复者1")
        XCTAssertEqual(editor.value as? String, "")
        app.buttons["composer.cancel"].tap()
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "P01 retained draft")
        app.buttons["composer.cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.isHittable)
        XCTAssertEqual(preview.frame.midY, originalY, accuracy: 12)
        XCTAssertFalse(app.buttons["thread-reader.subposts.all.p130001"].exists)
    }

    @MainActor
    func testOrdinarySubreplyBodyReplacesReplyButtonAsAnEntry() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let parent = app.tables["thread-reader.scroll.t100001"]
        let preview = app.textViews["thread-reader.subpost.t100001.p120002.ssubPost"]
        reveal(preview, in: parent)
        XCTAssertFalse(app.buttons["thread-reader.subposts.all.p120001"].exists)
        preview.tap()
        let list = app.tables["subposts.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let link = list.links["打开关联帖子"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.tables["thread-reader.scroll.t100002"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.links["@固定用户"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["user-profile.screen.91"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let body = app.textViews["thread-reader.content.node.t100001.p10002.ssubPost.n0"]
        reveal(body, in: list)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["composer.recipient"].label, "回复 样本回复者2")
    }

    @MainActor
    func testPreviewBackgroundOnThirdPageReturnsToSameParent() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let parent = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        app.buttons["thread-reader.compose.more"].tap()
        app.buttons["thread-reader.jump-page"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("3")
        app.alerts.buttons["thread-reader.jump-confirm"].firstMatch.tap()
        let preview = app.descendants(matching: .any)["thread-reader.subposts.preview.p430001"].firstMatch
        reveal(preview, in: parent)
        let originalY = preview.frame.midY
        // The 12pt padding is real background, outside the selectable text.
        preview.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 5, dy: 5)).tap()
        let list = app.tables["subposts.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.isHittable)
        XCTAssertEqual(preview.frame.midY, originalY, accuracy: 12)
        XCTAssertTrue((app.buttons["thread-reader.compose.more"].value as? String)?.contains("page:3") == true)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P01 page three return without old entry")
    }

    @MainActor
    func testBodyDragAndLongPressKeepNativeReadingInteractions() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let preview = app.textViews["thread-reader.subpost.t100001.p120002.ssubPost"]
        reveal(preview, in: app.tables["thread-reader.scroll.t100001"])
        preview.tap()
        let list = app.tables["subposts.list"]
        let body = app.textViews["thread-reader.content.node.t100001.p10002.ssubPost.n0"]
        reveal(body, in: list)
        let originalY = body.frame.midY
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 0, dy: -180)))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        XCTAssertLessThan(body.frame.midY, originalY)
        list.swipeDown()
        reveal(body, in: list)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).press(forDuration: 1)
        XCTAssertFalse(app.textViews["composer.body"].exists)
        let copy = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["Copy", "拷贝", "复制"]))
            .firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "P01 native subreply selection menu")
    }

    @MainActor
    func testFloorImageAuthorAndTextSelectionRemainIndependent() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.links["打开关联帖子"].firstMatch.tap()
        XCTAssertTrue(app.tables["thread-reader.scroll.t100002"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let body = app.textViews["thread-reader.content.node.t100001.p130001.spost.n0"]
        reveal(body, in: list)
        let image = app.buttons["thread-reader.content.image.t100001.p130001.spost.n1.action"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), app.debugDescription)
        // A tall inline image need not fit in the viewport to open its viewer.
        image.tap()
        UITestHarness.requirePresent(.mediaViewerClose, in: app)
        XCTAssertFalse(app.textViews["composer.body"].exists)
        UITestHarness.tap(.mediaViewerClose, in: app)
        let author = app.buttons["thread-reader.author.100004"]
        if !author.isHittable { list.swipeDown() }
        author.tap()
        XCTAssertTrue(app.descendants(matching: .any)["user-profile.screen.100004"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(body, in: list)
        let originalY = body.frame.midY
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: body.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 0, dy: -180)))
        XCTAssertFalse(app.textViews["composer.body"].exists)
        XCTAssertLessThan(body.frame.midY, originalY)
        list.swipeDown()
        reveal(body, in: list)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).press(forDuration: 1)
        XCTAssertFalse(app.textViews["composer.body"].exists)
        let copy = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["Copy", "拷贝", "复制"]))
            .firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in list: XCUIElement) {
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if element.exists, list.frame.contains(element.frame), element.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
