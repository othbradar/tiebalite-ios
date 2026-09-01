enum ReadingDataSourceMode: Equatable, Sendable {
#if DEBUG
    case fixture
#endif
    case live
}

enum RecommendationsAccessPolicy: Equatable, Sendable {
    case activeSessionRequired
    case unrestrictedFixture
}

struct AppEnvironment: Sendable {
    let readingDataSourceMode: ReadingDataSourceMode
    let recommendationsAccessPolicy: RecommendationsAccessPolicy
    let clock: any AppClock
    let idGenerator: any IDGenerator
    let httpClient: any HTTPClient
    let session: any SessionProviding
    let imageLoader: any ImageLoading
    let cache: any DataCaching
    let diagnostics: any DiagnosticsClient

    init(
        readingDataSourceMode: ReadingDataSourceMode,
        clock: any AppClock,
        idGenerator: any IDGenerator,
        httpClient: any HTTPClient,
        session: any SessionProviding,
        imageLoader: any ImageLoading,
        cache: any DataCaching,
        diagnostics: any DiagnosticsClient,
        recommendationsAccessPolicy: RecommendationsAccessPolicy? = nil
    ) {
        self.readingDataSourceMode = readingDataSourceMode
        self.recommendationsAccessPolicy =
            recommendationsAccessPolicy
            ?? (readingDataSourceMode == .live
                ? .activeSessionRequired
                : .unrestrictedFixture)
        self.clock = clock
        self.idGenerator = idGenerator
        self.httpClient = httpClient
        self.session = session
        self.imageLoader = imageLoader
        self.cache = cache
        self.diagnostics = diagnostics
    }
}
