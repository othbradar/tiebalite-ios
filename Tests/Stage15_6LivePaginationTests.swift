import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct Stage156LivePaginationTests {
    @Test
    func liveRecommendationSecondPageUsesEvidenceLockedParameters() async throws {
        let client = HarnessMockHTTPClient()
        let provider = try activeProvider()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: provider,
            host: "fixture.invalid"
        )
        let request = RecommendationPageRequest(
            loadKind: .nextPage,
            page: 2
        )
        let load = Task {
            try await repository.loadPage(request)
        }

        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        let wire = try Tieba_PersonalizedRequest(
            serializedBytes: extractPersonalizedPayload(
                from: try #require(call.request.body)
            )
        )
        #expect(wire.data.loadType == 2)
        #expect(wire.data.pn == 2)
        #expect(wire.data.pageThreadCount == 11)

        try await client.succeed(
            call.id,
            with: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try personalizedResponse(threadIDs: [7_001, 7_002])
                    .serializedData()
            )
        )

        let page = try await load.value
        #expect(page.requestedPage == 2)
        #expect(page.nextPageCandidate == 3)
        #expect(page.items.map(\.threadID) == [7_001, 7_002])
    }

    @Test
    func invalidRecommendationPageContractFailsBeforeHTTP() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveRecommendationRepository(
            client: client,
            authContextProvider: try activeProvider(),
            host: "fixture.invalid"
        )

        await #expect(
            throws: RecommendationRepositoryError.invalidRequest
        ) {
            try await repository.loadPage(
                RecommendationPageRequest(loadKind: .refresh, page: 2)
            )
        }
        #expect(await client.events().isEmpty)

        await #expect(
            throws: RecommendationRepositoryError.invalidRequest
        ) {
            try await FixtureRecommendationRepository().loadPage(
                RecommendationPageRequest(loadKind: .nextPage, page: 1)
            )
        }
    }

    @Test
    func fixtureRecommendationsLoadThreePagesWithStableFirstWinsOrder() async throws {
        let store = RecommendationsStore(
            repository: FixtureRecommendationRepository()
        )

        await store.loadIfNeeded()
        #expect(store.state.items?.count == 4)
        #expect(store.currentPage == 1)
        #expect(store.nextPage == 2)

        await store.loadNextPage()
        #expect(store.state.items?.count == 8)
        #expect(store.currentPage == 2)
        #expect(store.nextPage == 3)

        await store.loadNextPage()
        let final = try #require(store.state.items)
        #expect(final.map(\.threadID) == (100_001...100_012).map(Int64.init))
        #expect(Set(final.map(\.threadID)).count == 12)
        #expect(store.currentPage == 3)
        #expect(store.nextPage == nil)

        await store.loadNextPage()
        #expect(store.state.items == final)
    }

    @Test
    func recommendationFailureRetryBurstAndRefreshGenerationStayIsolated() async throws {
        let repository = Stage156ControlledRecRepo()
        let store = RecommendationsStore(repository: repository)
        let first = Self.recommendations([1, 2])

        let initial = Task { await store.loadIfNeeded() }
        try await repository.waitForCallCount(1)
        try await repository.succeed(
            call: 1,
            page: Self.page(first, requestedPage: 1, nextPage: 2)
        )
        await initial.value

        let failedNext = Task { await store.loadNextPage() }
        try await repository.waitForCallCount(2)
        await store.loadNextPage()
        #expect(await repository.requests().count == 2)
        try await repository.fail(
            call: 2,
            error: FixtureReadingRepositoryError.unavailable
        )
        await failedNext.value
        #expect(store.state == .nextPageFailure(first))
        #expect(store.currentPage == 1)

        let retriedNext = Task { await store.loadNextPage() }
        try await repository.waitForCallCount(3)
        try await repository.succeed(
            call: 3,
            page: Self.page(
                Self.recommendations([2, 3]),
                requestedPage: 2,
                nextPage: 3
            )
        )
        await retriedNext.value
        #expect(store.state.items?.map(\.threadID) == [1, 2, 3])

        let staleNext = Task { await store.loadNextPage() }
        try await repository.waitForCallCount(4)
        let refresh = Task { await store.reload() }
        try await repository.waitForCallCount(5)
        let refreshed = Self.recommendations([9])
        try await repository.succeed(
            call: 5,
            page: Self.page(refreshed, requestedPage: 1, nextPage: 2)
        )
        await refresh.value

        try await repository.succeed(
            call: 4,
            page: Self.page(
                Self.recommendations([4]),
                requestedPage: 3,
                nextPage: 4
            )
        )
        await staleNext.value

        #expect(store.state == .loaded(refreshed))
        #expect(store.currentPage == 1)
        #expect(store.nextPage == 2)
        #expect(await repository.cancelledCalls() == [4])
        #expect(await repository.requests().map(\.page) == [1, 2, 2, 3, 1])

        let failedRefresh = Task { await store.reload() }
        try await repository.waitForCallCount(6)
        try await repository.fail(
            call: 6,
            error: FixtureReadingRepositoryError.unavailable
        )
        await failedRefresh.value
        #expect(store.state == .refreshFailure(refreshed))
        #expect(store.currentPage == 1)
        #expect(store.nextPage == 2)
    }

    @Test
    func emptyOrDuplicateOnlyRecommendationPageStopsClientPrefetch() async throws {
        let duplicateRepository = Stage156SequenceRecRepo(
            pages: [
                Self.page(
                    Self.recommendations([1, 2]),
                    requestedPage: 1,
                    nextPage: 2
                ),
                Self.page(
                    Self.recommendations([1, 2]),
                    requestedPage: 2,
                    nextPage: 3
                )
            ]
        )
        let store = RecommendationsStore(repository: duplicateRepository)

        await store.loadIfNeeded()
        await store.loadNextPage()

        #expect(store.state.items?.map(\.threadID) == [1, 2])
        #expect(store.currentPage == 2)
        #expect(store.nextPage == nil)
        await store.loadNextPage()
        #expect(await duplicateRepository.requests().map(\.page) == [1, 2])
    }

    @Test
    func wrongRecommendationPageIdentityRetainsLoadedItems() async throws {
        let first = Self.recommendations([1, 2])
        let repository = Stage156SequenceRecRepo(
            pages: [
                Self.page(first, requestedPage: 1, nextPage: 2),
                Self.page(
                    Self.recommendations([3]),
                    requestedPage: 3,
                    nextPage: 4
                )
            ]
        )
        let store = RecommendationsStore(repository: repository)

        await store.loadIfNeeded()
        await store.loadNextPage()

        #expect(store.state == .nextPageFailure(first))
        #expect(store.currentPage == 1)
        #expect(store.nextPage == 2)
    }

    @Test
    func threadRejectsSkippedResponsePageAndRetainsLoadedRows() async throws {
        let repository = Stage156SkippedThreadPageRepository()
        let store = ThreadReaderStore(threadID: 140_006, repository: repository)

        await store.loadIfNeeded()
        let retained = try #require(store.state.snapshot)
        await store.loadNextPage()

        #expect(store.state == .nextPageFailure(retained))
        #expect(store.listPresentation?.postRowCount == retained.posts.count)
        #expect(await repository.requests().map(\.pageNumber) == [0, 2])
    }

    @Test
    func zeroCursorFallbackContinuesByExactSequentialPage() async throws {
        let repository = Stage156ZeroCursorThreadRepository()
        let store = ThreadReaderStore(threadID: 140_006, repository: repository)

        await store.loadIfNeeded()
        await store.loadNextPage()
        await store.loadNextPage()

        #expect(store.state.snapshot?.currentPage == 3)
        #expect(store.state.snapshot?.posts.count == 47)
        #expect(await repository.requests().map(\.pageNumber) == [0, 2, 3])
        #expect(await repository.requests().map(\.postID) == [0, 0, 0])
    }

    @Test
    func duplicateOnlyThreadPageRetainsRowsAndRetriesExactRequest() async throws {
        let repository = Stage156NoProgressThreadRepository()
        let store = ThreadReaderStore(threadID: 140_006, repository: repository)

        await store.loadIfNeeded()
        let retained = try #require(store.state.snapshot)

        await store.loadNextPage()
        #expect(store.state == .nextPageFailure(retained))
        #expect(store.listPresentation?.postRowCount == retained.posts.count)

        await store.loadNextPage()
        #expect(store.state == .nextPageFailure(retained))
        #expect(await repository.requests().map(\.pageNumber) == [0, 2, 2])
        #expect(await repository.requests().map(\.postID) == [0, 0, 0])
    }

    @Test
    func cancelledPrefetchTriggerDoesNotCancelStoreOwnedPage() async throws {
        let repository = Stage156ControlledRecRepo()
        let store = RecommendationsStore(repository: repository)
        let first = Self.recommendations([1, 2])

        let initial = Task { await store.loadIfNeeded() }
        try await repository.waitForCallCount(1)
        try await repository.succeed(
            call: 1,
            page: Self.page(first, requestedPage: 1, nextPage: 2)
        )
        await initial.value

        let triggerGate = HarnessContinuationGate<Void>()
        let trigger = Task { @MainActor in
            store.requestNextPage(after: 2)
            try? await triggerGate.wait()
        }
        try await repository.waitForCallCount(2)
        trigger.cancel()
        triggerGate.cancel()
        await trigger.value
        try await repository.succeed(
            call: 2,
            page: Self.page(
                Self.recommendations([2, 3]),
                requestedPage: 2,
                nextPage: 3
            )
        )
        for _ in 0..<20 where store.currentPage != 2 {
            await Task.yield()
        }

        #expect(store.state.items?.map(\.threadID) == [1, 2, 3])
        #expect(store.currentPage == 2)
        #expect(await repository.cancelledCalls().isEmpty)
    }

    private func extractPersonalizedPayload(from body: Data) throws -> Data {
        let prefix = Data(
            (
                "Content-Disposition: form-data; name=\"data\"; " +
                    "filename=\"file\"\r\n\r\n"
            ).utf8
        )
        let suffix = Data(
            "\r\n--\(PersonalizedProtocol.boundary)--\r\n".utf8
        )
        let start = try #require(body.range(of: prefix)?.upperBound)
        let end = try #require(
            body.range(of: suffix, in: start..<body.endIndex)?.lowerBound
        )
        return body.subdata(in: start..<end)
    }

    private func personalizedResponse(
        threadIDs: [Int64]
    ) -> Tieba_PersonalizedResponse {
        var data = Tieba_PersonalizedResponseData()
        data.threadList = threadIDs.map { threadID in
            var thread = Tieba_ThreadInfo()
            thread.id = threadID
            thread.threadID = threadID + 10_000
            thread.title = "Fixture \(threadID)"
            thread.forumName = "Fixture forum"
            return thread
        }
        var response = Tieba_PersonalizedResponse()
        response.error = Tieba_Error()
        response.data = data
        return response
    }

    private func activeProvider() throws -> SessionAuthContextProvider {
        let provider = SessionAuthContextProvider()
        provider.install(
            try #require(
                SessionCredential(
                    bduss: "fx-stage15-6-b",
                    stoken: "fx-stage15-6-s"
                )
            )
        )
        return provider
    }

    private static func page(
        _ items: [RecommendationSummary],
        requestedPage: UInt32,
        nextPage: UInt32?
    ) -> RecommendationRepositoryPage {
        RecommendationRepositoryPage(
            items: items,
            requestedPage: requestedPage,
            nextPageCandidate: nextPage
        )
    }

    private static func recommendations(
        _ threadIDs: [Int64]
    ) -> [RecommendationSummary] {
        threadIDs.map { threadID in
            RecommendationSummary(
                threadID: threadID,
                title: "Thread \(threadID)",
                forumName: "Forum",
                authorName: "Author",
                replyCount: 1,
                thumbnail: nil
            )
        }
    }
}

private actor Stage156ControlledRecRepo:
    RecommendationRepository {
    private struct PendingCall {
        let request: RecommendationPageRequest
        let gate: HarnessContinuationGate<RecommendationRepositoryPage>
    }

    private var calls: [PendingCall] = []
    private var observers: [(Int, HarnessContinuationGate<Void>)] = []
    private var cancellations: [Int] = []

    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await loadPage(.initial).items
    }

    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage {
        let call = calls.count + 1
        let gate = HarnessContinuationGate<RecommendationRepositoryPage>()
        calls.append(PendingCall(request: request, gate: gate))
        resumeObservers()
        do {
            let page = try await gate.wait()
            if Task.isCancelled {
                cancellations.append(call)
            }
            return page
        } catch {
            if Task.isCancelled {
                cancellations.append(call)
            }
            throw error
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        if calls.count >= expected {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        observers.append((expected, gate))
        try await gate.wait()
    }

    func succeed(
        call: Int,
        page: RecommendationRepositoryPage
    ) throws {
        guard calls.indices.contains(call - 1),
              calls[call - 1].gate.succeed(page) else {
            throw FixtureReadingRepositoryError.unavailable
        }
    }

    func fail(call: Int, error: any Error) throws {
        guard calls.indices.contains(call - 1),
              calls[call - 1].gate.fail(error) else {
            throw FixtureReadingRepositoryError.unavailable
        }
    }

    func requests() -> [RecommendationPageRequest] {
        calls.map(\.request)
    }

    func cancelledCalls() -> [Int] {
        cancellations.sorted()
    }

    private func resumeObservers() {
        observers = observers.filter { expected, gate in
            guard calls.count < expected else {
                gate.succeed(())
                return false
            }
            return true
        }
    }
}

private actor Stage156SequenceRecRepo:
    RecommendationRepository {
    private let pages: [RecommendationRepositoryPage]
    private var recordedRequests: [RecommendationPageRequest] = []

    init(pages: [RecommendationRepositoryPage]) {
        self.pages = pages
    }

    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await loadPage(.initial).items
    }

    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage {
        recordedRequests.append(request)
        guard pages.indices.contains(recordedRequests.count - 1) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return pages[recordedRequests.count - 1]
    }

    func requests() -> [RecommendationPageRequest] {
        recordedRequests
    }
}

private actor Stage156SkippedThreadPageRepository: ThreadReaderRepository {
    private let base = FixtureThreadReaderRepository()
    private var recordedRequests: [ThreadReaderPageRequest] = []

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        recordedRequests.append(request)
        let page = try await base.loadPage(request)
        guard request.pageNumber > 0 else {
            return page
        }
        return ThreadReaderSnapshot(
            threadID: page.threadID,
            title: page.title,
            forumName: page.forumName,
            author: page.author,
            replyCount: page.replyCount,
            posts: page.posts,
            currentPage: request.pageNumber + 1,
            totalPage: page.totalPage,
            hasMore: page.hasMore,
            nextPostID: page.nextPostID
        )
    }

    func requests() -> [ThreadReaderPageRequest] {
        recordedRequests
    }
}

private actor Stage156ZeroCursorThreadRepository: ThreadReaderRepository {
    private let base = FixtureThreadReaderRepository()
    private var recordedRequests: [ThreadReaderPageRequest] = []

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        recordedRequests.append(request)
        let baseRequest: ThreadReaderPageRequest
        if request.pageNumber > 0 {
            baseRequest = ThreadReaderPageRequest(
                threadID: request.threadID,
                pageNumber: request.pageNumber,
                postID: FixtureThreadReaderPages.nextPostID(
                    for: try seed(request.threadID),
                    afterPage: request.pageNumber - 1
                ),
                loadedPostIDs: request.loadedPostIDs
            )
        } else {
            baseRequest = request
        }
        let page = try await base.loadPage(baseRequest)
        return ThreadReaderSnapshot(
            threadID: page.threadID,
            title: page.title,
            forumName: page.forumName,
            author: page.author,
            replyCount: page.replyCount,
            posts: page.posts,
            currentPage: page.currentPage,
            totalPage: page.totalPage,
            hasMore: page.hasMore,
            nextPostID: page.hasMore ? 0 : nil
        )
    }

    func requests() -> [ThreadReaderPageRequest] {
        recordedRequests
    }

    private func seed(_ threadID: Int64) throws -> FixtureThreadSeed {
        guard let seed = FixtureReadingCatalog.allThreadSeeds.first(where: {
            $0.threadID == threadID
        }) else {
            throw FixtureReadingRepositoryError.threadNotFound
        }
        return seed
    }
}
