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
        case .sessionSignedInFixture, .rootNavigationMixedMedia, .dynamicFeedParity, .forumHomeParity, .threadReaderParity:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .signedIn
            safeLabel = signedInLabel(for: scenario)
            imageLoader = signedInImageLoader(for: scenario)
        case .sessionExpired:
            networkMode = .controlled
            httpBehavior = .controlled
            sessionStatus = .expired
            safeLabel = "Harness: Session expired"
            imageLoader = HarnessFixtureImageLoader(fixtures: [:])
        }

        let sessionDependencies = makeSessionDependencies(status: sessionStatus)
        let environment = makeEnvironment(
            scenario: scenario,
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
                notificationCounts: notificationCounts(for: scenario),
                authContextProvider: sessionDependencies.authContextProvider,
                sessionStore: sessionDependencies.store,
                loginWebSession: sessionDependencies.loginWebSession,
                recommendationRepository: recommendationRepository(for: scenario),
                followedForumsRepository: followedForumsRepository(for: scenario),
                forumHomeRepository: scenario == .forumHomeParity ? R05ForumFixture() : nil,
                threadReaderRepository: scenario == .threadReaderParity ? R06ThreadFixtureRepository() : nil
            ),
            isolationCanary: LaunchScenarioRegistry.isolationCanary,
            displayProfile: displayProfile
        )
    }

    private static func followedForumsRepository(for scenario: LaunchScenarioID) -> (any FollowedForumsRepository)? {
        scenario == .rootNavigationMixedMedia ? FixtureFollowedForumsRepository(additionalForumCount: 24) : nil
    }

    private static func notificationCounts(for scenario: LaunchScenarioID) -> NotificationBadgeState {
        NotificationBadgeState(
            unreadCount: [.sessionSignedInFixture, .rootNavigationMixedMedia].contains(scenario) ? 3 : 0
        )
    }

    private static func signedInLabel(for scenario: LaunchScenarioID) -> String {
        switch scenario {
        case .threadReaderParity: "Harness: Thread parity"
        case .forumHomeParity: "Harness: Forum parity"
        case .dynamicFeedParity: "Harness: Dynamic parity"
        case .rootNavigationMixedMedia: "Harness: Mixed-size root media"
        default: "Harness: Session signed in fixture"
        }
    }

    private static func signedInImageLoader(for scenario: LaunchScenarioID) -> any ImageLoading {
        switch scenario {
        case .threadReaderParity: R06ThreadFixtureImages()
        case .dynamicFeedParity, .forumHomeParity: R04FeedFixtureImages()
        case .rootNavigationMixedMedia: HarnessMixedSizeImageLoader()
        default: FixtureReadingImageLoader()
        }
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
        scenario: LaunchScenarioID,
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
            diagnostics: HarnessRecordingDiagnosticsClient(),
            recommendationsAccessPolicy: scenario == .sessionSignedOut
                ? .activeSessionRequired
                : nil
        )
    }

    private static func recommendationRepository(
        for scenario: LaunchScenarioID
    ) -> (any RecommendationRepository)? {
        switch scenario {
        case .networkOffline: HarnessRecoveringRecommendations()
        case .rootNavigationMixedMedia: HarnessMixedMetadataRecommendations()
        case .dynamicFeedParity: R04FeedFixture()
        default: nil
        }
    }
}

private actor HarnessRecoveringRecommendations: RecommendationRepository {
    private var requestCount = 0
    private let fixture = FixtureRecommendationRepository()

    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await loadPage(.initial).items
    }

    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage {
        requestCount += 1
        guard requestCount > 1 else {
            throw HTTPClientError.offline
        }
        return try await fixture.loadPage(request)
    }
}

private struct HarnessLaunchSessionDependencies {
    let authContextProvider: SessionAuthContextProvider
    let loginWebSession: LoginWebSession
    let store: SessionStore
}
#endif
