import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct Stage11PBPageProtocolTests {
    @Test
    func requestUsesEvidenceLockedAnonymousFirstPageContract() async throws {
        let input = try PBPageRequestInput(threadID: 8_001)
        let wire = try Tieba_PbPage_PbPageRequest(
            serializedBytes: PBPageProtocol.encodeRequest(input)
        )

        #expect(wire.hasData)
        #expect(wire.data.kz == 8_001)
        #expect(wire.data.pn == 0)
        #expect(wire.data.hasPid && wire.data.pid == 0)
        #expect(wire.data.rn == 15)
        #expect(wire.data.withFloor == 1)
        #expect(wire.data.floorRn == 4)
        #expect(wire.data.floorSortType == 1)
        #expect(wire.data.qType == 2)
        #expect(wire.data.sourceType == 2)
        #expect(wire.data.hasCommon)
        #expect(wire.data.common.clientType == 2)
        #expect(
            wire.data.common.clientVersion ==
                PersonalizedProtocol.androidClientVersion
        )
        #expect(wire.data.common.personalizedRecSwitch == 1)
        #expect(wire.data.common.from == "1020031h")
        #expect(!wire.data.hasAppPos)
        #expect(wire.data.common.clientID.isEmpty)
        #expect(!wire.data.common.hasBduss)
        #expect(!wire.data.common.hasStoken)

        let descriptor = try PBPageProtocol.makeDescriptor(
            host: "fixture.invalid"
        )
        let request = try await EndpointRequestBuilder(
            authorizer: FixtureOnlyRequestAuthorizer()
        ).makeRequest(
            endpoint: descriptor,
            authentication: .anonymous,
            body: try PBPageProtocol.makeRequestBody(input)
        )

        #expect(
            request.url.absoluteString ==
                "https://fixture.invalid/c/f/pb/page" +
                "?cmd=302001&format=protobuf"
        )
        #expect(request.headers["x_bd_data_type"] == "protobuf")
        #expect(request.headers["Authorization"] == nil)
        #expect(request.headers["Cookie"] == nil)
    }

    @Test
    func responseMapsHeaderFloorsImagesAndStableMediaIntent() throws {
        let responseBytes = try makePBPageResponse(threadID: 8_001)
        let response = try PBPageProtocol.decode(responseBytes)
        let snapshot = try PBPageProtocol.map(
            response,
            requestedThreadID: 8_001
        )

        #expect(snapshot.threadID == 8_001)
        #expect(snapshot.title == "Live fixture title")
        #expect(snapshot.forumName == "Live fixture forum")
        #expect(snapshot.author.displayName == "Thread author")
        #expect(snapshot.replyCount == 2)
        #expect(snapshot.posts.map(\.floorNumber) == [1, 2])
        #expect(snapshot.posts.map(\.document.source.postID) == [9_001, 9_002])

        let firstDocument = try #require(snapshot.posts.first?.document)
        let image = try #require(
            firstDocument.nodes.compactMap { node -> ThreadImageContent? in
                guard case let .image(content) = node.payload else {
                    return nil
                }
                return content
            }.first
        )
        let intent = try #require(
            firstDocument.mediaIntent(selecting: image.mediaID)
        )
        #expect(intent.initialMediaID == image.mediaID)
        #expect(intent.items.map(\.mediaID) == [image.mediaID])
        #expect(
            intent.items.first?.request.candidates.first?.destination
                .absoluteString == "https://fixture.invalid/live-image.jpg"
        )
    }

    @Test
    func malformedServerFailureAndMismatchedThreadRemainTyped() throws {
        #expect(throws: PBPageProtocolError.emptyBody) {
            try PBPageProtocol.decode(Data())
        }

        var failure = Tieba_PbPage_PbPageResponse()
        var wireError = Tieba_Error()
        wireError.errorCode = 403
        failure.error = wireError
        #expect(throws: EndpointWireFailure.server(code: 403)) {
            try PBPageProtocol.decode(failure.serializedData())
        }

        let response = try PBPageProtocol.decode(
            makePBPageResponse(threadID: 8_002)
        )
        #expect(
            throws: PBPageProtocolError.threadIdentityMismatch(
                requested: 8_001,
                received: 8_002
            )
        ) {
            try PBPageProtocol.map(response, requestedThreadID: 8_001)
        }
    }

    @Test
    func liveRepositoryUsesPipelineAndMapsOnlyDomainValues() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveThreadReaderRepository(
            client: client,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadThread(threadID: 8_001)
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(
            call.request.url.absoluteString ==
                "https://fixture.invalid/c/f/pb/page" +
                "?cmd=302001&format=protobuf"
        )
        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PBPageProtocol.liveResponseMIMEType
                ],
                body: try makePBPageResponse(threadID: 8_001)
            )
        )

        let snapshot = try await load.value
        #expect(snapshot.threadID == 8_001)
        #expect(snapshot.posts.count == 2)
    }

    @Test
    func liveRepositoryKeepsCancellationObservable() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveThreadReaderRepository(
            client: client,
            host: "fixture.invalid"
        )
        let load = Task {
            try await repository.loadThread(threadID: 8_001)
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

    @MainActor
    @Test
    func threadReplacementCancelsOldAndRejectsLateCompletion() async throws {
        let repository = ControlledThreadReaderRepository()
        let store = ThreadReaderStore(threadID: 8_001, repository: repository)
        let old = makeSnapshot(threadID: 8_001, title: "old")
        let latest = makeSnapshot(threadID: 8_001, title: "latest")

        let first = Task {
            await store.reload()
        }
        try await repository.waitForCallCount(1)

        let second = Task {
            await store.reload()
        }
        try await repository.waitForCallCount(2)

        try await repository.succeed(call: 2, snapshot: latest)
        await second.value
        #expect(store.state == .loaded(latest))

        try await repository.succeed(call: 1, snapshot: old)
        await first.value
        #expect(store.state == .loaded(latest))
        #expect(await repository.cancelledCalls() == [1])
    }

    @MainActor
    @Test
    func threadCancellationNeverBecomesVisibleFailure() async throws {
        let repository = ControlledThreadReaderRepository()
        let store = ThreadReaderStore(threadID: 8_001, repository: repository)
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

    private func makePBPageResponse(threadID: Int64) throws -> Data {
        var threadAuthor = Tieba_User()
        threadAuthor.id = 7_001
        threadAuthor.name = "thread-author"
        threadAuthor.nameShow = "Thread author"

        var thread = Tieba_ThreadInfo()
        thread.id = threadID
        thread.threadID = threadID
        thread.title = "Live fixture title"
        thread.replyNum = 2
        thread.author = threadAuthor

        var forum = Tieba_SimpleForum()
        forum.id = 6_001
        forum.name = "Live fixture forum"

        var image = Tieba_PbContent()
        image.type = 3
        image.src = "https://fixture.invalid/live-image.jpg"
        image.text = "image"

        var firstPost = Tieba_Post()
        firstPost.id = 9_001
        firstPost.floor = 1
        firstPost.authorID = threadAuthor.id
        firstPost.author = threadAuthor
        firstPost.content = [image]
        firstPost.timeEx = "公开时间"

        var replyAuthor = Tieba_User()
        replyAuthor.id = 7_002
        replyAuthor.nameShow = "Reply author"

        var replyText = Tieba_PbContent()
        replyText.type = 0
        replyText.text = "Reply body"

        var reply = Tieba_Post()
        reply.id = 9_002
        reply.floor = 2
        reply.authorID = replyAuthor.id
        reply.author = replyAuthor
        reply.content = [replyText]

        var data = Tieba_PbPage_PbPageResponseData()
        data.thread = thread
        data.forum = forum
        data.firstFloorPost = firstPost
        data.postList = [reply]

        var response = Tieba_PbPage_PbPageResponse()
        response.data = data
        return try response.serializedData()
    }

    private func makeSnapshot(
        threadID: Int64,
        title: String
    ) -> ThreadReaderSnapshot {
        ThreadReaderSnapshot(
            threadID: threadID,
            title: title,
            forumName: "Forum",
            author: ThreadReaderAuthor(
                rawUserID: 1,
                displayName: "Author"
            ),
            replyCount: 0,
            posts: []
        )
    }
}

private enum ControlledThreadReaderRepositoryError: Error {
    case unknownCall
}

private actor ControlledThreadReaderRepository: ThreadReaderRepository {
    private struct PendingCall {
        let gate: HarnessContinuationGate<ThreadReaderSnapshot>
    }

    private struct CountObserver {
        let count: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var observers: [CountObserver] = []
    private var observedCancellation: [Int] = []

    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<ThreadReaderSnapshot>()
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

    func succeed(call: Int, snapshot: ThreadReaderSnapshot) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.succeed(snapshot) else {
            throw ControlledThreadReaderRepositoryError.unknownCall
        }
    }

    func fail(call: Int, error: any Error) throws {
        guard let pendingCall = pending.removeValue(forKey: call),
              pendingCall.gate.fail(error) else {
            throw ControlledThreadReaderRepositoryError.unknownCall
        }
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
