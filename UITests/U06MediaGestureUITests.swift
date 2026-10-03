import XCTest

@MainActor
final class U06MediaGestureUITests: XCTestCase {
    func testUnzoomedPagingAtOrdinarySpeedsAndDiagonalZoomedPan() throws {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        MediaViewerProductionAssertions.openMultiple(in: app)
        for speed: XCUIGestureVelocity in [.slow, .default, .fast] {
            let first = MediaViewerProductionAssertions.requireImage(at: 0, in: app)
            first.swipeLeft(velocity: speed)
            MediaViewerProductionAssertions.requirePosition("2 / 6", in: app)
            let second = MediaViewerProductionAssertions.requireImage(at: 1, in: app)
            second.swipeRight(velocity: speed)
            MediaViewerProductionAssertions.requirePosition("1 / 6", in: app)
        }
        let image = MediaViewerProductionAssertions.requireImage(at: 0, in: app)
        for deltaY in [0.01, 0.02, 0.04] {
            image.doubleTap()
            MediaViewerProductionAssertions.requireZoomed(image)
            let before = try offset(in: app)
            image.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6))
                .press(forDuration: 0.05, thenDragTo: image.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.45, dy: 0.6 - deltaY)),
                       withVelocity: .slow, thenHoldForDuration: 0)
            let after = try offset(in: app)
            print("U06 diagonal dy=\(deltaY) before=\(before) after=\(after)")
            XCTAssertGreaterThan(abs(after.x - before.x), 5)
            XCTAssertGreaterThan(abs(after.y - before.y), 2)
            MediaViewerProductionAssertions.requirePosition("1 / 6", in: app)
            image.doubleTap()
            MediaViewerProductionAssertions.requireOriginalSize(image)
        }
        // A 2x XCTest pinch on iPad moved each finger only 8–11 pt, below recognition.
        image.pinch(withScale: 4, velocity: 1)
        MediaViewerProductionAssertions.requireZoomed(image)
        image.press(forDuration: 0.7)
        XCTAssertFalse(app.buttons["media-viewer.export.save"].firstMatch.exists)
        image.swipeLeft()
        MediaViewerProductionAssertions.requirePosition("1 / 6", in: app)
        image.swipeLeft()
        MediaViewerProductionAssertions.requirePosition("1 / 6", in: app)
        image.doubleTap()
        MediaViewerProductionAssertions.requireOriginalSize(image)
        if !app.buttons["media-viewer.close"].exists { image.tap() }
        MediaViewerProductionAssertions.requireChromeVisible(in: app)
        XCTAssertFalse(app.buttons["media-viewer.next"].exists)
        XCTAssertFalse(app.buttons["media-viewer.previous"].exists)
        MediaViewerProductionAssertions.close(in: app)
    }

    func testPinchDoesNotOpenImageActions() {
        let app = UITestHarness.launch(scenario: .threadContentRenderer)
        MediaViewerProductionAssertions.openRendererLab(in: app)
        MediaViewerProductionAssertions.openMultiple(in: app)
        let image = MediaViewerProductionAssertions.requireImage(at: 0, in: app)
        for attempt in 1...3 {
            image.pinch(withScale: 4, velocity: 1)
            let menuVisible = app.buttons["media-viewer.export.save"].firstMatch.exists
            print("U06 pinch attempt=\(attempt) image=\(image.value as? String ?? "missing") menu=\(menuVisible)")
            UITestHarness.attachSafeVisualEvidence(app: app, name: "U06 pinch \(attempt)")
            XCTAssertFalse(app.buttons["media-viewer.export.save"].firstMatch.exists)
            MediaViewerProductionAssertions.requireZoomed(image)
            if (image.value as? String)?.hasPrefix("已放大") == true { image.doubleTap() }
        }
    }

    private func offset(in app: XCUIApplication) throws -> CGPoint {
        let text = app.staticTexts["media-viewer.position"].value as? String ?? ""
        let values = Dictionary(uniqueKeysWithValues: text.split(separator: " ").compactMap { token -> (String, Double)? in
            let parts = token.split(separator: "=")
            guard parts.count == 2, let value = Double(parts[1]) else { return nil }
            return (String(parts[0]), value)
        })
        return CGPoint(x: try XCTUnwrap(values["x"]), y: try XCTUnwrap(values["y"]))
    }
}
