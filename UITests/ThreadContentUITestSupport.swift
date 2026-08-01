import XCTest

extension UITestHarness {
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
