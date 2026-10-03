import Foundation

@MainActor
final class AppCompositionRoot {
    let contentScheduler = ContentLoadScheduler()
    lazy var contentPrefetchEnvironment = ContentPrefetchEnvironment(settings: sharedSettingsStore)
    let environment: AppEnvironment
    let notificationsStore: NotificationsStore
    let currentAccountStore: CurrentAccountStore
    let notificationCounts: any NotificationCountSource
    private let notificationTargetRepository: any NotificationTargetRepository
    let authContextProvider: SessionAuthContextProvider
    let sessionStore: SessionStore
    let loginWebSession: LoginWebSession
    let textComposer: TextComposerService
    private let followedForumsRepository: any FollowedForumsRepository
    private let forumHomeRepository: any ForumHomeRepository
    private let browsingHistoryRepository: any BrowsingHistoryRepository
    private let contentCache: ContentPageCache
    private lazy var sharedSettingsStore = SettingsStore(repository: appSettingsRepository,
                                                         contentScheduler: contentScheduler, contentCache: contentCache)
    private let appSettingsRepository: any AppSettingsRepository
    private let recommendationRepository: any RecommendationRepository
    private let searchRepository: any SearchRepository
    private let subpostsRepository: any SubpostsRepository
    private let threadReaderRepository: any ThreadReaderRepository
    private let userProfileRepository: any UserProfileRepository

    init(
        environment: AppEnvironment,
        notificationCounts: (any NotificationCountSource)? = nil,
        authContextProvider: SessionAuthContextProvider? = nil,
        sessionStore: SessionStore? = nil,
        loginWebSession: LoginWebSession? = nil,
        browsingHistoryRepository: (any BrowsingHistoryRepository)? = nil,
        appSettingsRepository: (any AppSettingsRepository)? = nil,
        recommendationRepository: (any RecommendationRepository)? = nil,
        userProfileRepository: (any UserProfileRepository)? = nil,
        followedForumsRepository: (any FollowedForumsRepository)? = nil,
        forumHomeRepository: (any ForumHomeRepository)? = nil,
        forumHomeCache: ContentPageCache? = nil,
        threadReaderRepository: (any ThreadReaderRepository)? = nil
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
        let contentCache = forumHomeCache ?? ContentPageCache(directory: Self.contentCacheDirectory)
        self.contentCache = contentCache
        let scheduler = contentScheduler
        switch environment.readingDataSourceMode {
#if DEBUG
        case .fixture:
            currentAccountStore = CurrentAccountStore(repository: FixtureCurrentAccountRepository())
            notificationsStore = NotificationsStore(repository: FixtureNotificationsRepository())
            notificationTargetRepository = FixtureNotificationTargetRepository()
            textComposer = TextComposerService(repository: FixtureTextWriteRepository(), currentContext: {
                .active(.init(sessionID: .init(rawValue: 1), generation: 1))
            })
            self.browsingHistoryRepository = browsingHistoryRepository ?? InMemoryBrowsingHistoryRepository()
            self.appSettingsRepository = appSettingsRepository ?? InMemoryAppSettingsRepository()
            self.followedForumsRepository = followedForumsRepository ?? FixtureFollowedForumsRepository()
            let forumSource = forumHomeRepository ?? FixtureForumHomeRepository()
            self.forumHomeRepository = forumHomeCache.map {
                CachedForumHomeRepository(source: forumSource, cache: $0, clock: environment.clock, scheduler: scheduler,
                                          context: { resolvedAuthContextProvider.contentCacheContext })
            } ?? forumSource
            self.recommendationRepository = recommendationRepository ?? FixtureRecommendationRepository()
            searchRepository = FixtureSearchRepository()
            let reading = Self.readingRepositories(
                threads: threadReaderRepository ?? FixtureThreadReaderRepository(), subposts: FixtureSubpostsRepository(),
                cache: forumHomeCache.map { ($0, scheduler) }, environment: environment, auth: resolvedAuthContextProvider)
            subpostsRepository = reading.subposts
            self.threadReaderRepository = reading.threads
            self.userProfileRepository = userProfileRepository ?? FixtureUserProfileRepository()
#endif
        case .live:
            currentAccountStore = CurrentAccountStore(repository: LiveCurrentAccountRepository(
                client: environment.httpClient, authContextProvider: resolvedAuthContextProvider))
            notificationsStore = NotificationsStore(repository: LiveNotificationsRepository(
                client: environment.httpClient, authContextProvider: resolvedAuthContextProvider))
            notificationTargetRepository = LiveNotificationTargetRepository(client: environment.httpClient)
            textComposer = TextComposerService(repository: LiveTextWriteRepository(
                client: environment.httpClient, authContextProvider: resolvedAuthContextProvider),
                uploader: LiveComposerImageUploader(client: environment.httpClient, authContextProvider: resolvedAuthContextProvider),
                imageLoader: environment.imageLoader,
                currentContext: { resolvedAuthContextProvider.context() })
            self.browsingHistoryRepository = browsingHistoryRepository ?? JSONBrowsingHistoryRepository.production()
            self.appSettingsRepository = appSettingsRepository ?? UserDefaultsAppSettingsRepository()
            self.followedForumsRepository =
                LiveFollowedForumsRepository(
                    client: environment.httpClient,
                    authContextProvider: resolvedAuthContextProvider
                )
            self.forumHomeRepository = CachedForumHomeRepository(
                source: LiveForumHomeRepository(client: environment.httpClient), cache: contentCache,
                clock: environment.clock, scheduler: contentScheduler, context: { resolvedAuthContextProvider.contentCacheContext })
            self.recommendationRepository =
                recommendationRepository ?? LiveRecommendationRepository(
                    client: environment.httpClient,
                    authContextProvider: resolvedAuthContextProvider
                )
            searchRepository = LiveSearchRepository(client: environment.httpClient)
            let reading = CachedReadingRepository(
                threads: LiveThreadReaderRepository(client: environment.httpClient),
                subposts: LiveSubpostsRepository(client: environment.httpClient), cache: contentCache,
                clock: environment.clock, scheduler: contentScheduler, context: { resolvedAuthContextProvider.contentCacheContext })
            subpostsRepository = reading
            self.threadReaderRepository = reading
            self.userProfileRepository =
                userProfileRepository ?? LiveUserProfileRepository(
                    client: environment.httpClient
                )
        }
        self.notificationCounts = notificationCounts ?? notificationsStore
    }

    private static var contentCacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TiebaLiteContent-v1", isDirectory: true)
    }

    private static func readingRepositories(
        threads: any ThreadReaderRepository, subposts: any SubpostsRepository,
        cache: (pages: ContentPageCache, scheduler: ContentLoadScheduler)?,
        environment: AppEnvironment, auth: SessionAuthContextProvider
    ) -> (threads: any ThreadReaderRepository, subposts: any SubpostsRepository) {
        guard let cache else { return (threads, subposts) }
        let adapter = CachedReadingRepository(threads: threads, subposts: subposts, cache: cache.pages,
                                              clock: environment.clock, scheduler: cache.scheduler, context: { auth.contentCacheContext })
        return (adapter, adapter)
    }

    func makeNotificationDestination(target: NotificationTarget) -> NotificationDestinationStore {
        NotificationDestinationStore(target: target, repository: notificationTargetRepository,
                                     threads: threadReaderRepository)
    }

    func makeMediaExportStore() -> MediaExportStore {
#if UITESTING
        if environment.readingDataSourceMode == .fixture {
            return MediaExportStore(fetcher: OriginalImageFileFetcher(loader: HarnessExportImageTransport()),
                                    writer: HarnessExportPhotoWriter())
        }
#endif
        return MediaExportStore(fetcher: OriginalImageFileFetcher.production(), writer: PhotoLibraryWriter())
    }

    func makeBrowsingHistoryStore() -> BrowsingHistoryStore {
        BrowsingHistoryStore(
            repository: browsingHistoryRepository,
            clock: environment.clock
        )
    }

    func makeSettingsStore() -> SettingsStore {
        sharedSettingsStore
    }

    func makeRecommendationsStore() -> RecommendationsStore {
        RecommendationsStore(repository: recommendationRepository, prefetch: makeContentPrefetchSession())
    }

    func makeFollowedForumsStore() -> FollowedForumsStore {
        let sessionStore = sessionStore
        return FollowedForumsStore(
            repository: followedForumsRepository,
            prefetch: makeContentPrefetchSession(),
            expireSession: { context in
                await sessionStore.markExpired(context: context)
            }
        )
    }

    func makeSearchStore() -> SearchStore {
        SearchStore(repository: searchRepository)
    }

    func makeForumHomeStore(route: ForumRoute) -> ForumHomeStore {
        ForumHomeStore(route: route, repository: forumHomeRepository,
                       sortPreferences: sharedSettingsStore, prefetch: makeContentPrefetchSession())
    }

    func makeThreadReaderStore(threadID: Int64) -> ThreadReaderStore {
        ThreadReaderStore(
            threadID: threadID,
            repository: threadReaderRepository, prefetch: makeContentPrefetchSession()
        )
    }

    private func makeContentPrefetchSession() -> ContentPrefetchSession {
        let settings = sharedSettingsStore
        return ContentPrefetchSession(
            candidates: contentPrefetchEnvironment.makeScope(),
            nextPage: contentPrefetchEnvironment.makeScope(),
            threads: threadReaderRepository as? any ThreadContentPrefetching,
            forums: forumHomeRepository as? any ForumContentPrefetching,
            sort: { settings.forumSortPreferences.order(for: $0) })
    }

    func makeSubpostsStore(route: SubpostsRoute) -> SubpostsStore {
        SubpostsStore(route: route, repository: subpostsRepository)
    }

    func makeUserProfileStore(route: UserProfileRoute) -> UserProfileStore {
        UserProfileStore(route: route, repository: userProfileRepository)
    }

    static func production() -> AppCompositionRoot {
        let httpClient = URLSessionHTTPClient.production()
        let authContextProvider = SessionAuthContextProvider(
            cacheNamespaceStore: LocalContentCacheAccountNamespace(defaults: .standard)
        )
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
                imageLoader: ProductionImageLoader.production(),
                cache: NoStoreDataCache(),
                diagnostics: OSDiagnosticsClient()
            ),
            authContextProvider: authContextProvider,
            sessionStore: sessionStore,
            loginWebSession: loginWebSession
        )
    }
}
