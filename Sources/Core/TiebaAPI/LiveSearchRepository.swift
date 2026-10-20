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

    func search(_ query: SearchQuery) async throws -> SearchSnapshot {
        switch query.type {
        case .users:
            let users = try await executor.execute(
                endpoint: SearchUserWebProtocol.makeDescriptor(host: host, keyword: query.keyword),
                authentication: .anonymous, body: .none, pipeline: SearchUserWebProtocol.pipeline()
            )
            return SearchSnapshot(query: query, forums: [], threads: [], users: users,
                                  currentThreadPage: 1, hasMoreThreads: false)
        case .forums:
            let forums = try await loadForums(keyword: query.keyword)
            return SearchSnapshot(query: query, forums: forums, threads: [], currentThreadPage: 1, hasMoreThreads: false)
        case .threads:
            guard let request = SearchThreadPageRequest(query: query, page: 1) else {
                throw SearchWebProtocolError.invalidStaticConfiguration
            }
            let page = try await loadThreadPage(request)
            return SearchSnapshot(query: query, forums: [], threads: page.items,
                                  currentThreadPage: page.currentPage, hasMoreThreads: page.hasMore)
        }
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
        let endpoint = try request.query.scope == .global
            ? SearchWebProtocol.makeThreadDescriptor(host: host, request: request)
            : InForumSearchProtocol.makeDescriptor(host: host, request: request)
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
                authorizer: AnonymousRequestAuthorizer()
            )
        )
    }
}
