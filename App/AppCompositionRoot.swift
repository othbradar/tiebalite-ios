@MainActor
final class AppCompositionRoot {
    let environment: AppEnvironment
    private let recommendationRepository: any RecommendationRepository
    private let threadReaderRepository: any ThreadReaderRepository

    init(
        environment: AppEnvironment
    ) {
        self.environment = environment
        switch environment.readingDataSourceMode {
        case .fixture:
            recommendationRepository = FixtureRecommendationRepository()
            threadReaderRepository = FixtureThreadReaderRepository()
        case .live:
            recommendationRepository =
                EvidenceBlockedRecommendationRepository()
            threadReaderRepository = EvidenceBlockedThreadReaderRepository()
        }
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
        let httpClient = URLSessionHTTPClient.production()
        return AppCompositionRoot(
            environment: AppEnvironment(
                readingDataSourceMode: .live,
                clock: SystemAppClock(),
                idGenerator: MonotonicIDGenerator(),
                httpClient: httpClient,
                session: SignedOutSessionProvider(),
                imageLoader: DisabledImageLoader(),
                cache: NoStoreDataCache(),
                diagnostics: OSDiagnosticsClient()
            )
        )
    }
}
