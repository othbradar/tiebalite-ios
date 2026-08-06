import XCTest

extension UITestHarness {
    @MainActor
    static func attachSafeVisualEvidence(
        app: XCUIApplication,
        name: String
    ) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        XCTContext.runActivity(named: "Attach safe visual evidence") {
            $0.add(screenshot)
        }
    }

    @MainActor
    static func element(
        _ identifier: UITestElementID,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier.rawValue]
    }

    @MainActor
    static func scrollToHittable(
        _ identifier: UITestElementID,
        inside containerIdentifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        let container = app.descendants(matching: .any)[
            containerIdentifier.rawValue
        ]
        guard container.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: containerIdentifier)
            XCTFail(
                "Missing scroll container: \(containerIdentifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        for _ in 0..<24 {
            if element.exists, element.isHittable {
                return
            }
            container.swipeUp()
        }
        attachSafeFailureEvidence(app: app, expected: identifier)
        XCTFail(
            "Scroll target is not readable or hittable: \(identifier.rawValue)",
            file: file,
            line: line
        )
    }

    @MainActor
    static func scrollBackToHittable(
        _ identifier: UITestElementID,
        inside containerIdentifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        let container = app.descendants(matching: .any)[
            containerIdentifier.rawValue
        ]
        guard container.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: containerIdentifier)
            XCTFail(
                "Missing scroll container: \(containerIdentifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        for _ in 0..<24 {
            if element.exists, element.isHittable {
                return
            }
            container.swipeDown()
        }
        attachSafeFailureEvidence(app: app, expected: identifier)
        XCTFail(
            "Scroll target is not readable or hittable: \(identifier.rawValue)",
            file: file,
            line: line
        )
    }
}
