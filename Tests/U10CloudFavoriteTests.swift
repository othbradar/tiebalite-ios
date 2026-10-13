import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U10CloudFavoriteTests {
    @Test func requestsMatchReplayedIOSCommonAndSignature() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let url = root.appendingPathComponent("API/Favorites/native-ios-forms.json")
        let fixture = try JSONDecoder().decode(Forms.self, from: Data(contentsOf: url))
        let operations: [NativeFavoriteRequest.Operation] = [.list(0), .save(entry()), .remove(100001)]
        for (sample, operation) in zip(fixture.cases, operations) {
            let runtime = NativeWriteRuntimeContext(common: .init(
                staticValues: sample.staticContext, staticMode: sample.staticMode, dynamicValues: sample.input,
                metadata: .init(packageVersion: nil, experimentHits: nil, experimentMisses: nil)),
                http: .init(userAgent: "FixtureIOSAgent", acceptLanguage: "zh-Hans", clientLogID: 42, timeout: 10,
                            responseState: nil, cookies: .init(networkStatus: 1, wifiKeepAlive: false, cellularKeepAlive: false,
                                                               smallFlow: false, smallFlowValue: nil)),
                multipartBoundary: "unused")
            let request = try NativeFavoriteRequest.make(operation, account: "9", runtime: runtime)
            var components = URLComponents()
            components.percentEncodedQuery = String(data: try #require(request.body), encoding: .utf8)
            let fields = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(fields == sample.expected)
            #expect(request.url.path == sample.path && request.method == .post && request.url.query == nil)
            #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")
            #expect(request.headers["client_logid"] == "42")
        }
    }

    private struct Forms: Decodable { let cases: [Form] }
    private struct Form: Decodable {
        let path: String
        let staticContext: NativeWriteStaticCommonContext
        let staticMode: NativeWriteStaticCommonParameters.Mode
        let input: NativeWriteDynamicCommonContext
        let expected: [String: String]
    }

    @Test func nativeBusinessFieldsAndStrictReceipts() throws {
        let fields = try NativeFavoriteRequest.Operation.save(entry()).business(userID: "9")
        let records = try JSONSerialization.jsonObject(with: Data(try #require(fields["data"]).utf8)) as? [[String: String]]
        #expect(records == [["tid": "100001", "pid": "130001", "status": "1"]])
        #expect(try NativeFavoriteRequest.Operation.list(20).business(userID: "9") == ["rn": "20", "offset": "20", "user_id": "9"])
        #expect(try NativeFavoriteRequest.Operation.remove(100001).business(userID: "9") == ["tid": "100001", "fid": "0"])
        try NativeFavoriteResponse.confirm(response(#"{"error":{"errno":"0"}}"#))
        for json in [#"{}"#, #"{"error_code":true}"#, #"{"error_code":"oops"}"#, #"{"error_code":0,"error":{"errno":"4"}}"#] {
            #expect(throws: (any Error).self) { try NativeFavoriteResponse.confirm(response(json)) }
        }
    }

    @Test func listUsesSavedPostNotLatestPostAndDeletedEntryIsRetained() throws {
        let json = #"""
        {"error_code":0,"store_thread":[
          {"thread_id":"100001","mark_pid":"130001","mark_status":"1","title":"示例","forum_name":"示例吧",
           "max_pid":"990001","post_no":"99","is_deleted":"0"},
          {"thread_id":"100002","mark_pid":"0","mark_status":"1","is_deleted":"1"}
        ]}
        """#
        let page = try NativeFavoriteResponse.page(response(json), offset: 0)
        #expect(page.entries.first?.target.postID == 130001)
        #expect(page.entries.last?.isDeleted == true)
        #expect(page.nextOffset == nil)
        #expect(throws: (any Error).self) { try NativeFavoriteResponse.page(response(#"{"error_code":0}"#), offset: 0) }
    }

    @Test func favoriteFeedKeepsNativeAuthorMediaAndReplyCount() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Favorites/native-ios-feed.json"))
        let page = try NativeFavoriteResponse.page(.init(statusCode: 200, body: data), offset: 0)
        let entry = try #require(page.entries.first)
        let feed = entry.feedSummary
        #expect(entry.target.postID == 130001)
        #expect(feed.threadID == 100001 && feed.title == "收藏帖子示例")
        #expect(feed.authorName == "示例作者" && feed.author?.rawUserID == 23)
        #expect(feed.author?.portrait == "fixture-portrait")
        #expect(feed.replyCount == 42 && feed.mediaCount == 1)
        #expect(feed.thumbnailResources.first?.candidateURLs == ["https://example.com/favorite.jpg"])
        #expect(feed.summary == nil && feed.metadata.agreeCount == nil)
        let missing = try #require(page.entries.last).feedSummary
        #expect(missing.author == nil && missing.mediaCount == 0 && missing.replyCount == 0)
    }

    @Test func confirmedSaveDuplicateRemoveAndRemoteChangesSync() async throws {
        let repository = FavoriteFixtureRepository()
        let store = makeStore(repository)
        await store.refresh()
        await store.save(entry())
        await store.save(entry())
        #expect(store.entries.count == 1 && store.contains(100001))
        await repository.replace([entry(id: 200001)])
        await store.refresh()
        #expect(store.entries.map(\.id) == [200001])
        await repository.setFailure(true)
        await store.remove(200001)
        #expect(store.contains(200001) && store.feedback != nil)
        await repository.setFailure(false)
        await store.remove(200001)
        #expect(store.entries.isEmpty)
    }

    @Test func paginationDeduplicatesAndRefreshRemovesRemoteDeletions() async throws {
        let repository = FavoriteFixtureRepository()
        await repository.replace((1...43).map { entry(id: Int64($0)) })
        let store = makeStore(repository)
        await store.refresh()
        #expect(store.entries.count == 20 && store.hasMore)
        await store.loadMore()
        await store.loadMore()
        #expect(store.entries.count == 43 && !store.hasMore)
        await repository.replace([entry(id: 43)])
        await store.refresh()
        #expect(store.entries.map(\.id) == [43])
    }

    @Test func writingInvalidatesOffsetAndRefreshFailureKeepsSnapshot() async throws {
        let repository = FavoriteFixtureRepository()
        await repository.replace((1...43).map { entry(id: Int64($0)) })
        let store = makeStore(repository)
        await store.refresh()
        await store.remove(5)
        await store.loadMore() // Must restart at offset 0 after the deletion.
        #expect(store.entries.count == 20 && store.entries.last?.id == 21)
        await repository.setFailure(true)
        await store.refresh()
        #expect(store.entries.count == 20 && store.refreshFailed && store.state == .loaded)
        await repository.setFailure(false)
        await store.loadMore()
        await store.loadMore()
        #expect(store.entries.count == 42 && !store.contains(5) && !store.hasMore)
    }

    @Test func uncertainWriteDoesNotRetryOrClaimSuccess() async throws {
        let transport = U10FavoriteTransport()
        let repository = NativeFavoriteRepository { _, _ in try await transport.execute() }
        do {
            try await repository.save(entry(), account: "9")
            Issue.record("A timeout must not become confirmed success")
        } catch { #expect(error as? FavoriteFailure == .outcomeUnknown) }
        #expect(await transport.count == 1)
    }

    @Test(arguments: [false, true], [false, true])
    func cancelledOrChangedAccountCannotPublish(changesAccount: Bool, isWrite: Bool) async throws {
        let repository = U10HeldFavoriteRepository()
        let context = U10FavoriteContext()
        let store = FavoriteStore(repository: repository, context: { context.value }, account: { "9" })
        let task = Task { if isWrite { await store.save(entry()) } else { await store.refresh() } }
        try await repository.started.wait()
        await store.refresh() // Coalesced by the active operation: no second request.
        if changesAccount {
            context.value = .init(namespace: "other", revision: 2)
            store.sessionChanged()
        } else { task.cancel() }
        repository.release.succeed(())
        await task.value
        #expect(store.entries.isEmpty && !store.isBusy && store.feedback == nil)
        #expect(await repository.calls == 1)
    }

    private func makeStore(_ repository: any FavoriteRepositoryProtocol) -> FavoriteStore {
        FavoriteStore(repository: repository, context: { .init(namespace: "fixture", revision: 1) }, account: { "9" })
    }
    private func entry(id: Int64 = 100001) -> ThreadFavorite {
        .init(target: .init(threadID: id, postID: 130001), title: "示例帖子", forumName: "示例吧", status: 1, isDeleted: false)
    }
    private func response(_ json: String) -> HTTPResponse { .init(statusCode: 200, body: Data(json.utf8)) }
}

@MainActor private final class U10FavoriteContext { var value = ContentCacheContext(namespace: "fixture", revision: 1) }

private actor U10HeldFavoriteRepository: FavoriteRepositoryProtocol {
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    var calls = 0
    func page(offset: Int, account: String) async throws -> FavoritePage {
        calls += 1; started.succeed(())
        try await release.wait()
        let value = ThreadFavorite(target: .init(threadID: 1, postID: 2), title: "示例", forumName: "示例吧", status: 1, isDeleted: false)
        return .init(entries: [value], nextOffset: nil)
    }
    func save(_ entry: ThreadFavorite, account: String) async throws {
        calls += 1; started.succeed(()); try await release.wait()
    }
    func remove(_ threadID: Int64, account: String) async throws {}
}

private actor U10FavoriteTransport {
    var count = 0
    func execute() throws -> HTTPResponse { count += 1; throw HTTPClientError.timedOut }
}
