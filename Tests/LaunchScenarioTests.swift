import Testing
@testable import TiebaLite

struct LaunchScenarioTests {
    @Test
    func parsesEveryAllowlistedScenarioExactly() throws {
        #expect(LaunchScenarioRegistry.schemaVersion == 1)
        #expect(LaunchScenarioID.allCases.count == 8)

        for scenario in LaunchScenarioID.allCases {
            let parsed = try LaunchScenarioParser.parse(arguments: [
                "TiebaLite",
                LaunchScenarioParser.flag,
                scenario.rawValue
            ])
            #expect(parsed == scenario)
        }
    }

    @Test
    func rejectsMissingDuplicateAndUnknownScenarioWithoutEchoingRawValue() {
        let invalidArguments = [
            ["TiebaLite"],
            ["TiebaLite", LaunchScenarioParser.flag],
            [
                "TiebaLite",
                LaunchScenarioParser.flag,
                LaunchScenarioID.emptyShell.rawValue,
                LaunchScenarioParser.flag,
                LaunchScenarioID.networkOffline.rawValue
            ],
            ["TiebaLite", LaunchScenarioParser.flag, "UNKNOWN.PRIVATE.VALUE"],
            ["TiebaLite", LaunchScenarioParser.flag, " app.empty-shell "]
        ]

        for arguments in invalidArguments {
            do {
                _ = try LaunchScenarioParser.parse(arguments: arguments)
                Issue.record("Expected strict launch scenario rejection")
            } catch let error as LaunchScenarioParseError {
                #expect(!error.safeDescription.contains("UNKNOWN.PRIVATE.VALUE"))
                #expect(!error.safeDescription.contains(" app.empty-shell "))
            } catch {
                Issue.record("Unexpected launch scenario error type")
            }
        }
    }

    @Test
    func displayProfileIsAllowlistedAndDefaultsToSystem() throws {
        #expect(
            try LaunchDisplayProfileParser.parse(arguments: ["TiebaLite"])
                == .system
        )
        #expect(
            try LaunchDisplayProfileParser.parse(arguments: [
                "TiebaLite",
                LaunchDisplayProfileParser.flag,
                LaunchDisplayProfile.darkAccessibilityReduced.rawValue
            ]) == .darkAccessibilityReduced
        )
        #expect(
            try LaunchDisplayProfileParser.parse(arguments: [
                "TiebaLite",
                LaunchDisplayProfileParser.flag,
                LaunchDisplayProfile.darkAccessibilityMaximumReduced.rawValue
            ]) == .darkAccessibilityMaximumReduced
        )
    }

    @Test
    @MainActor
    func invalidDisplayProfileFailsClosedWithTheScenario() {
        let resolution = LaunchScenarioBootstrap.resolve(arguments: [
            "TiebaLite",
            LaunchScenarioParser.flag,
            LaunchScenarioID.emptyShell.rawValue,
            LaunchDisplayProfileParser.flag,
            "unknown-display-profile"
        ])

        switch resolution {
        case .ready:
            Issue.record("Unknown display profile must fail closed")
        case let .invalid(code):
            #expect(code == "invalid-scenario")
        }
    }

    @Test
    @MainActor
    func scenarioFactoryBuildsReplaceableSafeDependencies() async throws {
        for scenario in LaunchScenarioID.allCases {
            let descriptor = LaunchScenarioFactory.make(scenario: scenario)
            let snapshot = await descriptor.compositionRoot.environment.session.snapshot()

            #expect(descriptor.safeLabel.hasPrefix("Harness:"))
            #expect(
                descriptor.compositionRoot.environment.readingDataSourceMode
                    == .fixture
            )
            switch scenario {
            case .sessionSignedInFixture:
                #expect(snapshot.status == .signedIn)
            case .sessionExpired:
                #expect(snapshot.status == .expired)
            default:
                #expect(snapshot.status == .signedOut)
            }
        }
    }

    @Test
    @MainActor
    func unknownScenarioResolutionFailsClosed() {
        let resolution = LaunchScenarioBootstrap.resolve(arguments: [
            "TiebaLite",
            LaunchScenarioParser.flag,
            "unknown.scenario"
        ])

        switch resolution {
        case .ready:
            Issue.record("Unknown scenario must not construct an application environment")
        case let .invalid(code):
            #expect(code == "invalid-scenario")
        }
    }
}
