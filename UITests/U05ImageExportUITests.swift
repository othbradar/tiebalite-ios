import XCTest

@MainActor
final class U05ImageExportUITests: XCTestCase {
    func testSaveSecondImageShareAndReturnToReader() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        MediaViewerProductionAssertions.openMultiple(in: app)
        MediaViewerProductionAssertions.requireImage(at: 0, in: app).swipeLeft()
        MediaViewerProductionAssertions.requirePosition("2 / 6", in: app)
        XCTAssertFalse(app.buttons["media-viewer.export.save"].firstMatch.exists)
        MediaViewerProductionAssertions.requireImage(at: 1, in: app).press(forDuration: 0.7)
        let save = app.buttons["media-viewer.export.save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isHittable)
        save.tap()
        let status = app.staticTexts["media-viewer.export.status"]
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "第 2 张：已保存"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        XCTAssertEqual(app.alerts.count, 0, "Fixture must never request real Photos permission")
        MediaViewerProductionAssertions.requireImage(at: 1, in: app).swipeLeft()
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)
        XCTAssertTrue(status.label.contains("第 2 张"))
        MediaViewerProductionAssertions.requireImage(at: 2, in: app).press(forDuration: 0.7)
        let share = app.buttons["media-viewer.export.share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(share.isHittable)
        share.tap()
        let activity = app.otherElements["ActivityListView"]
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        let attachment = app.descendants(matching: .any)["LP.CaptionBar.TopCaption"]
        XCTAssertTrue(attachment.label.contains("TiebaLite-image"))
        // This iOS version presents an anchored popover; tapping outside is its native cancel action.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)).tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: activity)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        MediaViewerProductionAssertions.requireImage(at: 2, in: app).press(forDuration: 0.7)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: share)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        save.tap()
        let savedThird = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "第 3 张：已保存"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [savedThird], timeout: 5), .completed)
        MediaViewerProductionAssertions.requirePosition("3 / 6", in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U05 export controls after sharing")
        MediaViewerProductionAssertions.close(in: app)
    }
}
