struct EvidenceBlockedForumHomeRepository: ForumHomeRepository {
    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        _ = request
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

    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        let endpoint = try FRSPageProtocol.makeDescriptor(
            host: host,
            route: request.route
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
            body: try FRSPageProtocol.makeRequestBody(request: request),
            pipeline: FRSPageProtocol.pipeline(request: request)
        )
        try Task.checkCancellation()
        return snapshot
    }
}
