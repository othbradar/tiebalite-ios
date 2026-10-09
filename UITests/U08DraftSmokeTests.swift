import XCTest

final class U08DraftSmokeTests: XCTestCase {
    @MainActor
    func testSuccessfulReplyClosesComposerWithoutConfirmationAndClearsOnlySentDraft() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        app.terminate()
        app.launchEnvironment["U08_REPLY_REFRESH"] = "1"
        app.launch()
        UITestHarness.tapTab(.recommendations, in: app)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let first = app.descendants(matching: .any)["thread-reader.post.t100001.p110001.sfirstPost"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let originalY = first.frame.minY
        app.buttons["thread-reader.compose"].tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("U08 local reply")
        // The local writer decodes a synthetic beta3-supported receipt through the production pipeline.
        app.buttons["composer.send"].tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(list.isHittable)
        let published = app.textViews["thread-reader.content.node.t100001.p900002.spost.n0"]
        XCTAssertTrue(published.waitForExistence(timeout: 5))
        XCTAssertEqual(published.value as? String, "U08 mock published reply")
        XCTAssertTrue(published.isHittable)
        XCTAssertEqual(first.frame.minY, originalY, accuracy: 12)
        let reply = app.buttons["thread-reader.reply.p900002"]
        let avatar = app.descendants(matching: .any)["thread-reader.avatar.p900002"].firstMatch
        XCTAssertTrue(avatar.exists)
        XCTAssertEqual(reply.frame.minX, avatar.frame.maxX + 8, accuracy: 1)
        XCTAssertEqual(published.frame.minX, reply.frame.minX, accuracy: 1)
        XCTAssertTrue(app.descendants(matching: .any)["thread-reader.agree.p900002"].firstMatch.exists)
        let replyX = reply.frame.minX
        app.buttons["thread-reader.compose.more"].tap()
        app.buttons["thread-reader.compose.more.reload"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "第 2 楼"))
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(reply.frame.minX, replyX, accuracy: 1)
        XCTAssertEqual(published.frame.minX, replyX, accuracy: 1)
        app.buttons["thread-reader.compose"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "")
        app.buttons["composer.cancel"].tap()
    }

    @MainActor
    func testTextEmoticonAndPhotoSurviveProcessRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .settings)
        app.terminate()
        app.launchEnvironment["U08_FIXTURE_DRAFT"] = UUID().uuidString
        app.launch()
        openDraft(app)
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("U08 durable ")
        app.buttons["composer.toggle-emoticons"].tap()
        app.buttons["composer.emoticon.image_emoticon1"].tap()
        let text = editor.value as? String
        let photos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "composer.photo.remove."))
        let identifiers = photos.allElementsBoundByIndex.map(\.identifier)
        XCTAssertEqual(identifiers.count, 1)
        let status = app.staticTexts["composer.draft-status"]
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "草稿已保留"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.buttons["composer.cancel"].tap()
        app.terminate()
        app.launch()
        openDraft(app)
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, text)
        XCTAssertEqual(photos.allElementsBoundByIndex.map(\.identifier), identifiers)
        XCTAssertTrue(app.buttons["composer.send"].isEnabled)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U08 persisted text emoticon photo")
        app.buttons["composer.cancel"].tap()
    }

    @MainActor
    private func openDraft(_ app: XCUIApplication) {
        UITestHarness.tapTab(.settings, in: app)
        let settings = app.buttons["personal.open-settings"]
        if settings.exists { settings.tap() }
        let gallery = app.buttons["app.debug.open-component-gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))
        for _ in 0..<4 where !gallery.isHittable { app.swipeUp() }
        XCTAssertTrue(gallery.isHittable)
        gallery.tap()
        app.buttons["r10.gallery.open"].tap()
        let button = app.buttons["r10.select.1"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }
}
