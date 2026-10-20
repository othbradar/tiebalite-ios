import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct P02UserSearchTests {
    @Test
    func usersRequestOnlyAnonymousUserEndpointAndMapStableProfileIDs() async throws {
        let client = HarnessMockHTTPClient()
        let repository = LiveSearchRepository(client: client, host: "fixture.invalid")
        let query = try userQuery()
        let task = Task { try await repository.search(query) }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(call.request.method == .get)
        #expect(call.request.url.path == "/mo/q/search/user")
        #expect(URLComponents(url: call.request.url, resolvingAgainstBaseURL: false)?.queryItems == [
            URLQueryItem(name: "word", value: "Fixture")
        ])
        #expect(call.request.body == nil)
        #expect(!call.request.headers.keys.contains { ["cookie", "authorization"].contains($0.lowercased()) })
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try FixtureLoader(rootDirectory: root).loadData(id: FixtureID("search.user.synthetic"), expectedFormat: .json)
        try await client.succeed(call.id, with: HTTPResponse(statusCode: 200, headers: ["content-type": "application/json"], body: data))
        let snapshot = try await task.value
        #expect(snapshot.users.map(\.id) == [14_001, 14_002, 14_003])
        #expect(snapshot.users.map(\.isExactMatch) == [true, false, false])
        #expect(snapshot.users.first?.route.fallbackDisplayName == "Fixture 推荐用户")
        #expect(snapshot.users.last?.route.fallbackDisplayName == "fallback_name")
        #expect(snapshot.forums.isEmpty && snapshot.threads.isEmpty && !snapshot.hasMoreThreads)
        let profile = try #require(snapshot.users.first?.route)
        for root in [RootID.followedForums, .recommendations] {
            #expect(RouteGrammar.isValid([.search(), .userProfile(profile)], for: root))
            #expect(RouteGrammar.isValid([.search(scope: .global), .userProfile(profile)], for: root))
        }
        let presentation = SearchListPresentation(snapshot: snapshot, pagination: .idle)
        #expect(presentation.rows.map(\.id) == [
            .section(.recommended), .user(14_001), .section(.relatedUsers), .user(14_002), .user(14_003)
        ])
        #expect(presentation.prefetchRowIDs.isEmpty)
        #expect(SearchThreadPageRequest(query: query, page: 2) == nil)
    }

    @Test
    func arrayEmptyAndObjectRelatedResultsRemainDistinctFromMalformedOrRejectedResponses() throws {
        let empty = Data(#"{"no":0,"data":{"exactMatch":[],"fuzzyMatch":[]}}"#.utf8)
        #expect(try SearchUserWebProtocol.mapFixture(empty).isEmpty)
        let object = Data("""
        {"no":0,"data":{"exactMatch":[],"fuzzyMatch":{
          "0":{"id":"21","name":"A"},"1":null,"2":{"id":"22","name":"B"}
        }}}
        """.utf8)
        #expect(try SearchUserWebProtocol.mapFixture(object).map(\.id) == [21, 22])
        for body in ["", "not-json", #"{"no":0}"#, #"{"no":0,"data":{"fuzzyMatch":12}}"#,
                     #"{"no":401,"error":"fixture rejection"}"#] {
            #expect(throws: (any Error).self) { try SearchUserWebProtocol.mapFixture(Data(body.utf8)) }
        }
    }

    @Test
    func usersCacheAndPositionSurviveTypeSortChangesWithoutPagination() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)
        await store.selectType(.users)
        store.setDraftKeyword("Fixture")
        let load = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        let snapshot = try await FixtureSearchRepository().search(userQuery())
        try await repository.succeedSearch(call: 1, value: snapshot)
        await load.value
        #expect(store.state == .loaded(snapshot))
        store.setScrollAnchor(.user(14_018))
        await store.loadNextPage()
        await store.selectSort(.oldest)
        #expect(await repository.pageRequests().isEmpty)
        let threads = Task { await store.selectType(.threads) }
        try await repository.waitForSearchCount(2)
        try await repository.failSearch(call: 2)
        await threads.value
        await store.selectType(.users)
        #expect(store.state == .loaded(snapshot))
        #expect(store.scrollAnchor == .user(14_018))
        #expect(await repository.searchQueries().count == 2)
    }

    @Test
    func userErrorsRetryAndCancelledOldKeywordCannotReplaceNewEmptyResults() async throws {
        let repository = ControlledSearchRepository()
        let store = SearchStore(repository: repository)
        await store.selectType(.users)
        store.setDraftKeyword("Fixture")
        let failed = Task { await store.submit() }
        try await repository.waitForSearchCount(1)
        try await repository.failSearch(call: 1)
        await failed.value
        #expect(store.state == .failed(keyword: try #require(SearchKeyword("Fixture")), failure: .unavailable, retained: nil))
        let retry = Task { await store.retry() }
        try await repository.waitForSearchCount(2)
        store.setDraftKeyword("New")
        let fresh = Task { await store.submit() }
        try await repository.waitForSearchCount(3)
        let query = try userQuery("New")
        let empty = SearchSnapshot(query: query, forums: [], threads: [], currentThreadPage: 1, hasMoreThreads: false)
        try await repository.succeedSearch(call: 3, value: empty)
        await fresh.value
        let old = try await FixtureSearchRepository().search(userQuery())
        try await repository.succeedSearch(call: 2, value: old)
        await retry.value
        #expect(store.state == .empty(query.keyword))
        #expect(await repository.cancelledSearchCalls() == [2])
    }

    private func userQuery(_ text: String = "Fixture") throws -> SearchQuery {
        let keyword = try #require(SearchKeyword(text))
        return try #require(SearchQuery(type: .users, keyword: keyword, sort: .oldest))
    }

    @Test
    func userTransportFailuresAndCancellationRemainTypedWithoutAutomaticRetry() async throws {
        let query = try userQuery()
        for (failure, expected) in [(HTTPClientError.timedOut, EndpointExecutionError.transport(.timedOut)),
                                    (.offline, .transport(.offline))] {
            let client = HarnessMockHTTPClient(defaultBehavior: .failure(failure))
            let repository = LiveSearchRepository(client: client, host: "fixture.invalid")
            await #expect(throws: expected) { try await repository.search(query) }
            #expect(await client.events().count == 2)
        }
        let client = HarnessMockHTTPClient()
        let repository = LiveSearchRepository(client: client, host: "fixture.invalid")
        let task = Task { try await repository.search(query) }
        try await client.waitForPendingCallCount(1)
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await client.pendingCalls().isEmpty)
    }
}
