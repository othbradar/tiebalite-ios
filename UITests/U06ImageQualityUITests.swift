import XCTest

@MainActor
final class U06ImageQualityUITests: XCTestCase {
    func testHighDefinitionKeepsZoomSavesAndPagesBackToReader() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        MediaViewerProductionAssertions.openMultiple(in: app)
        let image = MediaViewerProductionAssertions.requireImage(at: 0, in: app)
        image.doubleTap()
        MediaViewerProductionAssertions.requireZoomed(image)
        let before = image.value as? String
        let quality = app.buttons["media-viewer.quality"]
        XCTAssertTrue(quality.isHittable)
        quality.tap()
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: quality)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 5), .completed)
        XCTAssertEqual(image.value as? String, before)
        XCTAssertTrue(image.isHittable)
        image.doubleTap()
        MediaViewerProductionAssertions.requireOriginalSize(image)
        image.press(forDuration: 0.7)
        let save = app.buttons["media-viewer.export.save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let saved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "第 1 张：已保存"),
            object: app.staticTexts["media-viewer.export.status"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 5), .completed)
        app.buttons["media-viewer.export.dismiss"].tap()
        image.swipeLeft(velocity: .fast)
        MediaViewerProductionAssertions.requirePosition("2 / 6", in: app)
        _ = MediaViewerProductionAssertions.requireImage(at: 1, in: app)
        MediaViewerProductionAssertions.requireImage(at: 1, in: app).swipeRight()
        MediaViewerProductionAssertions.requirePosition("1 / 6", in: app)
        _ = MediaViewerProductionAssertions.requireImage(at: 0, in: app)
        XCTAssertFalse(quality.exists)
        XCTAssertFalse(app.buttons["media-viewer.export.save"].firstMatch.exists)
        MediaViewerProductionAssertions.requireChromeVisible(in: app)
        UITestHarness.attachSafeVisualEvidence(app: app, name: "U06 high definition and export")
        MediaViewerProductionAssertions.close(in: app)
    }
}
