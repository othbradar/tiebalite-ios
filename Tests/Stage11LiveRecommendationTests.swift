import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct Stage11LiveRecommendationTests {
    @Test
    func liveRepositoryUsesRestoredActiveLeaseAndMapsDomain() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadRecommendations()
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(
            call.request.url.absoluteString ==
                "https://fixture.invalid/c/f/excellent/personalized?cmd=309264"
        )
        #expect(call.request.headers["x_bd_data_type"] == "protobuf")
        #expect(call.request.headers["Authorization"] == nil)
        #expect(call.request.headers["Cookie"] == nil)
        #expect(!(try #require(call.request.body)).isEmpty)

        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try personalizedFixtureData()
            )
        )

        let summaries = try await load.value
        #expect(summaries.map(\.threadID) == [1001, 1002])
        #expect(summaries.allSatisfy { !$0.title.isEmpty })
        #expect(summaries.allSatisfy { $0.threadID > 0 })
    }

    @Test
    func liveRepositoryProjectsEvidenceBackedThumbnailResources() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadRecommendations()
        }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        var media = Tieba_Media()
        media.bigPic = "https://images.fixture.invalid/big.jpg"
        media.srcPic = "https://images.fixture.invalid/source.jpg"
        var thread = Tieba_ThreadInfo()
        thread.id = 7_001
        thread.threadID = 7_001
        thread.title = "带图帖子"
        thread.forumName = "Fixture吧"
        thread.media = [media]
        var data = Tieba_PersonalizedResponseData()
        data.threadList = [thread]
        var response = Tieba_PersonalizedResponse()
        response.data = data

        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try response.serializedData()
            )
        )

        let summaries = try await load.value
        let thumbnail = try #require(summaries.first?.thumbnail)
        #expect(thumbnail.resource.resourceID == "recommendation.t7001.media.1")
        #expect(thumbnail.resource.candidateURLs == [
            "https://images.fixture.invalid/big.jpg",
            "https://images.fixture.invalid/source.jpg"
        ])
    }

    @Test
    func liveRepositoryMapsAnExplicitEmptyEnvelopeToEmptyDomain() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadRecommendations()
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        var response = Tieba_PersonalizedResponse()
        response.error = Tieba_Error()
        response.data = Tieba_PersonalizedResponseData()
        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try response.serializedData()
            )
        )

        #expect(try await load.value == [])
    }

    @Test
    func liveRepositoryKeepsHTTPFailureTyped() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadRecommendations()
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        try await client.succeed(
            call.id,
            with: HTTPResponse(statusCode: 503)
        )

        await #expect(
            throws: EndpointExecutionError.http(statusCode: 503)
        ) {
            try await load.value
        }
    }

    @Test
    func liveRepositoryKeepsCancellationObservable() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadRecommendations()
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        load.cancel()

        await #expect(throws: CancellationError.self) {
            try await load.value
        }
        #expect(await client.events() == [
            .started(call.id),
            .cancelled(call.id)
        ])
    }

    @Test
    func signedOutRecommendationFailsClosedWithoutSendingHTTP() async {
        let client = HarnessMockHTTPClient()
        let provider = SessionAuthContextProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )

        await #expect(throws: RequestAuthorizationError.self) {
            _ = try await repository.loadRecommendations()
        }
        #expect(await client.events().isEmpty)
    }

    @Test
    func replacementLeaseRejectsTheOldRecommendationResponse() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadRecommendations()
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        provider.install(
            try #require(
                SessionCredential(
                    bduss: "fx-replacement-b",
                    stoken: "fx-replacement-s"
                )
            )
        )
        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try personalizedFixtureData()
            )
        )

        await #expect(throws: RequestAuthorizationError.contextMismatch) {
            try await load.value
        }
    }

    @MainActor
    @Test
    func replacementCancelsOldRequestAndLateCompletionCannotOverwrite() async throws {
        let repository = ControlledRecommendationRepository()
        let store = RecommendationsStore(repository: repository)
        let old = Self.recommendation(threadID: 301)
        let latest = Self.recommendation(threadID: 302)

        let firstLoad = Task {
            await store.reload()
        }
        try await repository.waitForCallCount(1)

        let secondLoad = Task {
            await store.reload()
        }
        try await repository.waitForCallCount(2)

        try await repository.succeed(call: 2, items: [latest])
        await secondLoad.value
        #expect(store.state == .loaded([latest]))

        try await repository.succeed(call: 1, items: [old])
        await firstLoad.value

        #expect(store.state == .loaded([latest]))
        #expect(await repository.cancelledCalls() == [1])
    }

    @MainActor
    @Test
    func cancellationDoesNotBecomeVisibleFailure() async throws {
        let repository = ControlledRecommendationRepository()
        let store = RecommendationsStore(repository: repository)
        let load = Task {
            await store.reload()
        }

        try await repository.waitForCallCount(1)
        load.cancel()
        try await repository.fail(
            call: 1,
            error: FixtureReadingRepositoryError.unavailable
        )
        await load.value

        #expect(store.state == .initialLoading)
        #expect(await repository.cancelledCalls() == [1])
    }

    private func personalizedFixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("recommendations.personalized.cross-language"),
            expectedFormat: .protobuf
        )
    }

    private static func recommendation(
        threadID: Int64
    ) -> RecommendationSummary {
        RecommendationSummary(
            threadID: threadID,
            title: "Thread \(threadID)",
            forumName: "Forum",
            authorName: "Author",
            replyCount: 1,
            thumbnail: nil
        )
    }

    private func activeProvider() throws -> SessionAuthContextProvider {
        let provider = SessionAuthContextProvider()
        provider.install(
            try #require(
                SessionCredential(
                    bduss: "fx-live-b",
                    stoken: "fx-live-s"
                )
            )
        )
        return provider
    }
}

private actor ControlledRecommendationRepository: RecommendationRepository {
    private struct PendingCall {
        let gate: HarnessContinuationGate<[RecommendationSummary]>
    }

    private struct CountObserver {
        let count: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var observers: [CountObserver] = []
    private var observedCancellation: [Int] = []

    func loadRecommendations() async throws -> [RecommendationSummary] {
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<[RecommendationSummary]>()
        pending[call] = PendingCall(gate: gate)
        resumeObservers()

        do {
            let items = try await gate.wait()
            if Task.isCancelled {
                observedCancellation.append(call)
            }
            return items
        } catch {
            if Task.isCancelled {
                observedCancellation.append(call)
            }
            throw error
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        if calls >= expected {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        observers.append(CountObserver(count: expected, gate: gate))
        try await gate.wait()
    }

    func succeed(
        call: Int,
        items: [RecommendationSummary]
    ) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.succeed(items) else {
            throw ControlledRecommendationRepositoryError.unknownCall
        }
    }

    func fail(
        call: Int,
        error: any Error
    ) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.fail(error) else {
            throw ControlledRecommendationRepositoryError.unknownCall
        }
    }

    func cancelledCalls() -> [Int] {
        observedCancellation.sorted()
    }

    private func resumeObservers() {
        var remaining: [CountObserver] = []
        for observer in observers {
            if calls >= observer.count {
                observer.gate.succeed(())
            } else {
                remaining.append(observer)
            }
        }
        observers = remaining
    }
}

private enum ControlledRecommendationRepositoryError: Error {
    case unknownCall
}
