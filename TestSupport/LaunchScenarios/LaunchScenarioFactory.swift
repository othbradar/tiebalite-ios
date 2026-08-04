import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
@MainActor
enum LaunchScenarioFactory {
    static func make(
        scenario: LaunchScenarioID,
        displayProfile: LaunchDisplayProfile = .system
    ) -> LaunchScenarioDescriptor {
        let networkMode: LaunchScenarioNetworkMode
        let httpBehavior: HarnessHTTPDefaultBehavior
        let sessionStatus: SessionStatus
        let safeLabel: String
        let imageLoader: any ImageLoading

        switch scenario {
        case .emptyShell:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Empty shell"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        case .fixtureReadingFlow:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Fixture reading flow"
            imageLoader = FixtureReadingImageLoader()
        case .networkOffline:
            networkMode = .offline
            httpBehavior = .failure(.offline)
            sessionStatus = .signedOut
            safeLabel = "Harness: Network offline"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        case .networkSlow:
            networkMode = .slow
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Network slow"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        case .threadContentRenderer:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Thread content renderer"
            imageLoader = HarnessRendererImageLoader()
        case .sessionSignedOut:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedOut
            safeLabel = "Harness: Session signed out"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        case .sessionSignedInFixture:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedIn
            safeLabel = "Harness: Session signed in fixture"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        case .sessionExpired:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .expired
            safeLabel = "Harness: Session expired"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        }

        let environment = AppEnvironment(
            readingDataSourceMode: .fixture,
            clock: HarnessControlledClock(),
            idGenerator: HarnessSequenceIDGenerator(
                values: (1...32).map { OperationID(sequence: UInt64($0)) }
            ),
            httpClient: HarnessMockHTTPClient(defaultBehavior: httpBehavior),
            session: HarnessFixtureSessionProvider(
                snapshot: SessionSnapshot(status: sessionStatus, revision: 1)
            ),
            imageLoader: imageLoader,
            cache: HarnessInMemoryDataCache(),
            diagnostics: HarnessRecordingDiagnosticsClient()
        )

        return LaunchScenarioDescriptor(
            scenario: scenario,
            safeLabel: safeLabel,
            networkMode: networkMode,
            compositionRoot: AppCompositionRoot(environment: environment),
            isolationCanary: LaunchScenarioRegistry.isolationCanary,
            displayProfile: displayProfile
        )
    }
}
#endif
