import Foundation
import Testing
@testable import TiebaLite

struct Stage16ASearchProtocolTests {
    @Test
    func sanitizedJSONMapsStableFirstWinsForumAndThreadIDs() throws {
        let forumData = try fixtureData(
            id: "search.forum.synthetic"
        )
        let firstThreadData = try fixtureData(
            id: "search.thread.page1.synthetic"
        )
        let secondThreadData = try fixtureData(
            id: "search.thread.page2.synthetic"
        )
        let keyword = try #require(SearchKeyword("Fixture"))

        let forums = try SearchWebProtocol.mapForumFixture(forumData)
        let first = try SearchWebProtocol.mapThreadFixture(
            firstThreadData,
            keyword: keyword,
            requestedPage: 1
        )
        let second = try SearchWebProtocol.mapThreadFixture(
            secondThreadData,
            keyword: keyword,
            requestedPage: 2
        )

        #expect(forums.map(\.forumID) == [16_001, 16_002])
        #expect(forums.first?.name == "fixture_dev")
        #expect(forums.first?.displayName == "Fixture 开发")
        #expect(forums[1].memberCountText == "12")
        #expect(first.items.map(\.threadID) == [26_001, 26_002])
        #expect(first.items.first?.forumID == 16_001)
        #expect(first.items.first?.replyCount == 18)
        #expect(first.currentPage == 1)
        #expect(first.hasMore)
        #expect(second.items.map(\.threadID) == [26_002, 26_003])
        #expect(second.currentPage == 2)
        #expect(!second.hasMore)
    }

    @Test
    func liveRequestsUseEvidenceLockedAnonymousGETParameters() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveSearchRepository(
            client: client,
            host: "fixture.invalid"
        )
        let keyword = try #require(SearchKeyword("Fixture 关键字"))

        let forumLoad = Task {
            try await repository.loadForums(keyword: keyword)
        }
        try await client.waitForPendingCallCount(1)
        let forumCall = try #require(await client.pendingCalls().first)
        #expect(forumCall.request.method == .get)
        #expect(forumCall.request.url.host == "fixture.invalid")
        #expect(forumCall.request.url.path == "/mo/q/search/forum")
        #expect(query(forumCall.request.url) == [
            "word": "Fixture 关键字"
        ])
        #expect(forumCall.request.body == nil)
        #expect(!containsCredentialHeader(forumCall.request.headers))
        try await client.succeed(
            forumCall.id,
            with: jsonResponse(
                try fixtureData(id: "search.forum.synthetic")
            )
        )
        _ = try await forumLoad.value

        let pageRequest = try #require(
            SearchThreadPageRequest(keyword: keyword, page: 2)
        )
        let threadLoad = Task {
            try await repository.loadThreadPage(pageRequest)
        }
        try await client.waitForPendingCallCount(1)
        let threadCall = try #require(await client.pendingCalls().first)
        #expect(threadCall.request.method == .get)
        #expect(threadCall.request.url.path == "/mo/q/search/thread")
        #expect(query(threadCall.request.url) == [
            "ct": "1",
            "cv": "99.9.101",
            "is_use_zonghe": "1",
            "pn": "2",
            "st": "5",
            "tt": "1",
            "word": "Fixture 关键字"
        ])
        #expect(threadCall.request.body == nil)
        #expect(!containsCredentialHeader(threadCall.request.headers))
        try await client.succeed(
            threadCall.id,
            with: jsonResponse(
                try fixtureData(id: "search.thread.page2.synthetic")
            )
        )
        _ = try await threadLoad.value
    }

    private func fixtureData(id: String) throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID(id),
            expectedFormat: .json
        )
    }

    private func jsonResponse(_ data: Data) -> HTTPResponse {
        HTTPResponse(
            statusCode: 200,
            headers: ["content-type": SearchWebProtocol.responseMIMEType],
            body: data
        )
    }

    private func query(_ url: URL) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: (URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )?.queryItems ?? []).map { item in
                (item.name, item.value ?? "")
            }
        )
    }

    private func containsCredentialHeader(
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
struct Stage16ASearchStoreTests {
    @Test
    func blankKeywordSendsNoRequest() async {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)

        store.setDraftKeyword("  \n  ")
        await store.submit()

        #expect(store.state == .idle)
        #expect(await repository.searchKeywords().isEmpty)
    }

    @Test
    func newerKeywordCancelsAndRejectsLateOlderResult() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)

        store.setDraftKeyword("old")
        let oldLoad = Task { await store.submit() }
        try await repository.waitForSearchCount(1)

        store.setDraftKeyword("new")
        let newLoad = Task { await store.submit() }
        try await repository.waitForSearchCount(2)
        let newest = Self.snapshot(keyword: "new", threadIDs: [202])
        try await repository.succeedSearch(call: 2, value: newest)
        await newLoad.value

        try await repository.succeedSearch(
            call: 1,
            value: Self.snapshot(keyword: "old", threadIDs: [101])
        )
        await oldLoad.value

        #expect(store.state == .loaded(newest))
        #expect(store.submittedKeyword?.rawValue == "new")
        #expect(await repository.cancelledSearchCalls() == [1])
    }

    @Test
    func sameCompletedKeywordDoesNotRepeatWithoutExplicitRetry() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)

        store.setDraftKeyword("same")
        let first = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        let snapshot = Self.snapshot(keyword: "same", threadIDs: [301])
        try await repository.succeedSearch(call: 1, value: snapshot)
        await first.value

        await store.submit()

        #expect(store.state == .loaded(snapshot))
        #expect(await repository.searchKeywords().map(\.rawValue) == ["same"])
    }

    @Test
    func cancellationRestoresIdleWithoutPresentingFailure() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)

        store.setDraftKeyword("cancel")
        let load = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        store.cancel()
        try await repository.succeedSearch(
            call: 1,
            value: Self.snapshot(keyword: "cancel", threadIDs: [401])
        )
        await load.value

        #expect(store.state == .idle)
        #expect(await repository.cancelledSearchCalls() == [1])
    }

    @Test
    func nextPageFailureRetainsResultsAndDuplicateTriggerIsSingleFlight() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)
        store.setDraftKeyword("page")

        let initial = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        let first = Self.snapshot(
            keyword: "page",
            threadIDs: [501, 502],
            hasMore: true
        )
        try await repository.succeedSearch(call: 1, value: first)
        await initial.value

        let failedLoad = Task { await store.loadNextPage() }
        try await repository.waitForPageCount(1)
        await store.loadNextPage()
        #expect(await repository.pageRequests().count == 1)
        try await repository.failPage(
            call: 1,
            error: FixtureReadingRepositoryError.unavailable
        )
        await failedLoad.value

        #expect(store.state.snapshot == first)
        #expect(store.listPresentation?.pagination == .failure)

        let retry = Task { await store.loadNextPage() }
        try await repository.waitForPageCount(2)
        let page = ThreadSearchPage(
            items: [
                Self.thread(id: 502),
                Self.thread(id: 503)
            ],
            currentPage: 2,
            hasMore: false
        )
        try await repository.succeedPage(call: 2, value: page)
        await retry.value

        #expect(store.state.snapshot?.threads.map(\.threadID) == [501, 502, 503])
        #expect(store.state.snapshot?.currentThreadPage == 2)
        #expect(store.state.snapshot?.hasMoreThreads == false)
        #expect(await repository.pageRequests().map(\.page) == [2, 2])
    }

    @Test
    func routesUseStableForumAndThreadBusinessIDs() throws {
        let forum = ForumSearchResult(
            forumID: 601,
            name: "fixture_forum",
            displayName: "Fixture 吧",
            summary: nil,
            memberCountText: nil,
            postCountText: nil
        )
        let thread = Self.thread(id: 602)
        let forumRoute = try #require(
            ForumRoute(forumID: 601, forumName: "fixture_forum")
        )
        let threadID = try #require(ThreadID(602))

        #expect(AppRouter.forumRoute(for: forum) == .forum(forumRoute))
        #expect(AppRouter.threadRoute(for: thread) == .thread(threadID))
        #expect(RouteGrammar.isValid([.search, .forum(forumRoute)], for: .recommendations))
        #expect(RouteGrammar.isValid([.search, .thread(threadID)], for: .recommendations))
    }

    @Test
    func fixtureCompositionSearchesWithoutHTTPOrRealSession() async throws {
        let descriptor = LaunchScenarioFactory.make(
            scenario: .fixtureReadingFlow
        )
        let root = descriptor.compositionRoot
        let store = root.makeSearchStore()
        let client = try #require(
            root.environment.httpClient as? HarnessMockHTTPClient
        )

        store.setDraftKeyword("Swift")
        await store.submit()

        let snapshot = try #require(store.state.snapshot)
        #expect(!snapshot.forums.isEmpty)
        #expect(!snapshot.threads.isEmpty)
        #expect(await client.events().isEmpty)
        #expect(root.authContextProvider.context() == .anonymous)
    }

    private static func snapshot(
        keyword: String,
        threadIDs: [Int64],
        hasMore: Bool = false
    ) -> SearchSnapshot {
        guard let normalizedKeyword = SearchKeyword(keyword) else {
            preconditionFailure("Invalid test search keyword")
        }
        return SearchSnapshot(
            keyword: normalizedKeyword,
            forums: [],
            threads: threadIDs.map(thread),
            currentThreadPage: 1,
            hasMoreThreads: hasMore
        )
    }

    private static func thread(id: Int64) -> ThreadSearchResult {
        ThreadSearchResult(
            threadID: id,
            title: "Thread \(id)",
            summary: "Fixture summary",
            forumID: 1,
            forumName: "Fixture 吧",
            authorName: "Fixture 作者",
            replyCount: 3
        )
    }
}

private enum ControlledSearchRepositoryError: Error {
    case unknownCall
}

private actor ControlledSearchRepository: SearchRepository {
    private struct SearchCall {
        let keyword: SearchKeyword
        let gate: HarnessContinuationGate<SearchSnapshot>
    }

    private struct PageCall {
        let request: SearchThreadPageRequest
        let gate: HarnessContinuationGate<ThreadSearchPage>
    }

    private struct Observer {
        let count: Int
        let gate: HarnessContinuationGate<Void>
    }

    private var searches: [SearchCall] = []
    private var pages: [PageCall] = []
    private var searchObservers: [Observer] = []
    private var pageObservers: [Observer] = []
    private var cancelledSearches: [Int] = []

    func search(keyword: SearchKeyword) async throws -> SearchSnapshot {
        let call = searches.count + 1
        let gate = HarnessContinuationGate<SearchSnapshot>()
        searches.append(SearchCall(keyword: keyword, gate: gate))
        resumeSearchObservers()
        do {
            let value = try await gate.wait()
            if Task.isCancelled {
                cancelledSearches.append(call)
            }
            return value
        } catch {
            if Task.isCancelled {
                cancelledSearches.append(call)
            }
            throw error
        }
    }

    func loadThreadPage(
        _ request: SearchThreadPageRequest
    ) async throws -> ThreadSearchPage {
        let gate = HarnessContinuationGate<ThreadSearchPage>()
        pages.append(PageCall(request: request, gate: gate))
        resumePageObservers()
        return try await gate.wait()
    }

    func waitForSearchCount(_ count: Int) async throws {
        guard searches.count < count else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        searchObservers.append(Observer(count: count, gate: gate))
        try await gate.wait()
    }

    func waitForPageCount(_ count: Int) async throws {
        guard pages.count < count else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        pageObservers.append(Observer(count: count, gate: gate))
        try await gate.wait()
    }

    func succeedSearch(call: Int, value: SearchSnapshot) throws {
        guard searches.indices.contains(call - 1) else {
            throw ControlledSearchRepositoryError.unknownCall
        }
        searches[call - 1].gate.succeed(value)
    }

    func succeedPage(call: Int, value: ThreadSearchPage) throws {
        guard pages.indices.contains(call - 1) else {
            throw ControlledSearchRepositoryError.unknownCall
        }
        pages[call - 1].gate.succeed(value)
    }

    func failPage(call: Int, error: any Error) throws {
        guard pages.indices.contains(call - 1) else {
            throw ControlledSearchRepositoryError.unknownCall
        }
        pages[call - 1].gate.fail(error)
    }

    func searchKeywords() -> [SearchKeyword] {
        searches.map(\.keyword)
    }

    func pageRequests() -> [SearchThreadPageRequest] {
        pages.map(\.request)
    }

    func cancelledSearchCalls() -> [Int] {
        cancelledSearches
    }

    private func resumeSearchObservers() {
        let ready = searchObservers.filter { searches.count >= $0.count }
        searchObservers.removeAll { searches.count >= $0.count }
        ready.forEach { $0.gate.succeed(()) }
    }

    private func resumePageObservers() {
        let ready = pageObservers.filter { pages.count >= $0.count }
        pageObservers.removeAll { pages.count >= $0.count }
        ready.forEach { $0.gate.succeed(()) }
    }
}
