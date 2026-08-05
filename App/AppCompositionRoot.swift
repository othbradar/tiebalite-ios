@MainActor
final class AppCompositionRoot {
    let environment: AppEnvironment
    let authContextProvider: SessionAuthContextProvider
    let sessionStore: SessionStore
    let loginWebSession: LoginWebSession
    private let followedForumsRepository: any FollowedForumsRepository
    private let recommendationRepository: any RecommendationRepository
    private let threadReaderRepository: any ThreadReaderRepository

    init(
        environment: AppEnvironment,
        authContextProvider: SessionAuthContextProvider? = nil,
        sessionStore: SessionStore? = nil,
        loginWebSession: LoginWebSession? = nil
    ) {
        self.environment = environment
        let resolvedAuthContextProvider =
            authContextProvider ?? SessionAuthContextProvider()
        let resolvedLoginWebSession = loginWebSession ?? LoginWebSession()
        self.authContextProvider = resolvedAuthContextProvider
        self.loginWebSession = resolvedLoginWebSession
        self.sessionStore = sessionStore ?? SessionStore(
            credentialStore: EmptySessionCredentialStore(),
            authContextProvider: resolvedAuthContextProvider,
            websiteDataCleaner: resolvedLoginWebSession
        )
        switch environment.readingDataSourceMode {
        case .fixture:
            followedForumsRepository = FixtureFollowedForumsRepository()
            recommendationRepository = FixtureRecommendationRepository()
            threadReaderRepository = FixtureThreadReaderRepository()
        case .live:
            followedForumsRepository =
                EvidenceBlockedFollowedForumsRepository()
            recommendationRepository =
                EvidenceBlockedRecommendationRepository()
            threadReaderRepository = EvidenceBlockedThreadReaderRepository()
        }
    }

    func makeRecommendationsStore() -> RecommendationsStore {
        RecommendationsStore(repository: recommendationRepository)
    }

    func makeFollowedForumsStore() -> FollowedForumsStore {
        let sessionStore = sessionStore
        return FollowedForumsStore(
            repository: followedForumsRepository,
            expireSession: { context in
                await sessionStore.markExpired(context: context)
            }
        )
    }

    func makeThreadReaderStore(threadID: Int64) -> ThreadReaderStore {
        ThreadReaderStore(
            threadID: threadID,
            repository: threadReaderRepository
        )
    }

    static func production() -> AppCompositionRoot {
        let httpClient = URLSessionHTTPClient.production()
        let authContextProvider = SessionAuthContextProvider()
        let loginWebSession = LoginWebSession()
        let sessionStore = SessionStore(
            credentialStore: KeychainSessionCredentialStore(),
            authContextProvider: authContextProvider,
            websiteDataCleaner: loginWebSession
        )
        return AppCompositionRoot(
            environment: AppEnvironment(
                readingDataSourceMode: .live,
                clock: SystemAppClock(),
                idGenerator: MonotonicIDGenerator(),
                httpClient: httpClient,
                session: authContextProvider,
                imageLoader: DisabledImageLoader(),
                cache: NoStoreDataCache(),
                diagnostics: OSDiagnosticsClient()
            ),
            authContextProvider: authContextProvider,
            sessionStore: sessionStore,
            loginWebSession: loginWebSession
        )
    }
}
