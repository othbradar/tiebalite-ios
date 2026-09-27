import XCTest

extension UITestHarness {
    @MainActor
    static func scrollRendererTailIntoView(in app: XCUIApplication) {
        // R07 groups adjacent text nodes 19...22 into one native text view.
        // Check the original tail content and its visible end, not a retired node element.
        let text = UITestHarness.element(.threadContentAfterUnknown, in: app)
        let renderer = UITestHarness.element(.threadContentLabRoot, in: app)
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.hasSuffix("未知节点之后的合成尾部文本。"))
        for _ in 0..<24 where text.frame.maxY > renderer.frame.maxY {
            renderer.swipeUp()
        }
        XCTAssertLessThanOrEqual(text.frame.maxY, renderer.frame.maxY)
        XCTAssertGreaterThan(text.frame.maxY, UITestHarness.element(.shellScenario, in: app).frame.maxY)
        XCTAssertTrue(text.isHittable)
    }

    @MainActor
    static func tapRendererImageClearOfFixtureBanner(in app: XCUIApplication) {
        let image = UITestHarness.element(.threadContentImageSuccessAction, in: app)
        let banner = UITestHarness.element(.shellScenario, in: app)
        let viewport = UITestHarness.element(.threadContentLabRoot, in: app).frame.intersection(app.frame)
        let top = max(viewport.minY, banner.frame.maxY)
        let bottom = min(viewport.maxY, UITestHarness.element(.tabSettings, in: app).frame.minY)
        let centerY = (top + bottom) / 2
        // A large-type fixture banner can cover a target that reports hittable.
        // Use measured drags: a fling can carry this small cell past the whole viewport.
        for _ in 0..<24 {
            let frame = image.frame
            if frame.minY >= top, frame.maxY <= bottom { break }
            let limit = (bottom - top) / 3
            let delta = min(max(centerY - frame.midY, -limit), limit)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX, dy: centerY))
            let end = origin.withOffset(CGVector(dx: viewport.midX, dy: centerY + delta))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.05)
        }
        let frame = image.frame
        XCTAssertGreaterThanOrEqual(frame.minY, top)
        XCTAssertLessThanOrEqual(frame.maxY, bottom)
        XCTAssertTrue(image.isHittable)
        image.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    static func scrollRendererToHittable(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        let renderer = app.descendants(matching: .any)[
            UITestElementID.threadContentLabRoot.rawValue
        ]
        guard element.waitForExistence(timeout: 5),
              renderer.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing renderer scroll target: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        for _ in 0..<24 where !element.isHittable {
            renderer.swipeUp()
        }
        guard element.isHittable else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Renderer target is not readable or hittable: "
                    + identifier.rawValue,
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func scrollBackToHittable(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing reverse scroll target: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        for _ in 0..<24 where !element.isHittable {
            app.swipeDown()
        }
        guard element.isHittable else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Reverse scroll target is not readable or hittable: "
                    + identifier.rawValue,
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func requireValue(
        _ identifier: UITestElementID,
        equals expectedValue: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing fixture value: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Unexpected fixture value: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
    }
}
