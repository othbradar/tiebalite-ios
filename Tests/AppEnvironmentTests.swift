import Foundation
import Testing
@testable import TiebaLite

struct AppEnvironmentTests {
    @Test
    func everyDependencyCanBeReplacedWithoutGlobalState() async throws {
        let clock = HarnessControlledClock()
        let ids = HarnessSequenceIDGenerator(values: [OperationID(sequence: 7)])
        let http = HarnessMockHTTPClient(defaultBehavior: .failure(.offline))
        let session = HarnessFixtureSessionProvider(
            snapshot: SessionSnapshot(status: .signedIn, revision: 3)
        )
        let images = HarnessFixtureImageLoader(fixtures: [
            ImageRequest(resourceID: "fixture-image"): ImagePayload(
                data: Data("image".utf8),
                mediaType: "image/svg+xml"
            )
        ])
        let cache = HarnessInMemoryDataCache()
        let diagnostics = HarnessRecordingDiagnosticsClient()
        let environment = AppEnvironment(
            readingDataSourceMode: .fixture,
            clock: clock,
            idGenerator: ids,
            httpClient: http,
            session: session,
            imageLoader: images,
            cache: cache,
            diagnostics: diagnostics
        )

        #expect(environment.readingDataSourceMode == .fixture)
        #expect(await environment.clock.now == HarnessControlledClock.fixedEpoch)
        #expect(try await environment.idGenerator.next() == OperationID(sequence: 7))
        #expect(await environment.session.snapshot().status == .signedIn)
        #expect(
            try await environment.imageLoader.load(
                ImageRequest(resourceID: "fixture-image")
            ).mediaType == "image/svg+xml"
        )

        let cacheKey = CacheKey("fixture-cache")
        await environment.cache.store(Data("cached".utf8), for: cacheKey)
        #expect(await environment.cache.data(for: cacheKey) == Data("cached".utf8))

        let event = DiagnosticEvent(
            category: .application,
            operation: .appBootstrap,
            requestID: nil,
            result: .success
        )
        await environment.diagnostics.record(event)
        #expect(await diagnostics.events() == [event])

        let url = try #require(URL(string: "https://fixture.invalid/environment"))
        do {
            _ = try await environment.httpClient.execute(
                HTTPRequest(method: .get, url: url)
            )
            Issue.record("Expected injected offline transport")
        } catch let error as HTTPClientError {
            #expect(error == .offline)
        } catch {
            Issue.record("Injected HTTP dependency changed error category")
        }
    }

    @Test
    func preCancelledImageLoadsRemainCancellation() async {
        let request = ImageRequest(resourceID: "fixture-image")
        let loaders: [any ImageLoading] = [
            DisabledImageLoader(),
            HarnessFixtureImageLoader(fixtures: [
                request: ImagePayload(
                    data: Data("image".utf8),
                    mediaType: "image/svg+xml"
                )
            ])
        ]

        for loader in loaders {
            let task = Task {
                withUnsafeCurrentTask { currentTask in
                    currentTask?.cancel()
                }
                return try await loader.load(request)
            }

            do {
                _ = try await task.value
                Issue.record("Expected pre-cancelled image load")
            } catch is CancellationError {
                continue
            } catch {
                Issue.record("Image pre-cancellation changed error category")
            }
        }
    }
}
