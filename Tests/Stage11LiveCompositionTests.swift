import Foundation
import Testing
@testable import TiebaLite

struct Stage11LiveCompositionTests {
    @MainActor
    @Test
    func productionCompositionSelectsLiveTransportExplicitly() {
        let environment = AppCompositionRoot.production().environment

        #expect(environment.readingDataSourceMode == .live)
        #expect(environment.httpClient is URLSessionHTTPClient)
        #expect(environment.imageLoader is DisabledImageLoader)
    }

    @MainActor
    @Test
    func productionCompositionUsesOneSessionAuthorizationOwner() {
        let root = AppCompositionRoot.production()
        let environmentProvider =
            root.environment.session as? SessionAuthContextProvider

        #expect(environmentProvider === root.authContextProvider)
    }

    @MainActor
    @Test
    func fixtureModeKeepsReadingFlowOffline() async {
        let client = HarnessMockHTTPClient(defaultBehavior: .failure(.offline))
        let root = AppCompositionRoot(
            environment: makeEnvironment(
                mode: .fixture,
                client: client,
                imageLoader: FixtureReadingImageLoader()
            )
        )

        let store = root.makeRecommendationsStore()
        await store.loadIfNeeded()

        guard case let .loaded(items) = store.state else {
            Issue.record("Fixture mode did not load its local catalog")
            return
        }
        #expect(!items.isEmpty)
        #expect(await client.events().isEmpty)
    }

    @MainActor
    @Test
    func liveModeConnectsTheActiveLeaseToRecommendationTransport() async throws {
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
            environment: makeEnvironment(
                mode: .live,
                client: client,
                imageLoader: DisabledImageLoader(),
                session: provider
            ),
            authContextProvider: provider
        )
        let recommendationStore = root.makeRecommendationsStore()

        await recommendationStore.loadIfNeeded()

        #expect(recommendationStore.state == .initialFailure(.unavailable))
        #expect(await client.events() == [
            .started(HarnessHTTPCallID(rawValue: 1)),
            .failed(HarnessHTTPCallID(rawValue: 1), .offline)
        ])
    }

    @MainActor
    @Test
    func liveModeUsesTheRuntimeVerifiedThreadTransport() async throws {
        let client = HarnessMockHTTPClient()
        let root = AppCompositionRoot(
            environment: makeEnvironment(
                mode: .live,
                client: client,
                imageLoader: DisabledImageLoader()
            )
        )

        let store = root.makeThreadReaderStore(threadID: 8_001)
        let load = Task {
            await store.loadIfNeeded()
        }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)

        #expect(
            call.request.url.absoluteString ==
                "https://tiebac.baidu.com/c/f/pb/page" +
                "?cmd=302001&format=protobuf"
        )
        store.cancel()
        await load.value
        #expect(await client.events() == [
            .started(call.id),
            .cancelled(call.id)
        ])
    }

    private func makeEnvironment(
        mode: ReadingDataSourceMode,
        client: any HTTPClient,
        imageLoader: any ImageLoading,
        session: (any SessionProviding)? = nil
    ) -> AppEnvironment {
        AppEnvironment(
            readingDataSourceMode: mode,
            clock: HarnessControlledClock(),
            idGenerator: HarnessSequenceIDGenerator(
                values: [OperationID(sequence: 1)]
            ),
            httpClient: client,
            session: session ?? HarnessFixtureSessionProvider(
                snapshot: SessionSnapshot(status: .signedOut, revision: 1)
            ),
            imageLoader: imageLoader,
            cache: HarnessInMemoryDataCache(),
            diagnostics: HarnessRecordingDiagnosticsClient()
        )
    }
}
