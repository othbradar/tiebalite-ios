struct LiveFollowedForumsRepository: FollowedForumsRepository {
    private let client: any HTTPClient
    private let authContextProvider: any AuthContextProviding
    private let host: String

    init(
        client: any HTTPClient,
        authContextProvider: any AuthContextProviding,
        host: String = "tiebac.baidu.com"
    ) {
        self.client = client
        self.authContextProvider = authContextProvider
        self.host = host
    }

    func loadFollowedForums(
        authentication: AuthContext
    ) async throws -> [FollowedForum] {
        try Task.checkCancellation()
        let authorization = try await authContextProvider.authorization(
            for: authentication
        )
        let endpoint = try ForumGuideProtocol.makeDescriptor(host: host)
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: ActiveSessionRequestAuthorizer(
                    authContextProvider: authContextProvider
                )
            )
        )
        let forums = try await executor.execute(
            endpoint: endpoint,
            authentication: authentication,
            body: try ForumGuideProtocol.makeAuthenticatedRequestBody(
                authorization: authorization
            ),
            pipeline: ForumGuideProtocol.pipeline
        )
        try Task.checkCancellation()
        _ = try await authContextProvider.authorization(for: authentication)
        return forums
    }
}
