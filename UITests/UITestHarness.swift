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

enum UITestDisplayProfile: String {
    case darkAccessibilityReduced = "dark-accessibility-reduced"
    case system
}

enum UITestAppTab {
    case followedForums
    case recommendations
    case settings

    var elementID: UITestElementID {
        switch self {
        case .recommendations:
            .tabRecommendations
        case .followedForums:
            .tabFollowedForums
        case .settings:
            .tabSettings
        }
    }
}

enum UITestElementID: String, CaseIterable {
    case componentEmpty = "design-system.empty-state"
    case componentFullPageError = "design-system.full-page-error"
    case componentFullPageErrorRetry = "design-system.full-page-error.retry"
    case componentInitialLoading = "design-system.initial-loading"
    case componentInlineError = "design-system.inline-error"
    case componentInlineErrorRetry = "design-system.inline-error.retry"
    case componentInlineLoading = "design-system.inline-loading"
    case componentPagination = "design-system.pagination-footer"
    case debugOpenGallery = "app.debug.open-component-gallery"
    case followedForumsRoot = "app.root.followed-forums"
    case galleryAppearance = "design-system.gallery.appearance"
    case galleryDynamicType = "design-system.gallery.dynamic-type"
    case galleryReduceMotion = "design-system.gallery.reduce-motion"
    case galleryRoot = "design-system.gallery"
    case interactionCandidate = "interaction.lab.candidate"
    case interactionCurrentPage = "interaction.pager.current-id"
    case interactionLabTitle = "interaction.lab.title"
    case interactionMediaChrome = "interaction.media.chrome"
    case interactionMediaClose = "interaction.media.close"
    case interactionMediaCurrent = "interaction.media.current-id"
    case interactionMediaAccessibilityNext =
        "interaction.media.accessibility.next"
    case interactionMediaAccessibilityPrevious =
        "interaction.media.accessibility.previous"
    case interactionMediaFailure = "interaction.media.error.failure"
    case interactionMediaLoading = "interaction.media.loading.delayed"
    case interactionMediaOpenMultiple = "interaction.media.open.multiple"
    case interactionMediaOpenSingle = "interaction.media.open.single"
    case interactionMediaOverlayState = "interaction.media.overlay-state"
    case interactionMediaReleaseDelayed =
        "interaction.media.release-delayed"
    case interactionMediaRetryFailure = "interaction.media.retry.failure"
    case interactionMediaSource = "interaction.media.source-anchor"
    case interactionMediaViewer = "interaction.media.viewer"
    case interactionMediaZoom = "interaction.media.zoom-state"
    case interactionPagerArmDelete =
        "interaction.pager.action.arm-delete"
    case interactionPagerArmInsert =
        "interaction.pager.action.arm-insert"
    case interactionPagerArmRefresh =
        "interaction.pager.action.arm-refresh"
    case interactionPagerArmReorder =
        "interaction.pager.action.arm-reorder"
    case interactionPagerAccessibilityNext =
        "interaction.pager.accessibility.next"
    case interactionPagerAccessibilityPrevious =
        "interaction.pager.accessibility.previous"
    case interactionPagerCompletion =
        "interaction.pager.completion-count"
    case interactionPagerControllerCount =
        "interaction.pager.controller-count"
    case interactionPagerPageP1 = "interaction.pager.page.p1"
    case interactionPagerPageP2 = "interaction.pager.page.p2"
    case interactionPagerPageP3 = "interaction.pager.page.p3"
    case interactionPagerPosition = "interaction.pager.position"
    case interactionPagerRefresh = "interaction.pager.refresh-state"
    case interactionPagerReset = "interaction.pager.action.reset"
    case interactionPagerTransition =
        "interaction.pager.transition-state"
    case interactionPagerViewportHeight =
        "interaction.pager.viewport-height"
    case interactionSectionMedia = "interaction.lab.section.media"
    case interactionSectionPager = "interaction.lab.section.pager"
    case invalidScenario = "app.launch-scenario.invalid"
    case layoutControlCompact = "app.harness.layout.compact"
    case layoutControlRegular = "app.harness.layout.regular"
    case layoutCompact = "app.shell.layout.compact"
    case layoutRegular = "app.shell.layout.regular"
    case openForum = "app.fixture.root.open-forum"
    case openSubposts = "app.fixture.thread.open-subposts"
    case openThread = "app.fixture.forum.open-thread"
    case recommendationsRoot = "app.root.recommendations"
    case routeForum = "app.route.forum"
    case routeSubposts = "app.route.subposts"
    case routeThread = "app.route.thread"
    case settingsRoot = "app.root.settings"
    case shellRoot = "app.shell.root"
    case shellScenario = "app.shell.scenario"
    case shellTitle = "app.shell.title"
    case tabFollowedForums = "app.tab.followed-forums"
    case tabRecommendations = "app.tab.recommendations"
    case tabSettings = "app.tab.settings"
    case debugOpenInteractionLab = "app.debug.open-interaction-lab"
}

enum UITestHarness {
    static let scenarioFlag = "--launch-scenario"
    private static let invalidScenarioCanary = "unknown.fixture-scenario"

    @MainActor
    static func launch(
        scenario: UITestLaunchScenario,
        displayProfile: UITestDisplayProfile = .system
    ) -> XCUIApplication {
        var arguments = [scenarioFlag, scenario.rawValue]
        if displayProfile != .system {
            arguments.append(contentsOf: [
                "--display-profile",
                displayProfile.rawValue
            ])
        }
        return launchFixture(arguments: arguments)
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

        for _ in 0..<8 where !element.isHittable {
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
