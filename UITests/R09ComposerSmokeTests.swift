import XCTest

final class R09ComposerSmokeTests: XCTestCase {
    @MainActor
    func testFourComposerLayoutsAndMockSuccessFailure() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .settings)
        UITestHarness.tap(.debugOpenGallery, in: app)
        app.buttons["r09.gallery.open"].tap()
        for kind in ["thread", "threadReply", "floorReply", "subpostReply"] {
            let entry = app.buttons["r09.open.\(kind)"]
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            let editor = app.textViews["composer.body"]
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            XCTAssertEqual(app.textFields["composer.title"].exists, kind == "thread")
            XCTAssertEqual(app.staticTexts["composer.recipient"].exists, kind == "floorReply" || kind == "subpostReply")
            XCTAssertFalse(app.buttons["composer.send"].isEnabled)
            editor.tap()
            editor.typeText("R09 local sample")
            XCTAssertTrue(app.buttons["composer.send"].isEnabled)
            if app.keyboards.firstMatch.exists {
                XCTAssertLessThanOrEqual(editor.frame.minY + 44, app.keyboards.firstMatch.frame.minY)
            }
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 composer \(kind)")
            app.buttons["composer.cancel"].tap()
        }
        app.switches["r09.mock.failure"].switches.firstMatch.tap()
        XCTAssertEqual(app.switches["r09.mock.failure"].value as? String, "1")
        app.buttons["r09.open.threadReply"].tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Preserved failed draft")
        // This page owns a FixtureTextWriteRepository and has no Live network dependency.
        app.buttons["composer.send"].tap()
        XCTAssertTrue(app.staticTexts["composer.failure"].waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "Preserved failed draft")
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 mock failure retains draft")
        app.buttons["composer.cancel"].tap()
        app.switches["r09.mock.failure"].switches.firstMatch.tap()
        app.buttons["r09.open.threadReply"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Mock success")
        app.buttons["composer.send"].tap()
        let result = app.staticTexts["r09.mock.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("模拟发送成功"))
        XCTAssertTrue(result.label.contains("900002"))
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 mock success closes composer")
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.buttons["r09.open.subpostReply"].tap()
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(editor.isHittable)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 iPad landscape composer")
        }
    }

    @MainActor
    func testReadingEntriesAndCancelledDraftReturn() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow)
        UITestHarness.tap(.recommendationsFirstRow, in: app)
        let list = app.tables["thread-reader.scroll.t100001"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        app.buttons["thread-reader.compose"].tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Retain this draft")
        app.buttons["composer.cancel"].tap()
        app.buttons["thread-reader.compose"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "Retain this draft")
        app.buttons["composer.cancel"].tap()
        let reply = app.buttons["thread-reader.reply.p110001"]
        reveal(reply, in: list)
        reply.tap()
        XCTAssertTrue(app.staticTexts["composer.recipient"].waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "")
        app.buttons["composer.cancel"].tap()
        let all = app.buttons["thread-reader.subposts.all.p120001"]
        reveal(all, in: list)
        all.tap()
        let subposts = app.tables["subposts.list"]
        XCTAssertTrue(subposts.waitForExistence(timeout: 5))
        let subReply = app.buttons["subposts.reply.10001.action"]
        reveal(subReply, in: subposts)
        subReply.tap()
        XCTAssertTrue(app.staticTexts["composer.recipient"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["回复楼中楼"].exists)
        app.buttons["composer.cancel"].tap()
        XCTAssertTrue(subposts.isHittable)
    }

    @MainActor
    func testForumEntryReturnsToSameListAfterCancel() {
        continueAfterFailure = false
        let app = UITestHarness.launch(scenario: .forumHomeParity, startingTab: .followedForums)
        let forum = app.buttons["followed-forums.row.f13001"]
        XCTAssertTrue(forum.waitForExistence(timeout: 5))
        forum.tap()
        UITestHarness.requirePresent(.forumHomeHeader, in: app)
        let row = app.buttons["forum-home.row.t140003"]
        let originalY = row.frame.midY
        app.buttons["forum-home.compose"].tap()
        XCTAssertTrue(app.textViews["composer.body"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["composer.title"].exists)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 forum new thread entry")
        app.buttons["composer.cancel"].tap()
        XCTAssertTrue(row.isHittable)
        XCTAssertEqual(row.frame.midY, originalY, accuracy: 12)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in list: XCUIElement) {
        for _ in 0..<7 {
            if element.exists, !element.frame.isEmpty, list.frame.contains(element.frame), element.isHittable { return }
            list.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}

final class R09ComposerIPadSmokeTests: XCTestCase {
    @MainActor
    func testReplyEditorAdaptsToWidthAndKeyboard() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .settings)
        UITestHarness.tap(.debugOpenGallery, in: app)
        app.buttons["r09.gallery.open"].tap()
        let entry = app.buttons["r09.open.subpostReply"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("iPad local sample")
        XCTAssertTrue(app.buttons["composer.send"].isEnabled)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 iPad portrait keyboard")
        XCUIDevice.shared.orientation = .landscapeLeft
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: editor)
        let result = XCTWaiter.wait(for: [ready], timeout: 5)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 iPad rotation evidence")
        if result != .completed {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "R09 isolated rotation hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(editor.value as? String, "iPad local sample")
        XCTAssertTrue(app.buttons["composer.cancel"].isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R09 iPad landscape keyboard")
        app.buttons["composer.cancel"].tap()
        XCTAssertTrue(app.buttons["r09.gallery.open"].waitForExistence(timeout: 5))
    }
}
