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

        let sessionDependencies = makeSessionDependencies(
            status: sessionStatus
        )
        let environment = makeEnvironment(
            httpBehavior: httpBehavior,
            session: sessionDependencies.authContextProvider,
            imageLoader: imageLoader
        )

        return LaunchScenarioDescriptor(
            scenario: scenario,
            safeLabel: safeLabel,
            networkMode: networkMode,
            compositionRoot: AppCompositionRoot(
                environment: environment,
                authContextProvider: sessionDependencies.authContextProvider,
                sessionStore: sessionDependencies.store,
                loginWebSession: sessionDependencies.loginWebSession
            ),
            isolationCanary: LaunchScenarioRegistry.isolationCanary,
            displayProfile: displayProfile
        )
    }

    private static func makeSessionDependencies(
        status: SessionStatus
    ) -> HarnessLaunchSessionDependencies {
        let authContextProvider = SessionAuthContextProvider()
        let loginWebSession = LoginWebSession(loginURL: nil)
        let fixtureCredential = status != .signedOut
            ? SessionCredential(
                bduss: "ui-fixture-bduss",
                stoken: "ui-fixture-stoken"
            )
            : nil
        if let fixtureCredential {
            authContextProvider.install(fixtureCredential)
            if status == .expired {
                let context = authContextProvider.context()
                _ = authContextProvider.expire(context: context)
            }
        }
        let credentialStore = FakeSessionCredentialStore(
            initialCredential: status == .signedIn ? fixtureCredential : nil
        )
        return HarnessLaunchSessionDependencies(
            authContextProvider: authContextProvider,
            loginWebSession: loginWebSession,
            store: SessionStore(
                credentialStore: credentialStore,
                authContextProvider: authContextProvider,
                websiteDataCleaner: loginWebSession,
                initialState: sessionState(for: status),
                restoresOnLaunch: false
            )
        )
    }

    private static func sessionState(for status: SessionStatus) -> SessionState {
        switch status {
        case .expired:
            .expired
        case .signedIn:
            .signedIn
        case .signedOut:
            .signedOut
        }
    }

    private static func makeEnvironment(
        httpBehavior: HarnessHTTPDefaultBehavior,
        session: any SessionProviding,
        imageLoader: any ImageLoading
    ) -> AppEnvironment {
        AppEnvironment(
            readingDataSourceMode: .fixture,
            clock: HarnessControlledClock(),
            idGenerator: HarnessSequenceIDGenerator(
                values: (1...32).map { OperationID(sequence: UInt64($0)) }
            ),
            httpClient: HarnessMockHTTPClient(defaultBehavior: httpBehavior),
            session: session,
            imageLoader: imageLoader,
            cache: HarnessInMemoryDataCache(),
            diagnostics: HarnessRecordingDiagnosticsClient()
        )
    }
}

private struct HarnessLaunchSessionDependencies {
    let authContextProvider: SessionAuthContextProvider
    let loginWebSession: LoginWebSession
    let store: SessionStore
}
#endif
