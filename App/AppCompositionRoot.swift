@MainActor
final class AppCompositionRoot {
    let environment: AppEnvironment
    private let recommendationRepository: any RecommendationRepository
    private let threadReaderRepository: any ThreadReaderRepository

    init(
        environment: AppEnvironment,
        recommendationRepository: any RecommendationRepository =
            FixtureRecommendationRepository(),
        threadReaderRepository: any ThreadReaderRepository =
            FixtureThreadReaderRepository()
    ) {
        self.environment = environment
        self.recommendationRepository = recommendationRepository
        self.threadReaderRepository = threadReaderRepository
    }

    func makeRecommendationsStore() -> RecommendationsStore {
        RecommendationsStore(repository: recommendationRepository)
    }

    func makeThreadReaderStore(threadID: Int64) -> ThreadReaderStore {
        ThreadReaderStore(
            threadID: threadID,
            repository: threadReaderRepository
        )
    }

    static func production() -> AppCompositionRoot {
        AppCompositionRoot(
            environment: AppEnvironment(
                clock: SystemAppClock(),
                idGenerator: MonotonicIDGenerator(),
                httpClient: DisabledHTTPClient(),
                session: SignedOutSessionProvider(),
                imageLoader: FixtureReadingImageLoader(),
                cache: NoStoreDataCache(),
                diagnostics: OSDiagnosticsClient()
            )
        )
    }
}
