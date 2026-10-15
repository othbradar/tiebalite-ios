import XCTest

@MainActor
final class U13MediaUITests: XCTestCase {
    func testVideoStartsInsideThePostInsteadOfASheet() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        app.buttons["u13.open"].tap()
        app.buttons["media.video.fixture.video"].tap()
        XCTAssertFalse(app.buttons["media.video.close"].exists, "Video must not open a separate sheet")
        XCTAssertTrue(app.otherElements["media.video.inline.fixture.video"].waitForExistence(timeout: 5))
        expectState("fixture.video playing", app: app)
        let pause = playbackControl(in: app)
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        expectState("fixture.video paused", app: app)
        playbackControl(in: app).tap()
        expectState("fixture.video playing", app: app)
        app.scrollViews.firstMatch.swipeUp()
        app.scrollViews.firstMatch.swipeUp()
        expectState("none idle", app: app)
    }

    func testPlaybackOwnershipPauseInlineVideoAndScrollStop() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        app.buttons["u13.open"].tap()
        let voice = app.buttons["media.voice.fixture.voice1"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        voice.tap()
        expectState("fixture.voice1 playing", app: app)
        voice.tap()
        expectState("fixture.voice1 paused", app: app)
        app.buttons["media.voice.fixture.voice2"].tap()
        expectState("fixture.voice2 playing", app: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        expectState("none idle", app: app)
        app.buttons["media.video.fixture.video"].tap()
        expectState("fixture.video playing", app: app)
        XCTAssertFalse(app.buttons["media.video.close"].exists)
        voice.tap()
        expectState("fixture.voice1 playing", app: app)
        app.scrollViews.firstMatch.swipeUp()
        app.scrollViews.firstMatch.swipeUp()
        expectState("none idle", app: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U13 offscreen stop")
    }

    func testFailureRetryAndReducedMotionControl() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        app.buttons["u13.open"].tap()
        let toggle = app.switches["u13.reduce"]
        if !toggle.isHittable { app.scrollViews.firstMatch.swipeUp() }
        toggle.tap()
        XCTAssertTrue(app.buttons["media.animation.toggle"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["media.animation.toggle"].firstMatch.tap()
        let failure = app.buttons["media.video.fixture.failure"]
        for _ in 0..<4 where !failure.isHittable { app.scrollViews.firstMatch.swipeUp() }
        failure.tap()
        let retry = app.buttons["media.video.retry.fixture.failure"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["media.video.close"].exists)
    }

    func testAutomaticPlaybackUsesTheSettingsChoiceAndDoesNotOverridePause() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        UITestHarness.tapTab(.settings, in: app)
        app.buttons["personal.open-settings"].tap()
        let preference = app.buttons["settings.video-playback"]
        XCTAssertTrue(preference.waitForExistence(timeout: 5))
        preference.tap()
        app.buttons["自动播放"].tap()
        MediaViewerProductionAssertions.openRendererLab(in: app)
        app.buttons["u13.open"].tap()
        expectState("fixture.video playing", app: app)
        XCTAssertFalse(app.buttons["media.video.close"].exists)
        let pause = playbackControl(in: app)
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        expectState("fixture.video paused", app: app)
        app.buttons["media.voice.fixture.voice1"].tap()
        expectState("fixture.voice1 playing", app: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        expectState("none idle", app: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U13 inline automatic playback")
    }

    private func expectState(_ value: String, app: XCUIApplication) {
        let condition = NSPredicate(format: "label == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: condition, object: app.staticTexts["u13.state"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    private func playbackControl(in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["Play/Pause"]
        if !button.exists {
            app.otherElements["media.video.inline.fixture.video"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        }
        return button
    }
}
