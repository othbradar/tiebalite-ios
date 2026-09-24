import XCTest

final class R10ComposerSmokeTests: XCTestCase {
    @MainActor
    func testEmoticonPanelFillsWidthAndStaysBetweenToolbarAndStatus() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .settings)
        UITestHarness.tap(.debugOpenGallery, in: app)
        app.buttons["r10.gallery.open"].tap()
        app.buttons["r10.select.1"].tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        for cycle in 1...3 {
            editor.tap()
            app.buttons["composer.toggle-emoticons"].tap()
            let panel = app.scrollViews["composer.emoticons"]
            XCTAssertTrue(panel.waitForExistence(timeout: 5), app.debugDescription)
            let toggle = app.buttons["composer.toggle-emoticons"]
            let status = app.staticTexts["composer.draft-status"]
            XCTAssertEqual(panel.frame.width, editor.frame.width, accuracy: 1)
            XCTAssertEqual(panel.frame.minX, editor.frame.minX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(panel.frame.minY, toggle.frame.maxY)
            // The approved native input slot is below BOTH app controls; neither may overlap it.
            XCTAssertGreaterThanOrEqual(panel.frame.minY, status.frame.maxY)
            XCTAssertLessThanOrEqual(editor.frame.maxY, toggle.frame.minY)
            if cycle == 1 {
                XCTAssertGreaterThanOrEqual(app.buttons["composer.emoticon.image_emoticon1"].frame.minY, panel.frame.minY)
            }
            let frames = "cycle \(cycle): panel \(panel.frame), toolbar \(toggle.frame)"
                + ", status \(status.frame), editor \(editor.frame)"
            let snapshot = XCTAttachment(string: frames)
            snapshot.lifetime = .keepAlways
            add(snapshot)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 panel opening \(cycle)")
            panel.swipeUp()
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 panel scrolling \(cycle)")
            app.buttons["composer.toggle-emoticons"].tap()
            XCTAssertFalse(panel.exists)
        }
    }

    @MainActor
    func testPhotoCountsDeleteEmoticonsAndUploadRetry() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .settings)
        UITestHarness.tap(.debugOpenGallery, in: app)
        app.buttons["r10.gallery.open"].tap()
        for count in [1, 4, 5] {
            app.buttons["r10.select.\(count)"].tap()
            let editor = app.textViews["composer.body"]
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            let deletes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "composer.photo.remove."))
            XCTAssertEqual(deletes.count, count, app.debugDescription)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 \(count) selected photos")
            if count != 5 { app.buttons["composer.cancel"].tap(); continue }
            let remaining = deletes.allElementsBoundByIndex.map(\.identifier).enumerated().filter { $0.offset != 2 }.map(\.element)
            deletes.element(boundBy: 2).tap()
            XCTAssertEqual(deletes.allElementsBoundByIndex.map(\.identifier), remaining)
            editor.tap()
            editor.typeText("Photo reply ")
            app.buttons["composer.toggle-emoticons"].tap()
            XCTAssertTrue(app.scrollViews["composer.emoticons"].waitForExistence(timeout: 5))
            app.buttons["composer.emoticon.image_emoticon22"].tap()
            app.buttons["composer.emoticon.image_emoticon25"].tap()
            app.buttons["composer.emoticon.image_emoticon1"].tap()
            XCTAssertEqual(editor.value as? String, "Photo reply \u{FFFC}\u{FFFC}\u{FFFC}")
            XCTAssertFalse(app.descendants(matching: .any)["composer.preview"].exists)
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 four photos and official emoticons")
            app.buttons["composer.toggle-emoticons"].tap()
            XCTAssertFalse(app.scrollViews["composer.emoticons"].exists)
            // UITESTING gallery owns only Fixture repositories; this cannot publish to Live.
            app.buttons["composer.send"].tap()
            let upload = app.progressIndicators["composer.uploading"]
            XCTAssertTrue(upload.waitForExistence(timeout: 5))
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 upload in progress")
            app.buttons["r10.finish-upload"].tap()
            XCTAssertTrue(app.staticTexts["composer.media-failure"].waitForExistence(timeout: 5))
            XCTAssertEqual(deletes.count, 4)
            XCTAssertEqual(editor.value as? String, "Photo reply \u{FFFC}\u{FFFC}\u{FFFC}")
            UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 upload failure retains draft")
            app.buttons["composer.send"].tap()
            XCTAssertTrue(app.staticTexts["r10.result"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["r10.result"].label, "模拟完成")
        }
    }

    @MainActor
    func testIPadSheetKeyboardAndPhotoDraftSurviveRotation() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = UITestHarness.launch(scenario: .fixtureReadingFlow, startingTab: .settings)
        UITestHarness.tap(.debugOpenGallery, in: app)
        app.buttons["r10.gallery.open"].tap()
        app.buttons["r10.select.4"].tap()
        let editor = app.textViews["composer.body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("iPad draft")
        app.buttons["composer.toggle-emoticons"].tap()
        let panel = app.scrollViews["composer.emoticons"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(panel.frame.width, app.windows.firstMatch.frame.width, accuracy: 1)
        app.buttons["composer.emoticon.image_emoticon25"].tap()
        XCTAssertEqual(editor.value as? String, "iPad draft\u{FFFC}")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, "iPad draft\u{FFFC}")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "composer.photo.remove.")).count, 4)
        XCTAssertEqual(panel.frame.width, app.windows.firstMatch.frame.width, accuracy: 1)
        XCTAssertGreaterThanOrEqual(panel.frame.minY, app.staticTexts["composer.draft-status"].frame.maxY)
        panel.swipeUp()
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 iPad native emoticons landscape")
        app.buttons["composer.toggle-emoticons"].tap()
        XCTAssertTrue(editor.isHittable)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "R10 iPad four photos keyboard landscape")
    }
}
