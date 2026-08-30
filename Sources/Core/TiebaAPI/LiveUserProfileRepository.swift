struct LiveUserProfileRepository: UserProfileRepository {
    private let client: any HTTPClient
    private let host: String

    init(
        client: any HTTPClient,
        host: String = "tiebac.baidu.com"
    ) {
        self.client = client
        self.host = host
    }

    func loadProfile(route: UserProfileRoute) async throws -> UserProfile {
        let endpoint = try ProfileProtocol.makeDescriptor(host: host)
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: FixtureOnlyRequestAuthorizer()
            )
        )
        let result = try await executor.execute(
            endpoint: endpoint,
            authentication: .anonymous,
            body: try ProfileProtocol.makeRequestBody(route: route),
            pipeline: ProfileProtocol.pipeline(requestedRoute: route)
        )
        try Task.checkCancellation()
        switch result {
        case .empty:
            throw UserProfileRepositoryError.empty
        case let .loaded(profile):
            return profile
        }
    }
}
