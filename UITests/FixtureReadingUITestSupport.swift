import XCTest

extension UITestHarness {
    @MainActor
    static func launchIsolated(
        scenario: UITestLaunchScenario
    ) -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = [scenarioFlag, scenario.rawValue]
        app.launch()
        return app
    }

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
    static func scrollBackToStableFrame(
        _ identifier: UITestElementID,
        inside containerIdentifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let container = app.descendants(matching: .any)[
            containerIdentifier.rawValue
        ]
        let window = app.windows.firstMatch
        guard container.waitForExistence(timeout: 5),
              window.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: containerIdentifier)
            XCTFail(
                "Missing stable scroll viewport: "
                    + containerIdentifier.rawValue,
                file: file,
                line: line
            )
            return
        }

        for _ in 0..<24 {
            let element = app.descendants(matching: .any)[identifier.rawValue]
            if element.waitForExistence(timeout: 0.25) {
                let viewport = stableViewport(
                    container: container,
                    window: window,
                    app: app
                )
                let frame = element.frame
                if isValid(frame: frame, intersecting: viewport) {
                    if isFullyContained(frame, in: viewport) {
                        return
                    }
                    if centerVertically(
                        frame: frame,
                        in: viewport,
                        app: app
                    ) {
                        continue
                    }
                }
            }
            container.swipeDown()
        }

        attachSafeFailureEvidence(app: app, expected: identifier)
        XCTFail(
            "Scroll target did not reach a stable frame: "
                + identifier.rawValue,
            file: file,
            line: line
        )
    }

    @MainActor
    static func tapStableTarget(
        _ identifier: UITestElementID,
        inside containerIdentifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let container = app.descendants(matching: .any)[
            containerIdentifier.rawValue
        ]
        let window = app.windows.firstMatch
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard container.waitForExistence(timeout: 5),
              window.waitForExistence(timeout: 5),
              element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail("Missing stable tap target", file: file, line: line)
            return
        }

        let viewport = stableViewport(
            container: container,
            window: window,
            app: app
        )
        let frame = element.frame
        guard isValid(frame: frame, intersecting: viewport),
              isFullyContained(frame, in: viewport),
              element.elementType == .button,
              element.isEnabled else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail("Invalid stable tap frame", file: file, line: line)
            return
        }
        if element.isHittable {
            element.tap()
            return
        }

        let refreshedContainer = app.descendants(matching: .any)[
            containerIdentifier.rawValue
        ]
        let refreshedWindow = app.windows.firstMatch
        let refreshed = app.descendants(matching: .any)[identifier.rawValue]
        guard refreshedContainer.waitForExistence(timeout: 1),
              refreshedWindow.waitForExistence(timeout: 1),
              refreshed.waitForExistence(timeout: 1) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail("Stable tap target disappeared", file: file, line: line)
            return
        }
        let refreshedViewport = stableViewport(
            container: refreshedContainer,
            window: refreshedWindow,
            app: app
        )
        let refreshedFrame = refreshed.frame
        guard isValid(frame: refreshedFrame, intersecting: refreshedViewport),
              isFullyContained(refreshedFrame, in: refreshedViewport),
              isApproximatelyEqual(refreshedFrame, frame),
              refreshed.elementType == .button,
              refreshed.isEnabled else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail("Stable tap target frame changed", file: file, line: line)
            return
        }
        tapCenter(of: refreshedFrame, in: app)
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
    private static func stableViewport(
        container: XCUIElement,
        window: XCUIElement,
        app: XCUIApplication
    ) -> CGRect {
        container.frame
            .intersection(window.frame)
            .intersection(app.frame)
    }

    private static func isValid(
        frame: CGRect,
        intersecting viewport: CGRect
    ) -> Bool {
        frame.width > 0
            && frame.height > 0
            && frame.origin.x.isFinite
            && frame.origin.y.isFinite
            && frame.width.isFinite
            && frame.height.isFinite
            && !viewport.isNull
            && !viewport.isEmpty
            && viewport.origin.x.isFinite
            && viewport.origin.y.isFinite
            && viewport.width.isFinite
            && viewport.height.isFinite
            && frame.intersects(viewport)
    }

    private static func isFullyContained(
        _ frame: CGRect,
        in viewport: CGRect
    ) -> Bool {
        let horizontalInset = min(8, viewport.width / 4)
        let verticalInset = min(8, viewport.height / 4)
        return frame.minX >= viewport.minX + horizontalInset
            && frame.maxX <= viewport.maxX - horizontalInset
            && frame.minY >= viewport.minY + verticalInset
            && frame.maxY <= viewport.maxY - verticalInset
    }

    private static func isApproximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect
    ) -> Bool {
        let tolerance: CGFloat = 2
        return abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.maxX - rhs.maxX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.maxY - rhs.maxY) <= tolerance
    }

    @MainActor
    private static func centerVertically(
        frame: CGRect,
        in viewport: CGRect,
        app: XCUIApplication
    ) -> Bool {
        let appFrame = app.frame
        guard appFrame.width > 0, appFrame.height > 0 else { return false }
        let startY = viewport.midY
        let desiredDelta = viewport.midY - frame.midY
        let maximumStep = viewport.height * 0.08
        let clampedDelta = min(
            max(desiredDelta, -maximumStep),
            maximumStep
        )
        let unclampedEndY = startY + clampedDelta
        let endY = min(
            max(unclampedEndY, viewport.minY + 32),
            viewport.maxY - 32
        )
        guard abs(endY - startY) >= 8 else { return false }
        let normalizedX = (viewport.midX - appFrame.minX) / appFrame.width
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
            withVelocity: .default,
            thenHoldForDuration: 0
        )
        return true
    }

    @MainActor
    private static func tapCenter(
        of frame: CGRect,
        in app: XCUIApplication
    ) {
        let appFrame = app.frame
        let coordinate = app.coordinate(withNormalizedOffset: CGVector(
            dx: (frame.midX - appFrame.minX) / appFrame.width,
            dy: (frame.midY - appFrame.minY) / appFrame.height
        ))
        coordinate.tap()
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
