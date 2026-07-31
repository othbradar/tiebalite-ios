import XCTest

enum UITestLaunchScenario: String, CaseIterable {
    case emptyShell = "app.empty-shell"
    case networkOffline = "network.offline"
    case networkSlow = "network.slow"
    case sessionSignedOut = "session.signed-out"
    case sessionSignedInFixture = "session.signed-in-fixture"
    case sessionExpired = "session.expired"

    var safeLabel: String {
        switch self {
        case .emptyShell:
            "Harness: Empty shell"
        case .networkOffline:
            "Harness: Network offline"
        case .networkSlow:
            "Harness: Network slow"
        case .sessionSignedOut:
            "Harness: Session signed out"
        case .sessionSignedInFixture:
            "Harness: Session signed in fixture"
        case .sessionExpired:
            "Harness: Session expired"
        }
    }
}

enum UITestElementID: String, CaseIterable {
    case environment = "app.launch-placeholder.environment"
    case invalidScenario = "app.launch-scenario.invalid"
    case root = "app.launch-placeholder.root"
    case scenario = "app.launch-placeholder.scenario"
    case title = "app.launch-placeholder.title"
}

enum UITestHarness {
    static let scenarioFlag = "--launch-scenario"
    private static let invalidScenarioCanary = "unknown.fixture-scenario"

    @MainActor
    static func launch(scenario: UITestLaunchScenario) -> XCUIApplication {
        launchFixture(arguments: [scenarioFlag, scenario.rawValue])
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
    private static func launchFixture(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    private static func attachSafeFailureEvidence(
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
