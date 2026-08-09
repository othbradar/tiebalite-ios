import Foundation

enum LiveReadingCapabilityError: Error, Equatable, Sendable {
    case runtimeEvidenceUnavailable
}

struct LiveRecommendationRepository: RecommendationRepository {
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

    func loadRecommendations() async throws -> [RecommendationSummary] {
        try Task.checkCancellation()
        let context = await authContextProvider.context()
        let authorization = try await authContextProvider.authorization(
            for: context
        )
        let input = try PersonalizedRequestInput(
            loadKind: .refresh,
            page: 1
        )
        let endpoint = try PersonalizedProtocol.makeActiveDescriptor(host: host)
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: ActiveSessionRequestAuthorizer(
                    authContextProvider: authContextProvider
                )
            )
        )
        let page = try await executor.execute(
            endpoint: endpoint,
            authentication: context,
            body: try PersonalizedProtocol.makeAuthenticatedRequestBody(
                input,
                authorization: authorization
            ),
            pipeline: PersonalizedProtocol.pipeline(requestedPage: input.page)
        )
        try Task.checkCancellation()
        _ = try await authContextProvider.authorization(for: context)
        return Self.makeSummaries(from: page)
    }

    private static func makeSummaries(
        from page: RecommendationPage
    ) -> [RecommendationSummary] {
        var seenThreadIDs: Set<Int64> = []
        return page.items.compactMap { item in
            let threadID = item.rawFeedID
            guard threadID > 0,
                  seenThreadIDs.insert(threadID).inserted else {
                return nil
            }
            return RecommendationSummary(
                threadID: threadID,
                title: nonempty(item.title, fallback: "无标题"),
                forumName: nonempty(item.forumName, fallback: "未知吧"),
                authorName: authorName(item.author),
                replyCount: max(0, item.replyCount),
                thumbnail: nil
            )
        }
    }

    private static func authorName(
        _ author: RecommendationAuthor?
    ) -> String {
        guard let author else {
            return "未知作者"
        }
        let displayName = nonempty(author.nameShow, fallback: author.name)
        return nonempty(displayName, fallback: "未知作者")
    }

    private static func nonempty(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
