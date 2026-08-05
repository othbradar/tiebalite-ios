struct EvidenceBlockedForumHomeRepository: ForumHomeRepository {
    func loadForumHome(route: ForumRoute) async throws -> ForumHomeSnapshot {
        _ = route
        try Task.checkCancellation()
        throw LiveReadingCapabilityError.runtimeEvidenceUnavailable
    }
}

struct LiveForumHomeRepository: ForumHomeRepository {
    private let client: any HTTPClient
    private let host: String

    init(
        client: any HTTPClient,
        host: String = "tiebac.baidu.com"
    ) {
        self.client = client
        self.host = host
    }

    func loadForumHome(
        route: ForumRoute
    ) async throws -> ForumHomeSnapshot {
        let endpoint = try FRSPageProtocol.makeDescriptor(
            host: host,
            route: route
        )
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: FixtureOnlyRequestAuthorizer()
            )
        )
        let snapshot = try await executor.execute(
            endpoint: endpoint,
            authentication: .anonymous,
            body: try FRSPageProtocol.makeRequestBody(route: route),
            pipeline: FRSPageProtocol.pipeline(requestedRoute: route)
        )
        try Task.checkCancellation()
        return snapshot
    }
}
