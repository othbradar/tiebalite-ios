struct AppEnvironment: Sendable {
    let clock: any AppClock
    let idGenerator: any IDGenerator
    let httpClient: any HTTPClient
    let session: any SessionProviding
    let imageLoader: any ImageLoading
    let cache: any DataCaching
    let diagnostics: any DiagnosticsClient
}
