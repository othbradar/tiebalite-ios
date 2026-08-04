struct EvidenceBlockedThreadReaderRepository: ThreadReaderRepository {
    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        _ = threadID
        try Task.checkCancellation()
        throw LiveReadingCapabilityError.runtimeEvidenceUnavailable
    }
}

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

    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        let input = try PBPageRequestInput(threadID: threadID)
        let endpoint = try PBPageProtocol.makeDescriptor(host: host)
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: FixtureOnlyRequestAuthorizer()
            )
        )
        let snapshot = try await executor.execute(
            endpoint: endpoint,
            authentication: .anonymous,
            body: try PBPageProtocol.makeRequestBody(input),
            pipeline: PBPageProtocol.pipeline(requestedThreadID: threadID)
        )
        try Task.checkCancellation()
        return snapshot
    }
}
