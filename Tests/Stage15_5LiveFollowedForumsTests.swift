import Testing
@testable import TiebaLite

@MainActor
struct Stage15Point5LiveFollowedForumsTests {
    @Test
    func replacementLeaseRejectsTheOldForumGuideResponse() async throws {
        let client = HarnessMockHTTPClient()
        let provider = SessionAuthContextProvider()
        provider.install(
            try #require(
                SessionCredential(bduss: "fx-old-b", stoken: "fx-old-s")
            )
        )
        let oldContext = provider.context()
        let repository = LiveFollowedForumsRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadFollowedForums(
                authentication: oldContext
            )
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        provider.install(
            try #require(
                SessionCredential(bduss: "fx-new-b", stoken: "fx-new-s")
            )
        )
        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type":
                        ForumGuideProtocol.candidateLiveResponseMIMEType
                ],
                body: try FixtureLoader.loadTestBundleData(
                    id: FixtureID(
                        "followed-forums.forum-guide.synthetic"
                    ),
                    expectedFormat: .protobuf
                )
            )
        )

        await #expect(throws: RequestAuthorizationError.contextMismatch) {
            try await load.value
        }
    }

    @Test
    func liveCompositionConnectsTheActiveLeaseToForumGuideTransport() async throws {
        let client = HarnessMockHTTPClient(
            defaultBehavior: .failure(.offline)
        )
        let provider = SessionAuthContextProvider()
        provider.install(
            try #require(
                SessionCredential(
                    bduss: "fx-composition-b",
                    stoken: "fx-composition-s"
                )
            )
        )
        let root = AppCompositionRoot(
            environment: AppEnvironment(
                readingDataSourceMode: .live,
                clock: HarnessControlledClock(),
                idGenerator: HarnessSequenceIDGenerator(
                    values: [OperationID(sequence: 1)]
                ),
                httpClient: client,
                session: provider,
                imageLoader: DisabledImageLoader(),
                cache: HarnessInMemoryDataCache(),
                diagnostics: HarnessRecordingDiagnosticsClient()
            ),
            authContextProvider: provider
        )
        let store = root.makeFollowedForumsStore()

        await store.synchronize(with: .active(provider.context()))

        #expect(store.state == .initialFailure(.unavailable))
        #expect(await client.events() == [
            .started(HarnessHTTPCallID(rawValue: 1)),
            .failed(HarnessHTTPCallID(rawValue: 1), .offline)
        ])
    }
}
