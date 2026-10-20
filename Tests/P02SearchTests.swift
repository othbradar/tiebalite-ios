import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct P02SearchTests {
    @Test
    func independentTypesRestoreResultsErrorsPagesAndAnchorsWithoutRefetch() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)
        store.setDraftKeyword("Fixture")
        let first = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        let threads = try snapshot(type: .threads)
        try await repository.succeedSearch(call: 1, value: threads)
        await first.value
        store.setScrollAnchor(.thread(101))
        let threadQuery = try #require(store.query)

        let switchToForums = Task { await store.selectType(.forums) }
        try await repository.waitForSearchCount(2)
        try await repository.failSearch(call: 2)
        await switchToForums.value
        #expect(store.state == .failed(keyword: threads.keyword, failure: .unavailable, retained: nil))
        await store.selectType(.threads)
        #expect(store.state == .loaded(threads))
        #expect(store.scrollAnchor == .thread(101))
        await store.selectType(.forums)
        #expect(store.listPresentation == nil)
        #expect(await repository.searchQueries().count == 2)

        let retry = Task { await store.retry() }
        try await repository.waitForSearchCount(3)
        let forums = try snapshot(type: .forums)
        try await repository.succeedSearch(call: 3, value: forums)
        await retry.value
        store.setScrollAnchor(.forum(201))
        store.setScrollAnchor(.thread(101), for: threadQuery)
        #expect(store.scrollAnchor == .forum(201))
        await store.loadNextPage()
        #expect(await repository.pageRequests().isEmpty)
        await store.selectType(.threads)
        #expect(store.state.snapshot?.currentThreadPage == 1)
        #expect(store.scrollAnchor == .thread(101))
        await store.selectType(.forums)
        #expect(store.scrollAnchor == .forum(201))
        #expect(await repository.searchQueries().map(\.type) == [.threads, .forums, .forums])
    }

    @Test
    func switchingTypeAndKeywordRejectsLateResultAndResetsOtherTypeCache() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)
        store.setDraftKeyword("Fixture")
        let threads = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        let forums = Task { await store.selectType(.forums) }
        try await repository.waitForSearchCount(2)
        try await repository.succeedSearch(call: 2, value: snapshot(type: .forums))
        await forums.value
        try await repository.succeedSearch(call: 1, value: snapshot(type: .threads))
        await threads.value
        #expect(store.selectedType == .forums)
        #expect(store.state.snapshot?.threads.isEmpty == true)

        store.setDraftKeyword("New")
        let newer = Task { await store.submit() }
        try await repository.waitForSearchCount(3)
        try await repository.succeedSearch(call: 3, value: snapshot(type: .forums, keyword: "New", empty: true))
        await newer.value
        let newKeyword = try #require(SearchKeyword("New"))
        #expect(store.state == .empty(newKeyword))
        let newThreads = Task { await store.selectType(.threads) }
        try await repository.waitForSearchCount(4)
        try await repository.succeedSearch(call: 4, value: snapshot(type: .threads, keyword: "New"))
        await newThreads.value
        #expect(store.submittedKeyword?.rawValue == "New")
        #expect(await repository.searchQueries().map { $0.keyword.rawValue } == ["Fixture", "Fixture", "New", "New"])
        #expect(await repository.cancelledSearchCalls() == [1])
    }

    @Test
    func liveRepositoryRequestsOnlySelectedEndpointAndRejectsUnknownForumScope() async throws {
        let client = HarnessMockHTTPClient()
        let store = SearchStore(repository: LiveSearchRepository(client: client, host: "fixture.invalid"))
        store.setDraftKeyword("Fixture")
        let threads = Task { await store.submit() }
        try await client.waitForPendingCallCount(1)
        let first = try #require(await client.pendingCalls().first)
        #expect(first.request.url.path == "/mo/q/search/thread")
        #expect(await client.pendingCalls().count == 1)
        try await client.succeed(first.id, with: response(fixture: "search.thread.page1.synthetic"))
        await threads.value
        #expect(store.state.snapshot?.forums.isEmpty == true)

        let forums = Task { await store.selectType(.forums) }
        try await client.waitForPendingCallCount(1)
        let second = try #require(await client.pendingCalls().first)
        #expect(second.request.url.path == "/mo/q/search/forum")
        #expect(await client.pendingCalls().count == 1)
        try await client.succeed(second.id, with: response(fixture: "search.forum.synthetic"))
        await forums.value
        #expect(store.state.snapshot?.threads.isEmpty == true)

        let forum = try #require(ForumRoute(forumID: 42, forumName: "Fixture"))
        let keyword = try #require(SearchKeyword("Fixture"))
        #expect(SearchQuery(scope: .forum(forum), type: .forums, keyword: keyword) == nil)
        let query = try #require(SearchQuery(scope: .forum(forum), keyword: keyword))
        let repository = LiveSearchRepository(client: client, host: "fixture.invalid")
        await #expect(throws: SearchWebProtocolError.unsupportedScope) { try await repository.search(query) }
        #expect(await client.pendingCalls().isEmpty)
    }

    @Test
    func searchScopeSurvivesRouteCodingAndUsesIndependentStore() throws {
        let oldRoute = try JSONDecoder().decode(RouteIdentity.self, from: Data(#"{"search":{}}"#.utf8))
        #expect(oldRoute == .search())
        let forum = try #require(ForumRoute(forumID: 42, forumName: "Fixture"))
        let route = RouteIdentity.search(scope: .forum(forum))
        #expect(try JSONDecoder().decode(RouteIdentity.self, from: JSONEncoder().encode(route)) == route)
        #expect(RouteGrammar.isValid([route], for: .recommendations))
        let registry = AppFeatureStoreRegistry(compositionRoot: LaunchScenarioFactory.make(scenario: .fixtureReadingFlow).compositionRoot)
        let global = registry.searchStore(for: .global)
        let scoped = registry.searchStore(for: .forum(forum))
        #expect(global === registry.searchStore)
        #expect(scoped !== global)
        #expect(scoped === registry.searchStore(for: .forum(forum)))
        #expect(scoped.scope == .forum(forum))
    }

    @Test
    func sortCachesAndPaginationStaySeparateAndRejectLatePages() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)
        store.setDraftKeyword("Fixture")
        let first = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        try await repository.succeedSearch(call: 1, value: snapshot(type: .threads))
        await first.value
        store.setScrollAnchor(.thread(101))
        let page = Task { await store.loadNextPage() }
        try await repository.waitForPageCount(1)
        let oldest = Task { await store.selectSort(.oldest) }
        try await repository.waitForSearchCount(2)
        try await repository.succeedSearch(call: 2, value: snapshot(type: .threads, sort: .oldest))
        await oldest.value
        try await repository.succeedPage(call: 1, value: ThreadSearchPage(items: [], currentPage: 2, hasMore: false))
        await page.value
        #expect(store.query?.sort == .oldest)
        #expect(store.state.snapshot?.currentThreadPage == 1)
        #expect(store.scrollAnchor == nil)

        let relevant = Task { await store.selectSort(.relevance) }
        try await repository.waitForSearchCount(3)
        try await repository.failSearch(call: 3)
        await relevant.value
        await store.selectSort(.newest)
        #expect(store.state.snapshot?.query.sort == .newest)
        #expect(store.scrollAnchor == .thread(101))
        await store.selectSort(.oldest)
        #expect(store.state.snapshot?.query.sort == .oldest)
        #expect(await repository.searchQueries().map(\.sort) == [.newest, .oldest, .relevance])
        #expect(await repository.pageRequests().first?.query.sort == .newest)

        let forums = Task { await store.selectType(.forums) }
        try await repository.waitForSearchCount(4)
        try await repository.succeedSearch(call: 4, value: snapshot(type: .forums))
        await forums.value
        #expect(store.query?.sort == .newest)
        await store.selectType(.threads)
        #expect(store.query?.sort == .oldest)
        await store.selectType(.forums)
        #expect(await repository.searchQueries().count == 4)
    }

    @Test
    func eachSortEncodesEvidenceValueOnFirstAndNextPage() throws {
        let keyword = try #require(SearchKeyword("Fixture"))
        for (sort, value) in [(SearchSort.newest, "5"), (.oldest, "0"), (.relevance, "2")] {
            let query = try #require(SearchQuery(keyword: keyword, sort: sort))
            for page in [1, 2] {
                let request = try #require(SearchThreadPageRequest(query: query, page: page))
                let descriptor = try SearchWebProtocol.makeThreadDescriptor(host: "fixture.invalid", request: request)
                #expect(descriptor.queryItems.contains(EndpointField(name: "st", value: value)))
                #expect(descriptor.queryItems.contains(EndpointField(name: "pn", value: String(page))))
                #expect(descriptor.authentication == .anonymous)
            }
        }
    }

    private func snapshot(type: SearchResultType, keyword: String = "Fixture", empty: Bool = false,
                          sort: SearchSort = .newest) throws -> SearchSnapshot {
        let keyword = try #require(SearchKeyword(keyword))
        let query = try #require(SearchQuery(type: type, keyword: keyword, sort: sort))
        return SearchSnapshot(query: query,
                              forums: empty ? [] : [.init(forumID: 201, name: "Fixture", displayName: "Fixture",
                                                          summary: nil, memberCountText: nil, postCountText: nil)],
                              threads: empty ? [] : [.init(threadID: 101, title: "Fixture", summary: nil,
                                                           forumID: 201, forumName: "Fixture", authorName: "Fixture", replyCount: 1)],
                              currentThreadPage: 1, hasMoreThreads: true)
    }

    private func response(fixture: String) throws -> HTTPResponse {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try FixtureLoader(rootDirectory: root).loadData(id: FixtureID(fixture), expectedFormat: .json)
        return HTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: data)
    }
}
