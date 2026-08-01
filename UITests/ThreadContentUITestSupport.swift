import XCTest

extension UITestHarness {
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
