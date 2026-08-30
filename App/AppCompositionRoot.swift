@MainActor
final class AppCompositionRoot {
    let environment: AppEnvironment
    let authContextProvider: SessionAuthContextProvider
    let sessionStore: SessionStore
    let loginWebSession: LoginWebSession
    private let followedForumsRepository: any FollowedForumsRepository
    private let forumHomeRepository: any ForumHomeRepository
    private let browsingHistoryRepository: any BrowsingHistoryRepository
    private let appSettingsRepository: any AppSettingsRepository
    private let recommendationRepository: any RecommendationRepository
    private let searchRepository: any SearchRepository
    private let threadReaderRepository: any ThreadReaderRepository
    private let userProfileRepository: any UserProfileRepository

    init(
        environment: AppEnvironment,
        authContextProvider: SessionAuthContextProvider? = nil,
        sessionStore: SessionStore? = nil,
        loginWebSession: LoginWebSession? = nil,
        browsingHistoryRepository: (any BrowsingHistoryRepository)? = nil,
        appSettingsRepository: (any AppSettingsRepository)? = nil,
        userProfileRepository: (any UserProfileRepository)? = nil
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
            self.browsingHistoryRepository =
                browsingHistoryRepository
                ?? InMemoryBrowsingHistoryRepository()
            self.appSettingsRepository =
                appSettingsRepository ?? InMemoryAppSettingsRepository()
            followedForumsRepository = FixtureFollowedForumsRepository()
            forumHomeRepository = FixtureForumHomeRepository()
            recommendationRepository = FixtureRecommendationRepository()
            searchRepository = FixtureSearchRepository()
            threadReaderRepository = FixtureThreadReaderRepository()
            self.userProfileRepository =
                userProfileRepository ?? FixtureUserProfileRepository()
        case .live:
            self.browsingHistoryRepository =
                browsingHistoryRepository
                ?? JSONBrowsingHistoryRepository.production()
            self.appSettingsRepository =
                appSettingsRepository ?? UserDefaultsAppSettingsRepository()
            followedForumsRepository =
                LiveFollowedForumsRepository(
                    client: environment.httpClient,
                    authContextProvider: resolvedAuthContextProvider
                )
            forumHomeRepository = LiveForumHomeRepository(
                client: environment.httpClient
            )
            recommendationRepository =
                LiveRecommendationRepository(
                    client: environment.httpClient,
                    authContextProvider: resolvedAuthContextProvider
                )
            searchRepository = LiveSearchRepository(
                client: environment.httpClient
            )
            threadReaderRepository = LiveThreadReaderRepository(
                client: environment.httpClient
            )
            self.userProfileRepository =
                userProfileRepository ?? LiveUserProfileRepository(
                    client: environment.httpClient
                )
        }
    }

    func makeBrowsingHistoryStore() -> BrowsingHistoryStore {
        BrowsingHistoryStore(
            repository: browsingHistoryRepository,
            clock: environment.clock
        )
    }

    func makeSettingsStore() -> SettingsStore {
        SettingsStore(repository: appSettingsRepository)
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

    func makeSearchStore() -> SearchStore {
        SearchStore(repository: searchRepository)
    }

    func makeForumHomeStore(route: ForumRoute) -> ForumHomeStore {
        ForumHomeStore(route: route, repository: forumHomeRepository)
    }

    func makeThreadReaderStore(threadID: Int64) -> ThreadReaderStore {
        ThreadReaderStore(
            threadID: threadID,
            repository: threadReaderRepository
        )
    }

    func makeUserProfileStore(route: UserProfileRoute) -> UserProfileStore {
        UserProfileStore(route: route, repository: userProfileRepository)
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
