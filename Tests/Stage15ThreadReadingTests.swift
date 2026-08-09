import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct Stage15ThreadReadingTests {
    @Test
    func nextPageRequestCarriesEvidenceLockedPageAndPostCursor() throws {
        let input = try PBPageRequestInput(
            threadID: 8_001,
            pageNumber: 2,
            postID: 9_015
        )
        let wire = try Tieba_PbPage_PbPageRequest(
            serializedBytes: PBPageProtocol.encodeRequest(input)
        )

        #expect(wire.data.kz == 8_001)
        #expect(wire.data.pn == 2)
        #expect(wire.data.pid == 9_015)
        #expect(throws: PBPageProtocolError.invalidPageNumber) {
            try PBPageRequestInput(threadID: 8_001, pageNumber: -1)
        }
        #expect(throws: PBPageProtocolError.invalidPostID) {
            try PBPageRequestInput(threadID: 8_001, postID: -1)
        }
    }

    @Test
    func firstPageMapsFloorsInlineSubpostsTimeCursorAndSafeDegradation() throws {
        let snapshot = try PBPageProtocol.map(
            Stage15ProtoFixture.firstPage(),
            request: .initial(threadID: Stage15ProtoFixture.threadID)
        )

        #expect(snapshot.currentPage == 1)
        #expect(snapshot.totalPage == 3)
        #expect(snapshot.hasMore)
        #expect(snapshot.nextPostID == 9_015)
        #expect(snapshot.posts.map(\.document.source.postID) == [
            9_001, 9_002, 9_003
        ])

        let reply = try #require(snapshot.posts.first { $0.floorNumber == 2 })
        #expect(reply.createdAtUnixSeconds == 1_725_000_000)
        #expect(reply.subpostTotal == 3)
        #expect(reply.subposts.map(\.document.source.postID) == [9_201, 9_202])
        #expect(reply.subposts.allSatisfy {
            $0.document.source.scope == .subPost && $0.parentPostID == 9_002
        })
        #expect(reply.subposts[1].replyToDisplayName == nil)
        #expect(reply.document.nodes.contains { node in
            if case let .unsupported(content) = node.payload {
                return content.rawType == 9_999
            }
            return false
        })
        #expect(reply.document.nodes.last?.payload == .text(
            ThreadTextContent(value: "未知节点后的正文")
        ))

        let image = try #require(reply.document.nodes.compactMap { node in
            guard case let .image(content) = node.payload else {
                return nil as ThreadImageContent?
            }
            return content
        }.first)
        #expect(reply.document.mediaIntent(selecting: image.mediaID) != nil)

        let folded = try #require(snapshot.posts.first { $0.floorNumber == 3 })
        #expect(folded.document.availability == .unavailable(
            .folded(message: "本楼暂不可见")
        ))
    }

    @Test
    func subsequentPageKeepsServerOrderAndWirePaginationState() throws {
        let request = ThreadReaderPageRequest(
            threadID: Stage15ProtoFixture.threadID,
            pageNumber: 2,
            postID: 9_015,
            loadedPostIDs: [9_001, 9_002, 9_003]
        )
        let snapshot = try PBPageProtocol.map(
            Stage15ProtoFixture.secondPage(),
            request: request
        )

        #expect(snapshot.posts.map(\.document.source.postID) == [9_003, 9_004])
        #expect(snapshot.currentPage == 2)
        #expect(snapshot.totalPage == 3)
        #expect(snapshot.hasMore)
        #expect(snapshot.nextPostID == 9_025)
    }

    @Test
    func subsequentPageRequiresExactWirePageIdentity() throws {
        let request = ThreadReaderPageRequest(
            threadID: Stage15ProtoFixture.threadID,
            pageNumber: 2,
            postID: 9_015,
            loadedPostIDs: [9_001, 9_002, 9_003]
        )
        var missingIdentity = try Stage15ProtoFixture.secondPage()
        missingIdentity.data.page.currentPage = 0
        #expect(
            throws: PBPageProtocolError.pageIdentityMismatch(
                requested: 2,
                received: 0
            )
        ) {
            try PBPageProtocol.map(missingIdentity, request: request)
        }

        var skippedIdentity = try Stage15ProtoFixture.secondPage()
        skippedIdentity.data.page.currentPage = 3
        #expect(
            throws: PBPageProtocolError.pageIdentityMismatch(
                requested: 2,
                received: 3
            )
        ) {
            try PBPageProtocol.map(skippedIdentity, request: request)
        }
    }

    @Test
    func thirdPageAndLaterRemainRequestableUntilWireTerminal() throws {
        let request = ThreadReaderPageRequest(
            threadID: Stage15ProtoFixture.threadID,
            pageNumber: 3,
            postID: 9_025,
            loadedPostIDs: [9_001, 9_002, 9_003, 9_004]
        )
        let snapshot = try PBPageProtocol.map(
            Stage15ProtoFixture.thirdPage(),
            request: request
        )

        #expect(snapshot.currentPage == 3)
        #expect(snapshot.posts.map(\.document.source.postID) == [9_004, 9_005])
        #expect(!snapshot.hasMore)
        #expect(snapshot.nextPostID == nil)
    }

    @Test
    func wireHasMoreWithoutAnUnseenCursorUsesAndroidZeroFallback() throws {
        var response = try Stage15ProtoFixture.secondPage()
        response.data.thread.pids = "9001,9002,9003,9004"
        let request = ThreadReaderPageRequest(
            threadID: Stage15ProtoFixture.threadID,
            pageNumber: 2,
            postID: 9_015,
            loadedPostIDs: [9_001, 9_002, 9_003, 9_004]
        )

        let snapshot = try PBPageProtocol.map(response, request: request)

        #expect(snapshot.hasMore)
        #expect(snapshot.nextPostID == 0)
    }

    @Test
    func fixtureFivePagesDedupeAndKeepAnchorAtTerminal() async throws {
        let store = ThreadReaderStore(
            threadID: 140_006,
            repository: FixtureThreadReaderRepository()
        )
        await store.loadIfNeeded()
        let first = try #require(store.state.snapshot)
        let retainedPostID = try #require(first.posts.dropFirst().first?.id)

        #expect(first.posts.count == 17)
        #expect(first.posts[1].subposts.count == 2)
        #expect(first.posts[1].subpostTotal == 4)
        #expect(first.posts.contains { post in
            post.document.nodes.contains { node in
                if case .image = node.payload {
                    return true
                }
                return false
            }
        })
        #expect(first.posts.contains {
            $0.document.availability != .available
        })

        for expectedCount in [32, 47, 62, 77] {
            await store.loadNextPage()
            let merged = try #require(store.state.snapshot)
            #expect(merged.posts.count == expectedCount)
            #expect(
                Set(merged.posts.map(\.document.source.postID)).count
                    == expectedCount
            )
            #expect(merged.posts[1].id == retainedPostID)
        }

        let merged = try #require(store.state.snapshot)
        #expect(merged.currentPage == 5)
        #expect(!merged.hasMore)

        await store.loadNextPage()
        #expect(store.state.snapshot == merged)
    }

    @Test
    func nextPageFailureRetainsContentAndRetrySucceeds() async throws {
        let repository = Stage15FailOnceRepository()
        let store = ThreadReaderStore(
            threadID: 140_006,
            repository: repository
        )
        await store.loadIfNeeded()
        let retained = try #require(store.state.snapshot)

        await store.loadNextPage()
        #expect(store.state == .nextPageFailure(retained))

        await store.loadNextPage()
        let recovered = try #require(store.state.snapshot)
        #expect(recovered.posts.count == 32)
        #expect(recovered.hasMore)
        #expect(await repository.nextPageAttemptCount() == 2)
    }

    @Test
    func duplicateNextRequestIsSuppressedAndCancellationIsNotFailure() async throws {
        let repository = Stage15ControlledNextRepository()
        let store = ThreadReaderStore(
            threadID: 140_006,
            repository: repository
        )
        await store.loadIfNeeded()
        let retained = try #require(store.state.snapshot)

        let first = Task { await store.loadNextPage() }
        try await repository.waitForNextPageCall()
        await store.loadNextPage()
        #expect(await repository.nextPageCallCount() == 1)

        store.cancel()
        await first.value
        #expect(store.state == .loaded(retained))
        #expect(await repository.observedCancellation())
    }

    @Test
    func removingThreadRouteCancelsItsPendingNextPage() async throws {
        let repository = Stage15ControlledNextRepository()
        let registry = AppFeatureStoreRegistry(
            followedForumsStore: FollowedForumsStore(
                repository: FixtureFollowedForumsRepository()
            ),
            recommendationsStore: RecommendationsStore(
                repository: FixtureRecommendationRepository()
            ),
            makeThreadReaderStore: { threadID in
                ThreadReaderStore(
                    threadID: threadID,
                    repository: repository
                )
            }
        )
        let threadID = try #require(ThreadID(140_006))
        let store = registry.threadReaderStore(
            for: .followedForums,
            threadID: threadID
        )
        await store.loadIfNeeded()
        let load = Task { await store.loadNextPage() }
        try await repository.waitForNextPageCall()

        registry.retainFeatureStores(in: AppNavigationState())
        await load.value

        #expect(await repository.observedCancellation())
        #expect(store.state.snapshot?.posts.count == 17)
    }

    @Test
    func uiTestingThreadPaginationUsesFixtureLoaderAndNoLiveHTTP() async throws {
        let descriptor = LaunchScenarioFactory.make(
            scenario: .sessionSignedInFixture
        )
        let root = descriptor.compositionRoot
        let client = try #require(
            root.environment.httpClient as? HarnessMockHTTPClient
        )
        let store = root.makeThreadReaderStore(threadID: 140_006)

        await store.loadIfNeeded()
        await store.loadNextPage()

        #expect(store.state.snapshot?.posts.count == 32)
        #expect(root.environment.imageLoader is FixtureReadingImageLoader)
        #expect(await client.events().isEmpty)
    }
}

private actor Stage15FailOnceRepository: ThreadReaderRepository {
    private let base = FixtureThreadReaderRepository()
    private var nextAttempts = 0

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        if request.pageNumber > 0 {
            nextAttempts += 1
            if nextAttempts == 1 {
                throw FixtureReadingRepositoryError.unavailable
            }
        }
        return try await base.loadPage(request)
    }

    func nextPageAttemptCount() -> Int {
        nextAttempts
    }
}

private actor Stage15ControlledNextRepository: ThreadReaderRepository {
    private let base = FixtureThreadReaderRepository()
    private let gate = HarnessContinuationGate<ThreadReaderSnapshot>()
    private var nextCalls = 0
    private var cancelled = false
    private var observer: HarnessContinuationGate<Void>?

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        guard request.pageNumber > 0 else {
            return try await base.loadPage(request)
        }
        nextCalls += 1
        observer?.succeed(())
        observer = nil
        do {
            return try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            if Task.isCancelled {
                cancelled = true
            }
            throw error
        }
    }

    func waitForNextPageCall() async throws {
        if nextCalls > 0 {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        observer = gate
        try await gate.wait()
    }

    func nextPageCallCount() -> Int {
        nextCalls
    }

    func observedCancellation() -> Bool {
        cancelled
    }
}

private enum Stage15ProtoFixture {
    static let threadID: Int64 = 8_001

    static func firstPage() throws -> Tieba_PbPage_PbPageResponse {
        var thread = makeThread()
        thread.pids = "9002,invalid,9003,9015"
        var data = makeData(thread: thread, currentPage: 1, hasMore: true)
        data.firstFloorPost = makePost(id: 9_001, floor: 1, text: "首楼")

        var reply = makePost(id: 9_002, floor: 2, text: "普通楼层")
        reply.time = 1_725_000_000
        reply.content.append(imageContent())
        var unknown = Tieba_PbContent()
        unknown.type = 9_999
        unknown.text = "未知"
        reply.content.append(unknown)
        reply.content.append(textContent("未知节点后的正文"))
        reply.subPostNumber = 3
        var subposts = Tieba_SubPost()
        subposts.pid = reply.id
        subposts.subPostList = [
            makeSubpost(id: 9_201, authorID: 7_002, text: "第一条"),
            makeSubpost(
                id: 9_202,
                authorID: 7_003,
                text: "第二条",
                replyTo: "楼中楼甲"
            )
        ]
        reply.subPostList = subposts

        var folded = makePost(id: 9_003, floor: 3, text: "不会崩溃")
        folded.isFold = 1
        folded.foldTip = "本楼暂不可见"
        var invalid = makePost(id: 0, floor: 4, text: "非法楼层")
        invalid.id = 0
        data.postList = [reply, invalid, folded]
        return response(data)
    }

    static func secondPage() throws -> Tieba_PbPage_PbPageResponse {
        var thread = makeThread()
        thread.pids = "9025,9002"
        var data = makeData(thread: thread, currentPage: 2, hasMore: true)
        data.postList = [
            makePost(id: 9_000, floor: 1, text: "后续页重复首楼"),
            makePost(id: 9_003, floor: 3, text: "重复楼层"),
            makePost(id: 9_004, floor: 4, text: "第二页楼层")
        ]
        return response(data)
    }

    static func thirdPage() throws -> Tieba_PbPage_PbPageResponse {
        let thread = makeThread()
        var data = makeData(thread: thread, currentPage: 3, hasMore: false)
        data.postList = [
            makePost(id: 9_004, floor: 4, text: "重复楼层"),
            makePost(id: 9_005, floor: 5, text: "第三页楼层")
        ]
        return response(data)
    }

    private static func makeData(
        thread: Tieba_ThreadInfo,
        currentPage: Int32,
        hasMore: Bool
    ) -> Tieba_PbPage_PbPageResponseData {
        var forum = Tieba_SimpleForum()
        forum.id = 6_001
        forum.name = "脱敏测试吧"
        var page = Tieba_Page()
        page.currentPage = currentPage
        page.newTotalPage = 3
        page.hasMore_p = hasMore ? 1 : 0
        var data = Tieba_PbPage_PbPageResponseData()
        data.thread = thread
        data.forum = forum
        data.page = page
        data.userList = [
            user(id: 7_001, name: "楼主"),
            user(id: 7_002, name: "楼中楼甲"),
            user(id: 7_003, name: "楼中楼乙")
        ]
        return data
    }

    private static func makeThread() -> Tieba_ThreadInfo {
        var thread = Tieba_ThreadInfo()
        thread.id = threadID
        thread.threadID = threadID
        thread.title = "脱敏分页测试帖"
        thread.replyNum = 4
        thread.author = user(id: 7_001, name: "楼主")
        return thread
    }

    private static func makePost(
        id: UInt64,
        floor: UInt32,
        text: String
    ) -> Tieba_Post {
        var post = Tieba_Post()
        post.id = id
        post.floor = floor
        post.authorID = 7_001
        post.author = user(id: 7_001, name: "作者")
        post.content = [textContent(text)]
        return post
    }

    private static func makeSubpost(
        id: UInt64,
        authorID: Int64,
        text: String,
        replyTo: String? = nil
    ) -> Tieba_SubPostList {
        var subpost = Tieba_SubPostList()
        subpost.id = id
        subpost.authorID = authorID
        subpost.author = user(id: authorID, name: "楼中楼作者")
        subpost.time = 1_725_000_100
        if let replyTo {
            var mention = Tieba_PbContent()
            mention.type = 4
            mention.uid = 7_002
            mention.text = replyTo
            subpost.content = [mention, textContent(text)]
        } else {
            subpost.content = [textContent(text)]
        }
        return subpost
    }

    private static func textContent(_ text: String) -> Tieba_PbContent {
        var content = Tieba_PbContent()
        content.type = 0
        content.text = text
        return content
    }

    private static func imageContent() -> Tieba_PbContent {
        var content = Tieba_PbContent()
        content.type = 3
        content.src = "https://fixture.invalid/stage15/image.jpg"
        content.width = 1_200
        content.height = 800
        return content
    }

    private static func user(id: Int64, name: String) -> Tieba_User {
        var user = Tieba_User()
        user.id = id
        user.nameShow = name
        return user
    }

    private static func response(
        _ data: Tieba_PbPage_PbPageResponseData
    ) -> Tieba_PbPage_PbPageResponse {
        var response = Tieba_PbPage_PbPageResponse()
        response.data = data
        return response
    }
}
