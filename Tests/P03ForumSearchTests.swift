import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct P03ForumSearchTests {
    @Test
    func forumSearchUsesExistingPushPathAndReturnsWithoutReplacingForum() throws {
        let forum = try #require(ForumRoute(forumID: 16001, forumName: "Fixture 开发"))
        let search = RouteIdentity.search(scope: .forum(forum))
        let thread = try #require(ThreadID(26001))
        let post = try #require(PostID(36001))
        let destinations: [RouteIdentity] = [
            .thread(thread), .profileReply(.init(threadID: 26001, postID: 36001)),
            .subposts(threadID: thread, postID: post)
        ]
        for root in [RootID.followedForums, .recommendations] {
            for destination in destinations {
                let navigation = AppNavigationStore(initialState: .init(selectedTab: root.tab))
                #expect(navigation.push(.forum(forum), in: root))
                #expect(navigation.push(search, in: root))
                #expect(navigation.push(destination, in: root, readingEntry: .search))
                #expect(navigation.state.routes(for: root) == [.forum(forum), search, destination])
                #expect(navigation.readingEntry(for: destination, scope: .root(root)) == .search)
                #expect(!AppShellPresentation.showsPhoneTabSelector(in: navigation.state))
                #expect(navigation.replacePathFromSystem([.forum(forum), search], in: root))
                #expect(navigation.replacePathFromSystem([.forum(forum)], in: root))
            }
        }
        let settings: [SettingsRoute] = [.history, .content(.forum(forum)), .content(search), .content(.thread(thread))]
        #expect(SettingsRouteGrammar.canonical(settings) == settings)
        let other = try #require(ForumRoute(forumID: 16002, forumName: "Fixture 摄影"))
        #expect(!RouteGrammar.permitsContentAction(from: .forum(forum), to: .search(scope: .forum(other))))
    }

    @Test
    func forumScopeIsSentOnFirstPageAndNextPage() async throws {
        let client = P03SearchHTTPClient()
        let repository = LiveSearchRepository(client: client, host: "fixture.invalid")
        let forum = try #require(ForumRoute(forumID: 16001, forumName: "Fixture 开发"))
        let keyword = try #require(SearchKeyword("共同词"))
        let query = try #require(SearchQuery(scope: .forum(forum), keyword: keyword))
        let first = try await repository.search(query)
        #expect(first.threads.map(\.threadID) == [26001])
        _ = try await repository.loadThreadPage(#require(SearchThreadPageRequest(query: query, page: 2)))
        let requests = await client.requests
        #expect(requests.count == 2)
        for (index, request) in requests.enumerated() {
            let fields = Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url, resolvingAgainstBaseURL: false)?
                .queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(request.method == .get)
            #expect(fields == ["word": "共同词", "fname": "Fixture 开发", "pn": String(index + 1),
                               "rn": "20", "st": "5", "tt": "1", "ct": "1", "cv": "22.11.1"])
            #expect(request.headers.keys.allSatisfy { !["cookie", "authorization"].contains($0.lowercased()) })
        }
    }

    @Test
    func sameKeywordInTwoForumsAndGlobalUsesDistinctRequestsAndResults() async throws {
        let client = P03SearchHTTPClient()
        let repository = LiveSearchRepository(client: client, host: "fixture.invalid")
        let queryA = try pageRequest().query
        let queryB = try pageRequest(name: "Fixture 摄影", id: 16002).query
        let global = try #require(SearchQuery(keyword: queryA.keyword))
        var snapshots: [SearchSnapshot] = []
        for query in [queryA, queryB, global] { snapshots.append(try await repository.search(query)) }
        #expect(snapshots.map { $0.threads.first?.threadID } == [26001, 26002, 26003])
        #expect(Set(snapshots.map(\.query)).count == 3)
        let names = await client.requests.map { request in
            URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "fname" }?.value
        }
        #expect(names == ["Fixture 开发", "Fixture 摄影", nil])
    }

    @Test
    func mappedHitsKeepEveryFloorAndUseExistingCorrectDestination() throws {
        let request = try pageRequest()
        let page = try mapFixture(request: request)
        #expect(page.items.count == 4)
        #expect(Set(page.items.map(\.id)).count == 4)
        #expect(page.items[0].thumbnailResources.count == 1)
        #expect(page.items[3].title == "共同词的合成命中内容")
        #expect(page.items[3].quotedPosts.map(\.authorName) == ["fixture_parent", "fixture_topic"])
        #expect(page.items[3].quotedPosts.first?.text == "合成父回复")
        let tid = try #require(ThreadID(26001))
        #expect(AppRouter.threadRoute(for: page.items[0]) == .thread(tid))
        #expect(AppRouter.threadRoute(for: page.items[1]) == .profileReply(.init(threadID: 26001, postID: 36001)))
        #expect(AppRouter.threadRoute(for: page.items[2]) == .profileReply(.init(threadID: 26001, postID: 36002)))
        let parent = try #require(PostID(36002))
        #expect(AppRouter.threadRoute(for: page.items[3]) == .subposts(threadID: tid, postID: parent))
        let snapshot = SearchSnapshot(query: request.query, forums: [], threads: page.items,
                                      currentThreadPage: 1, hasMoreThreads: true)
        #expect(snapshot.appending(page).threads.count == 4)
        let presentation = SearchListPresentation(snapshot: snapshot, pagination: .idle)
        #expect(Set(presentation.rows.map(\.id)).count == 5)
    }

    @Test
    func mismatchedForumOrPageAndServerFailureNeverBecomeGlobalSuccess() throws {
        let wrongScope = try pageRequest(name: "Fixture 摄影", id: 16002)
        #expect(throws: EndpointExecutionError.mapping) { try mapFixture(request: wrongScope) }
        let second = try pageRequest(page: 2)
        #expect(throws: EndpointExecutionError.mapping) {
            try mapFixture(request: second)
        }
        let request = try pageRequest()
        let endpoint = try InForumSearchProtocol.makeDescriptor(host: "fixture.invalid", request: request)
        let adapter = FixtureEndpointAdapter(endpoint: endpoint, pipeline: SearchWebProtocol.threadPipeline(request: request))
        #expect(throws: (any Error).self) {
            try adapter.map(Data(#"{"no":300003,"error":"fixture rejected"}"#.utf8), mimeType: "application/json")
        }
        #expect(try adapter.map(Data(#"{"no":0,"data":{"current_page":1,"has_more":0,"post_list":[]}}"#.utf8),
                                mimeType: "application/json").items.isEmpty)
    }

    @Test
    func scopedStoresSeparateLateResultsAndRetryKeepsOriginalPageAndScope() async throws {
        let repository = ControlledSearchRepository()
        let queryA = try pageRequest().query
        let queryB = try pageRequest(name: "Fixture 摄影", id: 16002).query
        let global = SearchStore(repository: repository)
        let storeA = global.makeScopedStore(queryA.scope), storeB = global.makeScopedStore(queryB.scope)
        for store in [global, storeA, storeB] { store.setDraftKeyword("共同词") }
        let taskA = Task { await storeA.submit() }
        try await repository.waitForSearchCount(1)
        let taskB = Task { await storeB.submit() }
        try await repository.waitForSearchCount(2)
        let snapshotB = try sampleSnapshot(query: queryB, id: 202)
        try await repository.succeedSearch(call: 2, value: snapshotB)
        await taskB.value
        storeA.cancel()
        try await repository.succeedSearch(call: 1, value: sampleSnapshot(query: queryA, id: 101))
        await taskA.value
        #expect(storeA.state == .idle)
        #expect(storeB.state.snapshot == snapshotB)
        #expect(global.state == .idle)
        storeB.setScrollAnchor(.thread(202))
        let next = Task { await storeB.loadNextPage() }
        try await repository.waitForPageCount(1)
        try await repository.failPage(call: 1, error: SearchLoadFailure.unavailable)
        await next.value
        #expect(storeB.state.snapshot == snapshotB)
        let retry = Task { await storeB.retry() }
        try await repository.waitForPageCount(2)
        let requests = await repository.pageRequests()
        #expect(requests.count == 2 && requests.allSatisfy { $0.query == queryB && $0.page == 2 })
        try await repository.succeedPage(call: 2, value: .init(items: [], currentPage: 2, hasMore: false))
        await retry.value
        #expect(storeB.scrollAnchor == .thread(202))
        #expect(storeB.state.snapshot?.threads.map(\.threadID) == [202])
        await storeB.selectType(.users)
        #expect(storeB.selectedType == .threads)
    }

    @Test
    func modesHaveEvidenceValuesAndCachesRestoreWithoutRefetch() async throws {
        let repository = ControlledSearchRepository()
        let request = try pageRequest()
        let store = SearchStore(repository: repository, scope: request.query.scope)
        store.setDraftKeyword("共同词")
        let combinations: [(ForumSearchMode, SearchSort)] = [(.topics, .newest), (.comments, .newest),
                                                             (.comments, .relevance), (.topics, .relevance)]
        for (index, pair) in combinations.enumerated() {
            let task = Task {
                if index == 0 {
                    await store.submit()
                } else if store.selectedForumMode != pair.0 {
                    await store.selectForumMode(pair.0)
                } else {
                    await store.selectSort(pair.1)
                }
            }
            try await repository.waitForSearchCount(index + 1)
            let query = try #require(store.query)
            #expect(query.forumMode == pair.0 && query.sort == pair.1)
            let nextRequest = try #require(SearchThreadPageRequest(query: query, page: 2))
            let descriptor = try InForumSearchProtocol.makeDescriptor(host: "fixture.invalid", request: nextRequest)
            #expect(descriptor.queryItems.contains(EndpointField(name: "st", value: pair.1 == .relevance ? "2" : "5")))
            #expect(descriptor.queryItems.contains(EndpointField(name: "tt", value: pair.0 == .topics ? "1" : "3")))
            try await repository.succeedSearch(call: index + 1, value: sampleSnapshot(query: query, id: Int64(index + 1)))
            await task.value
        }
        await store.selectSort(.newest)
        #expect(store.state.snapshot?.threads.first?.threadID == 1)
        #expect(await repository.searchQueries().count == 4)
    }

    @Test
    func historySurvivesReopeningDeduplicatesLimitsAndNeverChangesForumScope() async throws {
        let suite = "P03-history-" + UUID().uuidString
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let history = LocalSearchHistoryRepository(persists: true, suiteName: suite)
        for index in 0..<23 { _ = await history.record(try #require(SearchKeyword("Fixture \(index)"))) }
        _ = await history.record(try #require(SearchKeyword("Fixture 20")))
        let reopened = LocalSearchHistoryRepository(persists: true, suiteName: suite)
        let words = await reopened.load()
        #expect(words.count == 20 && words.first == "Fixture 20" && Set(words).count == 20)
        let query = try pageRequest().query
        let store = SearchStore(repository: FixtureSearchRepository(), scope: query.scope, historyRepository: reopened)
        await store.loadHistory()
        store.setDraftKeyword(try #require(store.searchHistory.first))
        await store.submit()
        #expect(store.query?.scope == query.scope)
        store.setDraftKeyword("")
        #expect(store.state == .idle && store.submittedKeyword == nil)
        #expect(!store.searchHistory.isEmpty)
        await store.clearHistory()
        #expect(store.searchHistory.isEmpty)
        #expect(await history.load().isEmpty)
    }

    private func pageRequest(name: String = "Fixture 开发", id: Int64 = 16001, page: Int = 1) throws -> SearchThreadPageRequest {
        let forum = try #require(ForumRoute(forumID: id, forumName: name))
        let keyword = try #require(SearchKeyword("共同词"))
        let query = try #require(SearchQuery(scope: .forum(forum), keyword: keyword))
        return try #require(SearchThreadPageRequest(query: query, page: page))
    }

    private func mapFixture(request: SearchThreadPageRequest) throws -> ThreadSearchPage {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try FixtureLoader(rootDirectory: root).loadData(id: FixtureID("search.in-forum.synthetic"), expectedFormat: .json)
        let endpoint = try InForumSearchProtocol.makeDescriptor(host: "fixture.invalid", request: request)
        return try FixtureEndpointAdapter(endpoint: endpoint, pipeline: SearchWebProtocol.threadPipeline(request: request))
            .map(data, mimeType: "application/json")
    }

    private func sampleSnapshot(query: SearchQuery, id: Int64) throws -> SearchSnapshot {
        SearchSnapshot(query: query, forums: [], threads: [
            .init(threadID: id, title: "Fixture", summary: nil, forumID: 16001,
                  forumName: "Fixture", authorName: "Fixture", replyCount: 1)
        ], currentThreadPage: 1, hasMoreThreads: true)
    }

}

private actor P03SearchHTTPClient: HTTPClient {
    private(set) var requests: [HTTPRequest] = []
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let page = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "pn" }?.value ?? "1"
        let name = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "fname" }?.value
        let forumID = name == "Fixture 摄影" ? 16002 : 16001
        let threadID = name == nil ? 26003 : name == "Fixture 摄影" ? 26002 : 26001
        let body = """
        {"no":0,"data":{"current_page":\(page),"has_more":1,"post_list":[
        {"tid":"\(threadID)","title":"Fixture","content":"合成搜索样本","forum_id":"\(forumID)","forum_name":"\(name ?? "Fixture 开发")"}]}}
        """
        return HTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: Data(body.utf8))
    }
}
