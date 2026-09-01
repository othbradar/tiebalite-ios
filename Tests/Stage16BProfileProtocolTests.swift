import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct Stage16BProfileProtocolTests {
    @Test
    func requestUsesLockedAnonymousProfileContractWithoutCredentials() async throws {
        let route = try #require(UserProfileRoute(
            userID: 160_801,
            fallbackDisplayName: "Fixture 用户"
        ))
        let descriptor = try ProfileProtocol.makeDescriptor(
            host: "fixture.invalid"
        )
        let body = try ProfileProtocol.makeRequestBody(route: route)
        guard case let .multipartBinary(boundary, fields, part) = body else {
            Issue.record("Profile request changed body family")
            return
        }
        let request = try Tieba_Profile_ProfileRequest(
            serializedBytes: part.data
        )

        #expect(descriptor.id.rawValue == "user.profile")
        #expect(descriptor.authentication == .anonymous)
        #expect(descriptor.path == "/c/u/user/profile")
        #expect(descriptor.queryItems == [
            EndpointField(name: "cmd", value: "303012"),
            EndpointField(name: "format", value: "protobuf")
        ])
        #expect(boundary == ProfileProtocol.boundary)
        #expect(fields.isEmpty)
        #expect(part.name == "data")
        #expect(part.filename == "file")
        #expect(request.hasData)
        #expect(request.data.friendUid == 160_801)
        #expect(request.data.hasFriendUid)
        #expect(!request.data.hasUid)
        #expect(request.data.isGuest == 1)
        #expect(request.data.friendUidPortrait.isEmpty)
        #expect(request.data.hasPlist_p == 1)
        #expect(request.data.isFromUsercenter == 1)
        #expect(request.data.needPostCount == 1)
        #expect(request.data.page == 1)
        #expect(request.data.pn == 1)
        #expect(request.data.qType == 0)
        #expect(request.data.rn == 20)
        #expect(request.data.scrW == 0)
        #expect(request.data.scrH == 0)
        #expect(request.data.scrDip == 0)
        #expect(request.data.hasCommon)
        #expect(request.data.common.clientType == 2)
        #expect(
            request.data.common.clientVersion ==
                PersonalizedProtocol.androidClientVersion
        )
        #expect(request.data.common.personalizedRecSwitch == 1)
        #expect(!request.data.common.hasBduss)
        #expect(!request.data.common.hasStoken)

        let httpRequest = try await EndpointRequestBuilder(
            authorizer: AnonymousRequestAuthorizer()
        ).makeRequest(
            endpoint: descriptor,
            authentication: .anonymous,
            body: body
        )
        #expect(
            httpRequest.url.absoluteString ==
                "https://fixture.invalid/c/u/user/profile" +
                "?cmd=303012&format=protobuf"
        )
        #expect(!Self.containsCredentialHeader(httpRequest.headers))
    }

    @Test
    func syntheticProfileMapsOnlyPublicEvidenceApprovedFields() throws {
        let route = try #require(UserProfileRoute(
            userID: 160_801,
            fallbackDisplayName: "Fallback"
        ))
        let bytes = try Self.fixtureData()
        let wire = try ProfileProtocol.decode(bytes)
        let profile = try ProfileProtocol.map(
            wire,
            requestedRoute: route
        )

        #expect(profile.userID.rawValue == 160_801)
        #expect(profile.displayName == "Fixture 资料用户")
        #expect(profile.portraitResourceID == "fixture://profile/avatar")
        #expect(profile.introduction == "本地合成的公开用户简介")
        #expect(profile.sex == .female)
        #expect(profile.followingCount == 45)
        #expect(profile.followerCount == 321)
        #expect(profile.postCount == 987)
        #expect(profile.threadCount == 65)
        #expect(profile.totalAgreeCount == 4_321)
        #expect(profile.displayTiebaID == "fixture-tieba-id")

        let inspection = ProfileProtocol.inspectForDiagnostics(bytes)
        #expect(inspection.decoded)
        #expect(!inspection.hasServerError)
        #expect(inspection.displayFieldCount == 11)
    }

    @Test
    func mapperRejectsAValidResponseForTheWrongStableUserIdentity() throws {
        let wire = try ProfileProtocol.decode(Self.fixtureData())
        let wrongRoute = try #require(UserProfileRoute(
            userID: 160_802,
            fallbackDisplayName: "Wrong"
        ))

        #expect(throws: ProfileProtocolError.identityMismatch) {
            try ProfileProtocol.map(wire, requestedRoute: wrongRoute)
        }
    }

    @Test
    func liveRepositoryUsesAnonymousTransportAndMapsFixtureResponse() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveUserProfileRepository(
            client: client,
            host: "fixture.invalid"
        )
        let route = try #require(UserProfileRoute(
            userID: 160_801,
            fallbackDisplayName: "Fallback"
        ))
        let load = Task {
            try await repository.loadProfile(route: route)
        }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)

        #expect(call.request.method == .post)
        #expect(call.request.url.path == "/c/u/user/profile")
        #expect(!Self.containsCredentialHeader(call.request.headers))
        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": ProfileProtocol.fixtureResponseMIMEType
                ],
                body: try Self.fixtureData()
            )
        )
        let profile = try await load.value
        #expect(profile.userID == route.userID)
        #expect(profile.displayName == "Fixture 资料用户")
    }

    private static func fixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("user-profile.profile.synthetic"),
            expectedFormat: .protobuf
        )
    }

    private static func containsCredentialHeader(
        _ headers: [String: String]
    ) -> Bool {
        headers.keys.contains { name in
            let lowered = name.lowercased()
            return lowered == "cookie"
                || lowered == "bduss"
                || lowered == "stoken"
        }
    }
}

@MainActor
struct Stage16BUserProfileStoreTests {
    @Test
    func newerUserCancelsAndRejectsTheLateOlderProfile() async throws {
        let repository = ControlledUserProfileRepository()
        let firstRoute = try #require(UserProfileRoute(
            userID: 160_811,
            fallbackDisplayName: "First"
        ))
        let secondRoute = try #require(UserProfileRoute(
            userID: 160_812,
            fallbackDisplayName: "Second"
        ))
        let store = UserProfileStore(
            route: firstRoute,
            repository: repository
        )

        let firstLoad = Task { await store.load(route: firstRoute) }
        try await repository.waitForCallCount(1)
        let secondLoad = Task { await store.load(route: secondRoute) }
        try await repository.waitForCallCount(2)
        let secondProfile = Self.profile(route: secondRoute)
        try await repository.succeed(call: 2, profile: secondProfile)
        await secondLoad.value
        try await repository.succeed(
            call: 1,
            profile: Self.profile(route: firstRoute)
        )
        await firstLoad.value

        #expect(store.state == .loaded(secondProfile))
        #expect(store.route == secondRoute)
        #expect(await repository.cancelledCalls() == [1])
    }

    @Test
    func cancellationReturnsToIdleInsteadOfShowingFailure() async throws {
        let repository = ControlledUserProfileRepository()
        let route = try #require(UserProfileRoute(
            userID: 160_821,
            fallbackDisplayName: "Cancel"
        ))
        let store = UserProfileStore(route: route, repository: repository)
        let load = Task { await store.load(route: route) }
        try await repository.waitForCallCount(1)

        store.cancel()
        try await repository.succeed(
            call: 1,
            profile: Self.profile(route: route)
        )
        await load.value

        #expect(store.state == .idle(route))
        #expect(await repository.cancelledCalls() == [1])
    }

    @Test
    func repositoryEmptyResultUsesTheDedicatedEmptyState() async throws {
        let repository = ControlledUserProfileRepository()
        let route = try #require(UserProfileRoute(
            userID: 160_831,
            fallbackDisplayName: "Empty"
        ))
        let store = UserProfileStore(route: route, repository: repository)
        let load = Task { await store.load(route: route) }
        try await repository.waitForCallCount(1)

        try await repository.fail(
            call: 1,
            error: UserProfileRepositoryError.empty
        )
        await load.value

        #expect(store.state == .empty(route))
    }

    private static func profile(route: UserProfileRoute) -> UserProfile {
        UserProfile(
            userID: route.userID,
            displayName: route.fallbackDisplayName,
            portraitResourceID: route.portraitResourceID,
            introduction: nil,
            sex: nil,
            followingCount: nil,
            followerCount: nil,
            postCount: nil,
            threadCount: nil,
            totalAgreeCount: nil,
            displayTiebaID: nil
        )
    }
}

private enum ControlledUserProfileRepositoryError: Error {
    case unknownCall
}

private actor ControlledUserProfileRepository: UserProfileRepository {
    private struct Call {
        let route: UserProfileRoute
        let gate: HarnessContinuationGate<UserProfile>
    }

    private struct Observer {
        let count: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var calls: [Call] = []
    private var observers: [Observer] = []
    private var cancelled: [Int] = []

    func loadProfile(route: UserProfileRoute) async throws -> UserProfile {
        let callNumber = calls.count + 1
        let gate = HarnessContinuationGate<UserProfile>()
        calls.append(Call(route: route, gate: gate))
        resumeObservers()
        do {
            let profile = try await gate.wait()
            if Task.isCancelled {
                cancelled.append(callNumber)
            }
            return profile
        } catch {
            if Task.isCancelled {
                cancelled.append(callNumber)
            }
            throw error
        }
    }

    func waitForCallCount(_ count: Int) async throws {
        guard calls.count < count else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        observers.append(Observer(count: count, gate: gate))
        try await gate.wait()
    }

    func succeed(call: Int, profile: UserProfile) throws {
        guard calls.indices.contains(call - 1) else {
            throw ControlledUserProfileRepositoryError.unknownCall
        }
        calls[call - 1].gate.succeed(profile)
    }

    func fail(call: Int, error: any Error) throws {
        guard calls.indices.contains(call - 1) else {
            throw ControlledUserProfileRepositoryError.unknownCall
        }
        calls[call - 1].gate.fail(error)
    }

    func cancelledCalls() -> [Int] {
        cancelled
    }

    private func resumeObservers() {
        let ready = observers.filter { calls.count >= $0.count }
        observers.removeAll { calls.count >= $0.count }
        ready.forEach { $0.gate.succeed(()) }
    }
}
