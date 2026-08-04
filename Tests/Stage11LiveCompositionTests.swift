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
    func liveModeFailsClosedWithoutFixtureOrTransportFallback() async {
        let client = HarnessMockHTTPClient()
        let root = AppCompositionRoot(
            environment: makeEnvironment(
                mode: .live,
                client: client,
                imageLoader: DisabledImageLoader()
            )
        )
        let recommendationStore = root.makeRecommendationsStore()
        let threadStore = root.makeThreadReaderStore(threadID: 8_001)

        await recommendationStore.loadIfNeeded()
        await threadStore.loadIfNeeded()

        #expect(recommendationStore.state == .initialFailure(.unavailable))
        #expect(threadStore.state == .initialFailure(.unavailable))
        #expect(await client.events().isEmpty)
    }

    @MainActor
    @Test
    func liveModeBlocksThreadTransportUntilRuntimeEvidenceExists() async {
        let client = HarnessMockHTTPClient()
        let root = AppCompositionRoot(
            environment: makeEnvironment(
                mode: .live,
                client: client,
                imageLoader: DisabledImageLoader()
            )
        )

        let store = root.makeThreadReaderStore(threadID: 8_001)
        await store.loadIfNeeded()

        #expect(store.state == .initialFailure(.unavailable))
        #expect(await client.events().isEmpty)
    }

    private func makeEnvironment(
        mode: ReadingDataSourceMode,
        client: any HTTPClient,
        imageLoader: any ImageLoading
    ) -> AppEnvironment {
        AppEnvironment(
            readingDataSourceMode: mode,
            clock: HarnessControlledClock(),
            idGenerator: HarnessSequenceIDGenerator(
                values: [OperationID(sequence: 1)]
            ),
            httpClient: client,
            session: HarnessFixtureSessionProvider(
                snapshot: SessionSnapshot(status: .signedOut, revision: 1)
            ),
            imageLoader: imageLoader,
            cache: HarnessInMemoryDataCache(),
            diagnostics: HarnessRecordingDiagnosticsClient()
        )
    }
}
