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
        try await loadPage(.initial).items
    }

    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage {
        try Task.checkCancellation()
        guard request.isValid else {
            throw RecommendationRepositoryError.invalidRequest
        }
        let context = await authContextProvider.context()
        let authorization = try await authContextProvider.authorization(
            for: context
        )
        let input = try PersonalizedRequestInput(
            loadKind: personalizedLoadKind(for: request.loadKind),
            page: request.page
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
        return RecommendationRepositoryPage(
            items: Self.makeSummaries(from: page),
            requestedPage: page.requestedPage,
            nextPageCandidate: page.nextPageCandidate
        )
    }

    private func personalizedLoadKind(
        for loadKind: RecommendationPageLoadKind
    ) -> PersonalizedLoadKind {
        switch loadKind {
        case .refresh:
            .refresh
        case .nextPage:
            .nextPage
        }
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
            let title = nonempty(item.title, fallback: "无标题")
            return RecommendationSummary(
                threadID: threadID,
                title: title,
                forumName: nonempty(item.forumName, fallback: "未知吧"),
                authorName: authorName(item.author),
                replyCount: max(0, item.replyCount),
                thumbnail: item.thumbnailResource.map {
                    RecommendationThumbnail(
                        resource: $0,
                        alternativeText: "\(title) 的缩略图"
                    )
                }
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
