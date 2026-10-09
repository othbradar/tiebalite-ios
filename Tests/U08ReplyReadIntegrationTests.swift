import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08ReplyReadIntegrationTests {
    @Test func defaultSwitchAndPageBranchesMatchNativeWithoutChangingReceiptOrUsingFirstPage() throws {
        #expect(NativeReplyPageParameters.enabled(override: nil))
        #expect(!NativeReplyPageParameters.enabled(override: 0))
        let request = ReplyFollowupRequest(receipt: .init(threadID: 101, postID: 430001), entry: .search, page: 3)
        let thread = try NativeReplyPageParameters.fields(request, target: R09WriteFixture.target(.threadReply), requestCount: 8)
        #expect(thread["last_pid"] == "430001" && thread["request_times"] == "10" && thread["pn"] == nil)
        #expect(thread["fr"] == "search_page" && thread["session_request_times"] == "0" && thread["offset"] == "2")
        let signed = try NativeReplyPageParameters.signingFields(thread)
        #expect(signed["ad_param"] == "{\n    \"is_req_ad\" = 0;\n    \"load_count\" = 1;\n    \"refresh_count\" = 0;\n}")
        let floorTarget = R09WriteFixture.target(.floorReply)
        let floor = try NativeReplyPageParameters.fields(request, target: floorTarget, requestCount: 8)
        #expect(floor == ["kz": "101", "last_pid": String(floorTarget.postID), "mark_type": "2"])
    }

    @Test func emptyPageReplyAppearsWithoutPullRefreshAndPersistsWithoutInventingCachePage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U08ReplyPageSource()
        let adapter = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                              cache: .init(directory: directory))
        let http = HarnessMockHTTPClient()
        let store = ThreadReaderStore(threadID: 101, repository: adapter,
                                      replyFollowup: U08ReplyLoader(http: http, nativeResponse: true))
        await store.loadIfNeeded()
        let anchor = try #require(store.listPresentation?.rows.first { $0.id.isPost }?.id)
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        let retained = try #require(store.state.snapshot)
        let task = Task { await store.replySucceeded(.init(threadID: 101, postID: 430001), entry: .forum) }
        try await http.waitForPendingCallCount(1)
        let call = try #require(await http.pendingCalls().first)
        var response = try TiebaNativeWrite_ReplyReadResponse(serializedBytes: U08ReplyReadFixture.bytes())
        response.data.page = Data() // Native successful delta contains an empty page message.
        try await http.succeed(call.id, with: .init(statusCode: 200, body: try response.serializedData()))
        await task.value
        #expect(!store.refreshFailed && store.readAnchor == anchor)
        #expect(store.state.snapshot?.posts.map(\.id.postID) == [10, 430001])
        #expect(store.state.snapshot?.currentPage == retained.currentPage && store.state.snapshot?.hasMore == retained.hasMore)
        #expect(store.state.snapshot?.nextPostID == retained.nextPostID)
        let saved = try #require(await adapter.restoreThread(101))
        #expect(saved.pages.map(\.locator.responsePage) == [1])
        #expect(saved.pages.first?.value.posts.map(\.id.postID) == [10])
        #expect(saved.replyPosts?.posts.map(\.id.postID) == [430001])
        #expect(saved.position?.postID == 10)
        #expect(await source.pages == [1])
        let newAnchor = try #require(store.listPresentation?.rows.last { $0.id.isPost }?.id)
        store.setReadAnchor(newAnchor)
        await store.saveReadingPosition()
        let coldAdapter = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                                  cache: .init(directory: directory))
        let reopened = ThreadReaderStore(threadID: 101, repository: coldAdapter)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot?.posts.map(\.id.postID) == [10, 430001])
        #expect(reopened.readAnchor == newAnchor)
        #expect(await source.pages == [1])
        await reopened.loadNextPage()
        #expect(reopened.state.snapshot?.posts.map(\.id.postID) == [10, 20, 430001])
        #expect(!reopened.refreshFailed)
        let ticket = await coldAdapter.ticket()
        _ = await coldAdapter.mergeReplyPage(try U08ReplyReadFixture.page(3, ids: [430001], hasMore: false), ticket: ticket)
        #expect(await coldAdapter.restoreThread(101)?.replyPosts == nil)
    }

    @Test func newReplyMergesWithoutMovingAnchorAndSurvivesCacheReentry() async throws {
        let source = U08ReplyPageSource()
        let cache = ContentPageCache(directory: nil)
        let adapter = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: cache)
        let http = HarnessMockHTTPClient()
        let store = ThreadReaderStore(threadID: 101, repository: adapter, replyFollowup: U08ReplyLoader(http: http))
        await store.loadIfNeeded()
        let anchor = try #require(store.listPresentation?.rows.last { $0.id.isPost }?.id)
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        let task = Task { await store.replySucceeded(.init(threadID: 101, postID: 11), entry: .forum) }
        try await http.waitForPendingCallCount(1)
        await store.replySucceeded(.init(threadID: 101, postID: 11), entry: .forum)
        let page = try U08ReplyReadFixture.page(1, ids: [10, 11], hasMore: true)
        try await complete(http, page: page)
        await task.value
        #expect(store.state.snapshot?.posts.map(\.id.postID) == [10, 11])
        #expect(store.readAnchor == anchor && !store.refreshFailed)
        #expect(await source.pages == [1])
        let reopened = ThreadReaderStore(threadID: 101, repository: adapter)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot?.posts.map(\.id.postID) == [10, 11])
        #expect(reopened.readAnchor == anchor)
        #expect(await source.pages == [1])
    }

    @Test func distantReplyKeepsMissingPagesLoadableAndDoesNotOverwriteSavedPage() async throws {
        let source = U08ReplyPageSource()
        let adapter = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: .init(directory: nil))
        let http = HarnessMockHTTPClient()
        let store = ThreadReaderStore(threadID: 101, repository: adapter, replyFollowup: U08ReplyLoader(http: http))
        await store.loadIfNeeded()
        let anchor = try #require(store.listPresentation?.rows.first { $0.id.isPost }?.id)
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        let task = Task { await store.replySucceeded(.init(threadID: 101, postID: 30), entry: .search) }
        try await complete(http, page: U08ReplyReadFixture.page(3, ids: [30], hasMore: false))
        await task.value
        #expect(store.state.snapshot?.posts.map(\.id.postID) == [10, 30])
        #expect(store.state.snapshot?.currentPage == 1 && store.state.snapshot?.hasMore == true)
        #expect(await adapter.restoreThread(101)?.position?.postID == 10)
        await store.loadNextPage()
        #expect(store.state.snapshot?.posts.map(\.id.postID) == [10, 20, 30])
        #expect(store.listPresentation?.rows.compactMap { $0.post?.source.postID } == [10, 20, 30])
        await store.loadNextPage()
        #expect(store.state.snapshot?.currentPage == 3 && store.state.snapshot?.hasMore == false)
        #expect(store.state.snapshot?.posts.map(\.id.postID) == [10, 20, 30])
        #expect(store.readAnchor == anchor)
    }

    @Test func cacheClearOrLeavingPageRejectsLateReplyReadWithoutFallbackRequest() async throws {
        for cancel in [false, true] {
            let source = U08ReplyPageSource()
            let cache = ContentPageCache(directory: nil)
            let adapter = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: cache)
            let http = HarnessMockHTTPClient()
            let store = ThreadReaderStore(threadID: 101, repository: adapter, replyFollowup: U08ReplyLoader(http: http))
            await store.loadIfNeeded()
            let task = Task { await store.replySucceeded(.init(threadID: 101, postID: 11), entry: .forum) }
            try await http.waitForPendingCallCount(1)
            if cancel {
                store.cancel()
            } else {
                await cache.clear()
                try await complete(http, page: U08ReplyReadFixture.page(1, ids: [10, 11], hasMore: true))
            }
            await task.value
            #expect(store.state.snapshot?.posts.map(\.id.postID) == [10])
            #expect(await source.pages == [1] && !store.refreshFailed)
            if !cancel { #expect(await adapter.restoreThread(101) == nil) }
        }
    }

    @Test func failedReplyReadRetainsRowsAndDoesNotResendOrReload() async throws {
        let source = U08ReplyPageSource()
        let http = HarnessMockHTTPClient()
        let store = ThreadReaderStore(threadID: 101, repository: source, replyFollowup: U08ReplyLoader(http: http))
        await store.loadIfNeeded()
        let task = Task { await store.replySucceeded(.init(threadID: 101, postID: 11), entry: .forum) }
        try await http.waitForPendingCallCount(1)
        let call = try #require(await http.pendingCalls().first)
        try await http.succeed(call.id, with: .init(statusCode: 503))
        await task.value
        #expect(store.refreshFailed && store.state.snapshot?.posts.map(\.id.postID) == [10])
        #expect(await source.pages == [1])
        #expect(await http.events().count == 2)
    }

    @Test func manualRefreshCancelsReplyReadAndLeavesPaginationUsable() async throws {
        let source = U08ReplyPageSource()
        let http = HarnessMockHTTPClient()
        let store = ThreadReaderStore(threadID: 101, repository: source, replyFollowup: U08ReplyLoader(http: http))
        await store.loadIfNeeded()
        let task = Task { await store.replySucceeded(.init(threadID: 101, postID: 11), entry: .forum) }
        try await http.waitForPendingCallCount(1)
        await store.reload()
        await task.value
        await store.loadNextPage()
        #expect(store.state.snapshot?.posts.map(\.id.postID) == [10, 20])
        #expect(!store.refreshFailed)
        #expect(await http.pendingCalls().isEmpty)
    }

    private func complete(_ http: HarnessMockHTTPClient, page: ThreadReaderSnapshot) async throws {
        try await http.waitForPendingCallCount(1)
        let call = try #require(await http.pendingCalls().first)
        try await http.succeed(call.id, with: .init(statusCode: 200, body: try JSONEncoder().encode(page)))
    }
    @Test func nativeSearchAndContentOriginsAreRepresentable() {
        #expect(ThreadReadingEntry(rawValue: 34) != nil)
        #expect(ThreadReadingEntry(rawValue: 14) != nil)
    }

    @Test func nativeAdPageCountersUseMessageEighteenWithoutAndroidFields() throws {
        let data = try NativeReplyReadProtocol.encode(
            business: ["kz": "101", "last_pid": "430001", "mark_type": "2",
                       "ad_param": #"{"load_count":"2","refresh_count":"1","is_req_ad":0}"#], common: [:])
        // The independently extracted native AdParam descriptor uses int32 fields 1, 2 and 4.
        #expect(data.range(of: Data([0x92, 0x01, 0x06, 0x08, 0x02, 0x10, 0x01, 0x20, 0x00])) != nil)
    }
}
