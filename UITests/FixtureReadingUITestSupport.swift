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
        gestureAnchor anchorIdentifier: UITestElementID? = nil,
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
        let anchorX: CGFloat?
        if let anchorIdentifier {
            let anchor = app.descendants(matching: .any)[
                anchorIdentifier.rawValue
            ]
            guard anchor.waitForExistence(timeout: 5), anchor.isHittable else {
                attachSafeFailureEvidence(app: app, expected: anchorIdentifier)
                XCTFail(
                    "Missing scroll gesture anchor: \(anchorIdentifier.rawValue)",
                    file: file,
                    line: line
                )
                return
            }
            anchorX = anchor.frame.midX
        } else {
            anchorX = nil
        }

        for _ in 0..<24 {
            if isVisibleAndHittable(element, inside: container) {
                return
            }
            swipeUp(
                inside: container,
                atAbsoluteX: anchorX,
                in: app
            )
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
            if isVisibleAndHittable(element, inside: container) {
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

    @MainActor
    private static func isVisibleAndHittable(
        _ element: XCUIElement,
        inside container: XCUIElement
    ) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame.width > 0,
              frame.height > 0,
              frame.intersects(container.frame) else {
            return false
        }
        return element.isHittable
    }

    @MainActor
    private static func swipeUp(
        inside container: XCUIElement,
        atAbsoluteX anchorX: CGFloat?,
        in app: XCUIApplication
    ) {
        guard let anchorX else {
            container.swipeUp()
            return
        }
        // A regular-width split can expose a scroll container frame spanning
        // the empty detail column. A known visible row supplies the actual
        // list-column x coordinate without a screen-size constant.
        let appFrame = app.frame
        let visibleFrame = container.frame.intersection(appFrame)
        let normalizedX = (anchorX - appFrame.minX) / appFrame.width
        let startY = visibleFrame.minY + (visibleFrame.height * 0.82)
        let endY = visibleFrame.minY + (visibleFrame.height * 0.18)
        let start = app.coordinate(withNormalizedOffset: CGVector(
            dx: normalizedX,
            dy: (startY - appFrame.minY) / appFrame.height
        ))
        let end = app.coordinate(withNormalizedOffset: CGVector(
            dx: normalizedX,
            dy: (endY - appFrame.minY) / appFrame.height
        ))
        start.press(
            forDuration: 0.01,
            thenDragTo: end,
            withVelocity: .fast,
            thenHoldForDuration: 0
        )
    }
}
