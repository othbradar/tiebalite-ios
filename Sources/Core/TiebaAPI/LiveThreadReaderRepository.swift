struct LiveThreadReaderRepository: ThreadReaderRepository {
    private let client: any HTTPClient
    private let host: String

    init(
        client: any HTTPClient,
        host: String = "tiebac.baidu.com"
    ) {
        self.client = client
        self.host = host
    }

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        let input = try PBPageRequestInput(
            threadID: request.threadID,
            pageNumber: request.pageNumber,
            postID: request.postID
        )
        let endpoint = try PBPageProtocol.makeDescriptor(host: host)
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: AnonymousRequestAuthorizer()
            )
        )
        let snapshot = try await executor.execute(
            endpoint: endpoint,
            authentication: .anonymous,
            body: try PBPageProtocol.makeRequestBody(input),
            pipeline: PBPageProtocol.pipeline(request: request)
        )
        try Task.checkCancellation()
        return snapshot
    }
}
