import XCTest

enum UITestHarness {
    static let scenarioFlag = "--launch-scenario"
    private static let invalidScenarioCanary = "unknown.fixture-scenario"

    @MainActor
    static func launch(
        scenario: UITestLaunchScenario,
        displayProfile: UITestDisplayProfile = .system,
        startingTab: UITestAppTab? = .recommendations
    ) -> XCUIApplication {
        var arguments = [scenarioFlag, scenario.rawValue]
        if displayProfile != .system {
            arguments.append(contentsOf: [
                "--display-profile",
                displayProfile.rawValue
            ])
        }
        let app = launchFixture(arguments: arguments)
        if let startingTab {
            tapTab(startingTab, in: app)
        }
        return app
    }

    @MainActor
    static func launchUnknownScenarioCanary() -> XCUIApplication {
        launchFixture(arguments: [scenarioFlag, invalidScenarioCanary])
    }

    @MainActor
    static func requirePresent(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        expectedLabel: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]

        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing safe fixture element: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        if identifier != .invalidScenario {
            let invalid = app.descendants(matching: .any)[
                UITestElementID.invalidScenario.rawValue
            ]
            guard !invalid.exists else {
                attachSafeFailureEvidence(app: app, expected: identifier)
                XCTFail("Fixture launch failed closed", file: file, line: line)
                return
            }
        }

        if let expectedLabel, element.label != expectedLabel {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Unexpected label for safe fixture element: \(identifier.rawValue)",
                file: file,
                line: line
            )
        }
    }
    @MainActor
    static func requireAbsent(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !app.descendants(matching: .any)[identifier.rawValue].exists else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Unexpected safe fixture element: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func waitUntilAbsent(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Fixture element did not disappear: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func requireLabel(
        _ identifier: UITestElementID,
        equals expectedLabel: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing fixture label: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Unexpected fixture label: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func requireLabelNotEqual(
        _ identifier: UITestElementID,
        to rejectedLabel: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing fixture label: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        let predicate = NSPredicate(
            format: "label != %@",
            rejectedLabel
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Fixture label did not change: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
    }
}

extension UITestHarness {
    @MainActor
    static func tap(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing tappable fixture element: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        let predicate = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        guard XCTWaiter.wait(for: [expectation], timeout: 5) == .completed else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Fixture element is not hittable: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }
        element.tap()
    }

    @MainActor
    static func requireTabPresent(
        _ tab: UITestAppTab,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = tabElement(tab, in: app)
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: tab.elementID)
            XCTFail(
                "Missing App tab selector: \(tab.elementID.rawValue)",
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func tapTab(
        _ tab: UITestAppTab,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = tabElement(tab, in: app)
        guard element.waitForExistence(timeout: 5), element.isHittable else {
            attachSafeFailureEvidence(app: app, expected: tab.elementID)
            XCTFail(
                "App tab selector is unavailable: \(tab.elementID.rawValue)",
                file: file,
                line: line
            )
            return
        }
        element.tap()
    }

    @MainActor
    static func requireTabSelected(
        _ tab: UITestAppTab,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = tabElement(tab, in: app)
        guard element.waitForExistence(timeout: 5), element.isSelected else {
            attachSafeFailureEvidence(app: app, expected: tab.elementID)
            XCTFail(
                "App tab lacks selected accessibility state: "
                    + tab.elementID.rawValue,
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    static func tapSystemBack(
        in app: XCUIApplication,
        returningTo identifier: UITestElementID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        guard backButton.waitForExistence(timeout: 5), backButton.isHittable else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail("System navigation back is unavailable", file: file, line: line)
            return
        }
        backButton.tap()
        requirePresent(identifier, in: app, file: file, line: line)
    }

    @MainActor
    static func swipeSystemBack(
        in app: XCUIApplication,
        returningTo identifier: UITestElementID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let start = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)
        )
        let end = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)
        )
        start.press(forDuration: 0.1, thenDragTo: end)
        requirePresent(identifier, in: app, file: file, line: line)
    }

    @MainActor
    static func scrollToHittable(
        _ identifier: UITestElementID,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier.rawValue]
        guard element.waitForExistence(timeout: 5) else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Missing scroll target: \(identifier.rawValue)",
                file: file,
                line: line
            )
            return
        }

        for _ in 0..<24 where !element.isHittable {
            app.swipeUp()
        }
        guard element.isHittable else {
            attachSafeFailureEvidence(app: app, expected: identifier)
            XCTFail(
                "Scroll target is not readable or hittable: "
                    + identifier.rawValue,
                file: file,
                line: line
            )
            return
        }
    }

    @MainActor
    private static func launchFixture(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    private static func tabElement(
        _ tab: UITestAppTab,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[
            tab.elementID.rawValue
        ]
    }

    @MainActor
    static func attachSafeFailureEvidence(
        app: XCUIApplication,
        expected: UITestElementID
    ) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Sanitized fixture scenario failure"
        screenshot.lifetime = .keepAlways
        XCTContext.runActivity(named: "Attach safe fixture evidence") { activity in
            activity.add(screenshot)

            let summary = XCTAttachment(
                string: safeHierarchySummary(app: app, expected: expected)
            )
            summary.name = "Sanitized hierarchy summary"
            summary.lifetime = .keepAlways
            activity.add(summary)
        }
    }
    @MainActor
    private static func safeHierarchySummary(
        app: XCUIApplication,
        expected: UITestElementID
    ) -> String {
        let safeLabels = Set(
            UITestLaunchScenario.allCases.map(\.safeLabel) + ["invalid-scenario"]
        )
        let observations = UITestElementID.allCases.map { identifier in
            let element = app.descendants(matching: .any)[identifier.rawValue]
                .firstMatch
            guard element.exists else {
                return "\(identifier.rawValue)=absent"
            }
            let label = safeLabels.contains(element.label) ? element.label : "<redacted>"
            return "\(identifier.rawValue)=present,label=\(label)"
        }
        return (["expected=\(expected.rawValue)"] + observations)
            .joined(separator: "\n")
    }
}
