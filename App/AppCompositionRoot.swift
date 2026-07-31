@MainActor
final class AppCompositionRoot {
    let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    static func production() -> AppCompositionRoot {
        AppCompositionRoot(
            environment: AppEnvironment(
                clock: SystemAppClock(),
                idGenerator: MonotonicIDGenerator(),
                httpClient: DisabledHTTPClient(),
                session: SignedOutSessionProvider(),
                imageLoader: DisabledImageLoader(),
                cache: NoStoreDataCache(),
                diagnostics: OSDiagnosticsClient()
            )
        )
    }
}
