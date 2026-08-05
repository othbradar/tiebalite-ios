import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct Stage13FollowedForumsTests {
    @Test
    func fixtureRepositoryReturnsStableFollowedForums() async throws {
        let repository = FixtureFollowedForumsRepository()
        let forums = try await repository.loadFollowedForums(
            authentication: activeFixtureContext()
        )

        #expect(forums.map(\.forumID) == [13_001, 13_002, 13_003])
        #expect(forums.map(\.name) == ["Swift开发", "iOS技术", "开源软件"])
        #expect(Set(forums.map(\.forumID)).count == forums.count)
    }

    @Test
    func productionRepositoryRemainsEvidenceBlockedWithoutRuntimeProbe() async {
        let repository = EvidenceBlockedFollowedForumsRepository()

        await #expect(throws: LiveReadingCapabilityError.self) {
            _ = try await repository.loadFollowedForums(
                authentication: activeFixtureContext()
            )
        }
    }

    @Test
    func syntheticProtoMapsStableIdentityNameAndAvailableFields() throws {
        let response = try ForumGuideProtocol.decode(forumGuideFixtureData())
        let forums = try ForumGuideProtocol.map(response)

        #expect(forums.map(\.forumID) == [13_001, 13_002, 13_003])
        #expect(forums.first?.name == "Swift开发")
        #expect(forums.first?.levelID == 8)
        #expect(forums.first?.levelName == "八级")
        #expect(forums.first?.memberCount == 123_456)
        #expect(forums.first?.threadCount == 7_890)
        #expect(forums.first?.hotCount == 321)
        #expect(forums.first?.avatarResourceID == "fixture://forum/swift")
    }

    @Test
    func authenticatedRequestUsesLockedEndpointProtoAndCredentialSubset() async throws {
        let authorization = SessionAuthorization(
            bduss: "fx-auth-b",
            stoken: "fx-auth-s"
        )
        let body = try ForumGuideProtocol.makeAuthenticatedRequestBody(
            authorization: authorization
        )
        guard case let .multipartBinary(boundary, fields, part) = body else {
            Issue.record("ForumGuide request changed body family")
            return
        }

        let wire = try Tieba_ForumGuide_ForumGuideRequest(
            serializedBytes: part.data
        )
        #expect(boundary == ForumGuideProtocol.boundary)
        #expect(part.name == "data")
        #expect(part.filename == "file")
        #expect(wire.hasData)
        #expect(wire.data.sortType == 2)
        #expect(wire.data.callFrom == 0)
        #expect(fields == [
            EndpointField(name: "BDUSS", value: "fx-auth-b"),
            EndpointField(name: "stoken", value: "fx-auth-s")
        ])

        let provider = SessionAuthContextProvider()
        provider.install(
            try #require(
                SessionCredential(bduss: "fx-auth-b", stoken: "fx-auth-s")
            )
        )
        let request = try await EndpointRequestBuilder(
            authorizer: ActiveSessionRequestAuthorizer(
                authContextProvider: provider
            )
        ).makeRequest(
            endpoint: try ForumGuideProtocol.makeDescriptor(
                host: "fixture.invalid"
            ),
            authentication: provider.context(),
            body: body
        )

        #expect(
            request.url.absoluteString ==
                "https://fixture.invalid/c/f/forum/forumGuide" +
                "?cmd=309683&format=protobuf"
        )
        #expect(request.headers["x_bd_data_type"] == "protobuf")
        #expect(request.headers["Cookie"] == nil)
        #expect(request.headers["Authorization"] == nil)
    }

    @Test
    func liveRepositoryExecutesActiveRequestAndMapsOnlyDomainValues() async throws {
        let client = HarnessMockHTTPClient()
        let provider = SessionAuthContextProvider()
        provider.install(
            try #require(
                SessionCredential(bduss: "fx-live-b", stoken: "fx-live-s")
            )
        )
        let repository = LiveFollowedForumsRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadFollowedForums(
                authentication: provider.context()
            )
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type":
                        ForumGuideProtocol.candidateLiveResponseMIMEType
                ],
                body: try forumGuideFixtureData()
            )
        )

        let forums = try await load.value
        #expect(forums.map(\.forumID) == [13_001, 13_002, 13_003])
        #expect(await client.events() == [
            .started(call.id),
            .succeeded(call.id)
        ])
    }

    @Test
    func debugProbeReportsOnlySanitizedResponseMetadata() throws {
        let body = try forumGuideFixtureData()
        let result = DebugFollowedForumsProbe.map(
            response: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type":
                        ForumGuideProtocol.candidateLiveResponseMIMEType
                ],
                body: body
            ),
            endpoint: try ForumGuideProtocol.makeDescriptor(
                host: "fixture.invalid"
            )
        )

        #expect(result.statusCode == 200)
        #expect(
            result.mimeType ==
                ForumGuideProtocol.candidateLiveResponseMIMEType
        )
        #expect(result.responseBytes == body.count)
        #expect(result.decoded)
        #expect(result.itemCount == 3)
        #expect(result.outcome == .success)
    }

    @Test
    func forumRouteUsesValidatedNameInsteadOfListIdentity() throws {
        let forum = followedForum(id: 91_001, name: "  Swift开发  ")
        let route = try #require(
            ForumRoute(forumID: 91_001, forumName: "Swift开发")
        )

        #expect(AppRouter.forumRoute(for: forum) == .forum(route))
    }

    @MainActor
    @Test
    func signedOutDoesNotSendARepositoryRequest() async {
        let repository = ControlledFollowedForumsRepository()
        let store = FollowedForumsStore(repository: repository)

        await store.synchronize(with: .signedOut)

        #expect(store.state == .signedOut)
        #expect(await repository.callCount() == 0)
    }

    @MainActor
    @Test
    func replacementRejectsTheCancelledOldResponse() async throws {
        let repository = ControlledFollowedForumsRepository()
        let store = FollowedForumsStore(repository: repository)
        let context = activeFixtureContext()
        let old = followedForum(id: 14_001, name: "旧数据")
        let latest = followedForum(id: 14_002, name: "新数据")

        let first = Task {
            await store.synchronize(with: .active(context))
        }
        try await repository.waitForCallCount(1)

        let second = Task {
            await store.reload()
        }
        try await repository.waitForCallCount(2)

        try await repository.succeed(call: 2, forums: [latest])
        await second.value
        #expect(store.state == .loaded([latest]))

        try await repository.succeed(call: 1, forums: [old])
        await first.value
        #expect(store.state == .loaded([latest]))
        #expect(await repository.cancelledCalls() == [1])
    }

    @MainActor
    @Test
    func cancellationDoesNotBecomeAVisibleFailure() async throws {
        let repository = ControlledFollowedForumsRepository()
        let store = FollowedForumsStore(repository: repository)
        let context = activeFixtureContext()
        let load = Task {
            await store.synchronize(with: .active(context))
        }

        try await repository.waitForCallCount(1)
        store.cancel()
        try await repository.fail(
            call: 1,
            error: FollowedForumsLoadFailure.unavailable
        )
        await load.value

        #expect(store.state == .initialLoading)
        #expect(await repository.cancelledCalls() == [1])
    }

    @MainActor
    @Test
    func explicitCredentialExpiryEntersExpiredWithoutGuessingNetworkErrors() async throws {
        let repository = ControlledFollowedForumsRepository()
        let recorder = ExpirationRecorder()
        let store = FollowedForumsStore(
            repository: repository,
            expireSession: { context in
                await recorder.record(context)
            }
        )
        let context = activeFixtureContext()
        let load = Task {
            await store.synchronize(with: .active(context))
        }

        try await repository.waitForCallCount(1)
        try await repository.fail(
            call: 1,
            error: FollowedForumsRepositoryError.sessionExpired
        )
        await load.value

        #expect(store.state == .expired)
        #expect(await recorder.contexts() == [context])
    }

    @Test
    func ordinaryFailureCanRetryWithoutExpiringTheSession() async throws {
        let repository = ControlledFollowedForumsRepository()
        let recorder = ExpirationRecorder()
        let store = FollowedForumsStore(
            repository: repository,
            expireSession: { context in
                await recorder.record(context)
            }
        )
        let context = activeFixtureContext()
        let firstLoad = Task {
            await store.synchronize(with: .active(context))
        }

        try await repository.waitForCallCount(1)
        try await repository.fail(
            call: 1,
            error: FollowedForumsLoadFailure.unavailable
        )
        await firstLoad.value
        #expect(store.state == .initialFailure(.unavailable))
        #expect(await recorder.contexts().isEmpty)

        let forum = followedForum(id: 15_001, name: "重试成功")
        let retry = Task {
            await store.reload()
        }
        try await repository.waitForCallCount(2)
        try await repository.succeed(call: 2, forums: [forum])
        await retry.value

        #expect(store.state == .loaded([forum]))
        #expect(await recorder.contexts().isEmpty)
    }

    @MainActor
    @Test
    func uiTestingFixtureUsesFakeSessionRepositoryAndNoHTTP() async throws {
        let descriptor = LaunchScenarioFactory.make(
            scenario: .sessionSignedInFixture
        )
        let root = descriptor.compositionRoot
        let store = root.makeFollowedForumsStore()
        let context = root.authContextProvider.context()
        let client = try #require(
            root.environment.httpClient as? HarnessMockHTTPClient
        )

        await store.synchronize(with: .active(context))

        guard case let .loaded(forums) = store.state else {
            Issue.record("Signed-in UI fixture did not load followed forums")
            return
        }
        #expect(forums.map(\.forumID) == [13_001, 13_002, 13_003])
        #expect(await client.events().isEmpty)
    }

    private func forumGuideFixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("followed-forums.forum-guide.synthetic"),
            expectedFormat: .protobuf
        )
    }

    private func activeFixtureContext() -> AuthContext {
        .active(
            ProtectedDataLease(
                sessionID: SessionID(rawValue: 13),
                generation: 1
            )
        )
    }

    private func followedForum(id: Int64, name: String) -> FollowedForum {
        FollowedForum(
            forumID: id,
            name: name,
            avatarResourceID: nil,
            hotCount: 0,
            memberCount: 0,
            threadCount: 0,
            levelID: nil,
            levelName: nil,
            isSignedToday: false
        )
    }
}

private actor ExpirationRecorder {
    private var recordedContexts: [AuthContext] = []

    func record(_ context: AuthContext) {
        recordedContexts.append(context)
    }

    func contexts() -> [AuthContext] {
        recordedContexts
    }
}

private enum ControlledFollowedForumsRepositoryError: Error {
    case unknownCall
}

private actor ControlledFollowedForumsRepository: FollowedForumsRepository {
    private struct PendingCall {
        let gate: HarnessContinuationGate<[FollowedForum]>
    }

    private struct CountObserver {
        let count: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var observers: [CountObserver] = []
    private var observedCancellation: [Int] = []

    func loadFollowedForums(
        authentication: AuthContext
    ) async throws -> [FollowedForum] {
        guard case .active = authentication else {
            throw FollowedForumsLoadFailure.unavailable
        }
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<[FollowedForum]>()
        pending[call] = PendingCall(gate: gate)
        resumeObservers()

        do {
            let forums = try await gate.wait()
            if Task.isCancelled {
                observedCancellation.append(call)
            }
            return forums
        } catch {
            if Task.isCancelled {
                observedCancellation.append(call)
            }
            throw error
        }
    }

    func callCount() -> Int {
        calls
    }

    func waitForCallCount(_ expected: Int) async throws {
        if calls >= expected {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        observers.append(CountObserver(count: expected, gate: gate))
        try await gate.wait()
    }

    func succeed(call: Int, forums: [FollowedForum]) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.succeed(forums) else {
            throw ControlledFollowedForumsRepositoryError.unknownCall
        }
    }

    func fail(call: Int, error: any Error) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.fail(error) else {
            throw ControlledFollowedForumsRepositoryError.unknownCall
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
