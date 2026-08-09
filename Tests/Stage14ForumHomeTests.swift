import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct Stage14ForumHomeTests {
    @Test
    func fixtureRepositoryReturnsForumHeaderPinnedAndRegularThreads() async throws {
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let snapshot = try await FixtureForumHomeRepository()
            .loadForumHome(route: route)

        #expect(snapshot.forum.forumID == 13_001)
        #expect(snapshot.forum.name == "Swift开发")
        #expect(snapshot.forum.slogan?.isEmpty == false)
        #expect(snapshot.threads.filter(\.isPinned).count == 2)
        #expect(snapshot.threads.filter { !$0.isPinned }.count == 6)
        #expect(Set(snapshot.threads.map(\.itemID)).count == 8)
        #expect(snapshot.threads.allSatisfy { $0.threadID > 0 })
    }

    @Test
    func fixtureForumAndThreadReaderKeepSecondForumIdentity() async throws {
        let firstRoute = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let secondRoute = try #require(
            ForumRoute(forumID: 13_002, forumName: "iOS技术")
        )
        let homeRepository = FixtureForumHomeRepository()
        let threadRepository = FixtureThreadReaderRepository()
        let first = try await homeRepository.loadForumHome(route: firstRoute)
        let second = try await homeRepository.loadForumHome(route: secondRoute)
        let nameOnly = try await homeRepository.loadForumHome(
            route: try #require(ForumRoute("iOS技术"))
        )
        let selected = try #require(
            second.threads.filter { !$0.isPinned }.dropFirst(2).first
        )

        #expect(Set(first.threads.map(\.threadID)).isDisjoint(
            with: Set(second.threads.map(\.threadID))
        ))
        #expect(second.threads.allSatisfy { $0.forumName == "iOS技术" })
        #expect(nameOnly.forum.forumID == nil)

        let thread = try await threadRepository.loadThread(
            threadID: selected.threadID
        )
        #expect(thread.threadID == selected.threadID)
        #expect(thread.title == selected.title)
        #expect(thread.forumName == "iOS技术")
    }

    @Test
    func forumRouteCarriesKnownIDAndValidatedNameWithoutGuessingDeepLinkID() throws {
        let followedRoute = try #require(
            ForumRoute(forumID: 13_001, forumName: "  Swift开发  ")
        )
        let deepLinkRoute = try #require(ForumRoute("Swift开发"))

        #expect(followedRoute.forumID?.rawValue == 13_001)
        #expect(followedRoute.forumName.rawValue == "Swift开发")
        #expect(deepLinkRoute.forumID == nil)
        #expect(deepLinkRoute.forumName.rawValue == "Swift开发")

        let followedForum = makeFollowedForum()
        #expect(AppRouter.forumRoute(for: followedForum) == .forum(followedRoute))
    }

    @Test
    func frsRequestUsesLockedEndpointHeaderAndFirstPageProtoFields() async throws {
        let route = try #require(
            ForumRoute(forumID: nil, forumName: "Swift 开发")
        )
        let endpoint = try FRSPageProtocol.makeDescriptor(
            host: "fixture.invalid",
            route: route
        )
        let body = try FRSPageProtocol.makeRequestBody(route: route)
        guard case let .multipartBinary(boundary, fields, part) = body else {
            Issue.record("FRS request changed body family")
            return
        }

        let wire = try Tieba_FrsPage_FrsPageRequest(
            serializedBytes: part.data
        )
        #expect(boundary == FRSPageProtocol.boundary)
        #expect(fields.isEmpty)
        #expect(part.name == "data")
        #expect(part.filename == "file")
        #expect(wire.hasData)
        #expect(wire.data.kw == "Swift+%E5%BC%80%E5%8F%91")
        #expect(wire.data.pn == 1)
        #expect(wire.data.loadType == 1)
        #expect(wire.data.sortType == 0)
        #expect(wire.data.qType == 2)
        #expect(wire.data.rn == 90)
        #expect(wire.data.rnNeed == 30)
        #expect(wire.data.stType == "recom_flist")
        #expect(wire.data.withGroup == 1)
        #expect(wire.data.hasAdParam)
        #expect(wire.data.adParam.loadCount == 0)
        #expect(wire.data.adParam.refreshCount == 4)
        #expect(wire.data.adParam.yogaLibVersion == "1.0")
        #expect(wire.data.hasCommon)
        #expect(wire.data.common.clientType == 2)
        #expect(
            wire.data.common.clientVersion ==
                PersonalizedProtocol.androidClientVersion
        )
        #expect(wire.data.common.from == "1020031h")
        #expect(
            wire.data.common.userAgent ==
                PersonalizedProtocol.androidUserAgent
        )
        #expect(!wire.data.common.hasBduss)
        #expect(!wire.data.common.hasStoken)
        #expect(!wire.data.common.hasZID)
        #expect(wire.data.common.cuid.isEmpty)
        #expect(wire.data.common.androidID.isEmpty)
        #expect(!wire.data.hasAppPos)
        #expect(wire.data.scrDip == 0)
        #expect(wire.data.scrH == 0)
        #expect(wire.data.scrW == 0)

        let request = try await EndpointRequestBuilder(
            authorizer: FixtureOnlyRequestAuthorizer()
        ).makeRequest(
            endpoint: endpoint,
            authentication: .anonymous,
            body: body
        )
        #expect(
            request.url.absoluteString ==
                "https://fixture.invalid/c/f/frs/page?cmd=301001"
        )
        #expect(request.headers["forum_name"] == "Swift+%E5%BC%80%E5%8F%91")
        #expect(request.headers["x_bd_data_type"] == "protobuf")
        #expect(request.headers["Cookie"] == nil)
        #expect(request.headers["Authorization"] == nil)
    }

    @Test
    func syntheticFRSMapsHeaderPinnedNormalAndAuthorFallback() throws {
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let response = try FRSPageProtocol.decode(frsFixtureData())
        let snapshot = try FRSPageProtocol.map(
            response,
            requestedRoute: route
        )

        #expect(snapshot.forum.forumID == 13_001)
        #expect(snapshot.forum.memberCount == 123_456)
        #expect(snapshot.forum.threadCount == 7_890)
        #expect(snapshot.forum.postCount == 456_789)
        let pinnedIDs = snapshot.threads.filter(\.isPinned).map(\.itemID)
        let regularIDs = snapshot.threads.filter { !$0.isPinned }.map(\.itemID)
        #expect(pinnedIDs == [14_001, 14_002])
        #expect(regularIDs == [14_003, 14_004])
        #expect(snapshot.threads.map(\.threadID) == [140_001, 140_002, 140_003, 140_004])
        #expect(snapshot.threads[0].authorName == "线协议读者")
        #expect(snapshot.threads[3].authorName == "未知作者")
    }

    @Test
    func liveRepositoryBuildsAnonymousRequestAndMapsOnlyDomainValues() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveForumHomeRepository(
            client: client,
            host: "fixture.invalid"
        )
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let load = Task {
            try await repository.loadForumHome(route: route)
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(
            call.request.url.absoluteString ==
                "https://fixture.invalid/c/f/frs/page?cmd=301001"
        )
        #expect(
            call.request.headers["forum_name"] ==
                "Swift%E5%BC%80%E5%8F%91"
        )
        #expect(call.request.headers["Cookie"] == nil)

        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": FRSPageProtocol.liveResponseMIMEType
                ],
                body: try frsFixtureData()
            )
        )

        let snapshot = try await load.value
        #expect(snapshot.forum.forumID == 13_001)
        #expect(snapshot.threads.count == 4)
    }

    @Test
    func replacementForumRejectsCancelledLateResponse() async throws {
        let repository = ControlledForumHomeRepository()
        let firstRoute = try #require(
            ForumRoute(forumID: 14_001, forumName: "旧吧")
        )
        let secondRoute = try #require(
            ForumRoute(forumID: 14_002, forumName: "新吧")
        )
        let store = ForumHomeStore(route: firstRoute, repository: repository)

        let first = Task {
            await store.synchronize(with: firstRoute)
        }
        try await repository.waitForCallCount(1)

        let second = Task {
            await store.synchronize(with: secondRoute)
        }
        try await repository.waitForCallCount(2)

        let latest = makeSnapshot(route: secondRoute, itemID: 22)
        try await repository.succeed(call: 2, snapshot: latest)
        await second.value
        #expect(store.state == .loaded(latest))

        try await repository.succeed(
            call: 1,
            snapshot: makeSnapshot(route: firstRoute, itemID: 11)
        )
        await first.value
        #expect(store.state == .loaded(latest))
        #expect(await repository.cancelledCalls() == [1])
    }

    @Test
    func cancellationNeverBecomesAVisibleFailure() async throws {
        let repository = ControlledForumHomeRepository()
        let route = try #require(
            ForumRoute(forumID: 14_003, forumName: "取消吧")
        )
        let store = ForumHomeStore(route: route, repository: repository)
        let load = Task {
            await store.synchronize(with: route)
        }

        try await repository.waitForCallCount(1)
        store.cancel()
        try await repository.fail(
            call: 1,
            error: ForumHomeLoadFailure.unavailable
        )
        await load.value

        #expect(store.state == .initialLoading)
        #expect(await repository.cancelledCalls() == [1])
    }

    @Test
    func repeatedSynchronizationForTheSameForumDoesNotDuplicateRequests() async throws {
        let repository = ControlledForumHomeRepository()
        let route = try #require(
            ForumRoute(forumID: 14_004, forumName: "稳定吧")
        )
        let store = ForumHomeStore(route: route, repository: repository)
        let load = Task {
            await store.synchronize(with: route)
        }

        try await repository.waitForCallCount(1)
        let snapshot = makeSnapshot(route: route, itemID: 33)
        try await repository.succeed(call: 1, snapshot: snapshot)
        await load.value
        await store.synchronize(with: route)

        #expect(store.state == .loaded(snapshot))
        #expect(await repository.callCount() == 1)
    }

    @Test
    func forumThreadNavigationUsesThreadIDInsteadOfRowIdentity() throws {
        let item = ForumThreadSummary(
            itemID: 91_001,
            threadID: 92_002,
            title: "身份边界",
            forumName: "Swift开发",
            authorName: "Fixture 作者",
            replyCount: 3,
            viewCount: 9,
            isPinned: false
        )
        let threadID = try #require(ThreadID(92_002))

        #expect(AppRouter.threadRoute(for: item) == .thread(threadID))
        #expect(item.id == 92_002)
    }

    @Test
    func uiTestingCompositionUsesForumFixtureWithoutLiveHTTP() async throws {
        let descriptor = LaunchScenarioFactory.make(
            scenario: .sessionSignedInFixture
        )
        let root = descriptor.compositionRoot
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let store = root.makeForumHomeStore(route: route)
        let client = try #require(
            root.environment.httpClient as? HarnessMockHTTPClient
        )

        await store.synchronize(with: route)

        guard case let .loaded(snapshot) = store.state else {
            Issue.record("Fixture forum home did not load")
            return
        }
        #expect(snapshot.threads.count == 8)
        #expect(await client.events().isEmpty)
    }

    private func frsFixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("forum-home.frs-page.synthetic"),
            expectedFormat: .protobuf
        )
    }

    private func makeFollowedForum() -> FollowedForum {
        FollowedForum(
            forumID: 13_001,
            name: "Swift开发",
            avatarResourceID: nil,
            hotCount: 0,
            memberCount: 0,
            threadCount: 0,
            levelID: nil,
            levelName: nil,
            isSignedToday: false
        )
    }

    private func makeSnapshot(
        route: ForumRoute,
        itemID: Int64,
        currentPage: Int = 1,
        hasMore: Bool = false
    ) -> ForumHomeSnapshot {
        let forumID = route.forumID?.rawValue
        return ForumHomeSnapshot(
            forum: ForumSummary(
                forumID: forumID,
                name: route.forumName.rawValue,
                slogan: nil,
                avatarResourceID: nil,
                memberCount: 1,
                threadCount: 1,
                postCount: 1
            ),
            threads: [
                ForumThreadSummary(
                    itemID: itemID,
                    threadID: itemID + 1_000,
                    title: "Fixture 帖子",
                    forumName: route.forumName.rawValue,
                    authorName: "Fixture 作者",
                    replyCount: 1,
                    viewCount: 2,
                    isPinned: false
                )
            ],
            currentPage: currentPage,
            hasMore: hasMore
        )
    }
}

@MainActor
struct Stage14PForumHomeRouteReplacementTests {
    @Test
    func replacementForumRejectsLateNextPageResponse() async throws {
        let repository = ControlledForumHomeRepository()
        let firstRoute = try #require(
            ForumRoute(forumID: 14_101, forumName: "旧分页吧")
        )
        let secondRoute = try #require(
            ForumRoute(forumID: 14_102, forumName: "新分页吧")
        )
        let store = ForumHomeStore(route: firstRoute, repository: repository)

        let initialLoad = Task {
            await store.synchronize(with: firstRoute)
        }
        try await repository.waitForCallCount(1)
        let firstPage = makeSnapshot(
            route: firstRoute,
            itemID: 101,
            currentPage: 1,
            hasMore: true
        )
        try await repository.succeed(call: 1, snapshot: firstPage)
        await initialLoad.value

        let oldNextPage = Task {
            await store.loadNextPage()
        }
        try await repository.waitForCallCount(2)

        let replacementLoad = Task {
            await store.synchronize(with: secondRoute)
        }
        try await repository.waitForCallCount(3)
        let latest = makeSnapshot(route: secondRoute, itemID: 303)
        try await repository.succeed(call: 3, snapshot: latest)
        await replacementLoad.value
        #expect(store.state == .loaded(latest))

        try await repository.succeed(
            call: 2,
            snapshot: makeSnapshot(
                route: firstRoute,
                itemID: 202,
                currentPage: 2,
                hasMore: false
            )
        )
        await oldNextPage.value

        #expect(store.route == secondRoute)
        #expect(store.state == .loaded(latest))
        #expect(store.listPresentation?.threadRows.map(\.itemID) == [303])
        #expect(await repository.cancelledCalls() == [2])
    }

    private func makeSnapshot(
        route: ForumRoute,
        itemID: Int64,
        currentPage: Int = 1,
        hasMore: Bool = false
    ) -> ForumHomeSnapshot {
        ForumHomeSnapshot(
            forum: ForumSummary(
                forumID: route.forumID?.rawValue,
                name: route.forumName.rawValue,
                slogan: nil,
                avatarResourceID: nil,
                memberCount: 1,
                threadCount: 1,
                postCount: 1
            ),
            threads: [
                ForumThreadSummary(
                    itemID: itemID,
                    threadID: itemID + 1_000,
                    title: "Fixture 帖子",
                    forumName: route.forumName.rawValue,
                    authorName: "Fixture 作者",
                    replyCount: 1,
                    viewCount: 2,
                    isPinned: false
                )
            ],
            currentPage: currentPage,
            hasMore: hasMore
        )
    }
}

struct Stage14ForumHomeDiagnosticsTests {
    @Test
    func frsDiagnosticInspectionDistinguishesServerEnvelopeAndMalformedBytes() throws {
        var wireError = Tieba_Error()
        wireError.errorCode = 403
        var failed = Tieba_FrsPage_FrsPageResponse()
        failed.error = wireError

        #expect(
            FRSPageProtocol.inspectForDiagnostics(
                try failed.serializedData()
            ) ==
                .init(decoded: true, hasServerError: true)
        )
        #expect(
            FRSPageProtocol.inspectForDiagnostics(Data([0xFF])) ==
                .init(decoded: false, hasServerError: false)
        )
    }
}

private enum ControlledForumHomeRepositoryError: Error {
    case unknownCall
}

private actor ControlledForumHomeRepository: ForumHomeRepository {
    private struct PendingCall {
        let gate: HarnessContinuationGate<ForumHomeSnapshot>
    }

    private struct CountObserver {
        let count: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var observers: [CountObserver] = []
    private var observedCancellation: [Int] = []

    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        _ = request
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<ForumHomeSnapshot>()
        pending[call] = PendingCall(gate: gate)
        resumeObservers()

        do {
            let snapshot = try await gate.wait()
            if Task.isCancelled {
                observedCancellation.append(call)
            }
            return snapshot
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

    func succeed(call: Int, snapshot: ForumHomeSnapshot) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.succeed(snapshot) else {
            throw ControlledForumHomeRepositoryError.unknownCall
        }
    }

    func fail(call: Int, error: any Error) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.fail(error) else {
            throw ControlledForumHomeRepositoryError.unknownCall
        }
    }

    func callCount() -> Int {
        calls
    }

    func cancelledCalls() -> [Int] {
        observedCancellation
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
