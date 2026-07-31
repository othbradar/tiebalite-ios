import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
@MainActor
enum LaunchScenarioFactory {
    static func make(scenario: LaunchScenarioID) -> LaunchScenarioDescriptor {
        let networkMode: LaunchScenarioNetworkMode
        let httpBehavior: HarnessHTTPDefaultBehavior
        let sessionStatus: SessionStatus
        let safeLabel: String

        switch scenario {
        case .emptyShell:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Empty shell"
        case .networkOffline:
            networkMode = .offline
            httpBehavior = .failure(.offline)
            sessionStatus = .signedOut
            safeLabel = "Harness: Network offline"
        case .networkSlow:
            networkMode = .slow
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Network slow"
        case .sessionSignedOut:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Session signed out"
        case .sessionSignedInFixture:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedIn
            safeLabel = "Harness: Session signed in fixture"
        case .sessionExpired:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .expired
            safeLabel = "Harness: Session expired"
        }

        let environment = AppEnvironment(
            clock: HarnessControlledClock(),
            idGenerator: HarnessSequenceIDGenerator(
                values: (1...32).map { OperationID(sequence: UInt64($0)) }
            ),
            httpClient: HarnessMockHTTPClient(defaultBehavior: httpBehavior),
            session: HarnessFixtureSessionProvider(
                snapshot: SessionSnapshot(status: sessionStatus, revision: 1)
            ),
            imageLoader: HarnessFixtureImageLoader(fixtures: [:]),
            cache: HarnessInMemoryDataCache(),
            diagnostics: HarnessRecordingDiagnosticsClient()
        )

        return LaunchScenarioDescriptor(
            scenario: scenario,
            safeLabel: safeLabel,
            networkMode: networkMode,
            compositionRoot: AppCompositionRoot(environment: environment),
            isolationCanary: LaunchScenarioRegistry.isolationCanary
        )
    }
}
#endif
