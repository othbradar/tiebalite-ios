struct LiveSearchRepository: SearchRepository {
    private let client: any HTTPClient
    private let host: String

    init(
        client: any HTTPClient,
        host: String = "tieba.baidu.com"
    ) {
        self.client = client
        self.host = host
    }

    func search(keyword: SearchKeyword) async throws -> SearchSnapshot {
        guard let request = SearchThreadPageRequest(
            keyword: keyword,
            page: 1
        ) else {
            throw SearchWebProtocolError.invalidStaticConfiguration
        }
        async let forums = loadForums(keyword: keyword)
        async let threadPage = loadThreadPage(request)
        let (forumResults, page) = try await (forums, threadPage)
        try Task.checkCancellation()
        return SearchSnapshot(
            keyword: keyword,
            forums: forumResults,
            threads: page.items,
            currentThreadPage: page.currentPage,
            hasMoreThreads: page.hasMore
        )
    }

    func loadForums(
        keyword: SearchKeyword
    ) async throws -> [ForumSearchResult] {
        let endpoint = try SearchWebProtocol.makeForumDescriptor(
            host: host,
            keyword: keyword
        )
        return try await executor.execute(
            endpoint: endpoint,
            authentication: .anonymous,
            body: .none,
            pipeline: SearchWebProtocol.forumPipeline()
        )
    }

    func loadThreadPage(
        _ request: SearchThreadPageRequest
    ) async throws -> ThreadSearchPage {
        let endpoint = try SearchWebProtocol.makeThreadDescriptor(
            host: host,
            request: request
        )
        return try await executor.execute(
            endpoint: endpoint,
            authentication: .anonymous,
            body: .none,
            pipeline: SearchWebProtocol.threadPipeline(request: request)
        )
    }

    private var executor: EndpointExecutor {
        EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: FixtureOnlyRequestAuthorizer()
            )
        )
    }
}
