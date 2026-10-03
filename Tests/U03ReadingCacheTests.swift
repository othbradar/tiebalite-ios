import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U03ReadingCacheTests {
    private let threadID: Int64 = 140_006

    @Test func threePagesRestoreFromDiskWithoutRequestsAndOnlyDisplayWritesProgress() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("u03-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U03ThreadSource()
        let adapter = makeAdapter(source, cache: ContentPageCache(directory: directory))
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        await store.loadNextPage()
        await store.loadNextPage()
        let initialAnchor = try #require(store.listPresentation?.rows.last { $0.id.isPost }?.id)
        store.setInitialReadAnchor(initialAnchor)
        #expect(await adapter.restoreThread(threadID)?.position == nil)
        let retained = try #require(store.state.snapshot)
        let anchor = ThreadReaderRowID.post(threadID: threadID, postID: try #require(retained.posts.last?.id.postID))
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        await store.loadIfNeeded()
        #expect(await source.requests.count == 3)
        let rebuilt = makeAdapter(source, cache: ContentPageCache(directory: directory))
        let reopened = ThreadReaderStore(threadID: threadID, repository: rebuilt)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot == retained)
        #expect(reopened.readAnchor == anchor)
        #expect(await source.requests.count == 3)
        let first = try #require(reopened.listPresentation?.rows.first?.id)
        reopened.setReadAnchor(first)
        await reopened.saveReadingPosition()
        let atTop = ThreadReaderStore(threadID: threadID, repository: rebuilt)
        await atTop.loadIfNeeded()
        #expect(atTop.readAnchor == first)
    }

    @Test func staleCurrentPageRefreshRetainsLaterPagesAndFailureKeepsDiskCopy() async throws {
        let source = U03ThreadSource()
        let clock = U03ReadingClock()
        let adapter = makeAdapter(source, clock: clock)
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        await store.loadNextPage()
        await store.loadNextPage()
        let retained = try #require(store.state.snapshot)
        // An anchor in page 2 must revalidate page 2 while keeping the already read third page.
        let second = try #require(await adapter.restoreThread(threadID)?.pages.first { $0.locator.page == 2 })
        let anchor = ThreadReaderRowID.post(threadID: threadID, postID: try #require(second.value.posts.last?.id.postID))
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        await clock.advance(301)
        await source.setFailure(.transport(.offline))
        let reopened = ThreadReaderStore(threadID: threadID, repository: adapter)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot == retained && reopened.refreshFailed)
        #expect(reopened.readAnchor == anchor)
        #expect(await source.requests.last?.pageNumber == 2)
        #expect(await adapter.restoreThread(threadID)?.pages.count == 3)
        await source.setFailure(nil)
        await reopened.reload()
        #expect(reopened.state.snapshot == retained)
        #expect(!reopened.refreshFailed && reopened.readAnchor == anchor)
        #expect(await source.requests.last?.postID == second.locator.postID)
    }

    @Test func missingMiddlePageRestoresTheReadingRangeWithoutNetworkReplay() async throws {
        let source = U03ThreadSource()
        let cache = ContentPageCache(directory: nil)
        let adapter = makeAdapter(source, cache: cache)
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        await store.loadNextPage()
        await store.loadNextPage()
        let postID = try #require(store.state.snapshot?.posts.last?.id.postID)
        store.setReadAnchor(.post(threadID: threadID, postID: postID))
        await store.saveReadingPosition()
        let data = try #require(await cache.read(key: "anonymous|\(ReadingCacheIdentity(threadID: threadID).key)"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        let missing = try #require(manifest.records.first { $0.locator.page == 2 })
        await cache.remove(key: missing.key)
        let reopened = ThreadReaderStore(threadID: threadID, repository: adapter)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot?.currentPage == 3)
        #expect(reopened.state.snapshot?.hasMore == true)
        #expect(reopened.readAnchor == .post(threadID: threadID, postID: postID))
        #expect(await source.requests.count == 3)
        await source.setFailure(.transport(.offline))
        await reopened.loadNextPage()
        #expect(await source.requests.last?.pageNumber == 4)
        #expect(reopened.state.snapshot?.currentPage == 3)
        if case .nextPageFailure = reopened.state {} else { Issue.record("Missing network page must stay retryable") }
    }

    @Test func threadQueryAndAccountAreIsolatedAndExpiredAccountDropsVisibleRows() async throws {
        let context = U03ReadingContext()
        let source = U03ThreadSource()
        let adapter = makeAdapter(source, context: { context.value })
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        let differentThread = await adapter.restoreThread(threadID + 1)
        let differentQuery: CachedReading<ThreadReaderSnapshot>? = await adapter.restore(
            .init(threadID: threadID, query: "author-descending"))
        #expect(differentThread == nil && differentQuery == nil)
        context.value = .init(namespace: "other", revision: 1)
        #expect(await adapter.restoreThread(threadID) == nil)
        await source.setFailure(.transport(.offline))
        await store.loadIfNeeded()
        #expect(store.state.snapshot == nil)
        context.value = .init(namespace: nil, revision: 2)
        await store.loadIfNeeded()
        #expect(store.state.snapshot == nil)
    }

    @Test(arguments: [false, true])
    func clearOrAccountChangeRejectsLatePagesAndOldCheckpoint(changeAccount: Bool) async throws {
        let source = U03ThreadSource()
        let context = U03ReadingContext()
        let cache = ContentPageCache(directory: nil)
        let adapter = makeAdapter(source, cache: cache, context: { context.value })
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        let oldTicket = await adapter.ticket()
        await source.suspendNext()
        let load = Task { await store.loadNextPage() }
        try await source.started.wait()
        if changeAccount { context.value = .init(namespace: "other", revision: 1) } else { await cache.clear() }
        source.release.succeed(())
        await load.value
        await adapter.checkpoint(.init(identity: .init(threadID: threadID), postID: 1,
                                       locator: .init(page: 0, postID: 0)), ticket: oldTicket)
        #expect(await adapter.restoreThread(threadID) == nil)
        #expect(store.state.snapshot?.currentPage == 1)
    }

    @Test func explicitDeniedResponseEvictsCachedThreadButDoesNotGuessWireCodes() async throws {
        let source = U03ThreadSource()
        let adapter = makeAdapter(source)
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        await source.setFailure(.server(code: 99_999))
        await store.reload()
        #expect(store.state.snapshot != nil)
        #expect(await adapter.restoreThread(threadID) != nil)
        await source.setFailure(.http(statusCode: 403))
        await store.reload()
        #expect(store.state.snapshot == nil)
        #expect(await adapter.restoreThread(threadID) == nil)
    }

    @Test func subpostsPersistTheirParentPagesAndAnchorAcrossRebuildAndRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("u03-sub-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let route = SubpostsRoute(threadID: 8_001, postID: 9_002)
        let adapter = makeAdapter(U03ThreadSource(), cache: ContentPageCache(directory: directory))
        let store = SubpostsStore(route: route, repository: adapter)
        await store.loadIfNeeded()
        await store.loadNextPage()
        store.setReadAnchor(.reply(10_025))
        await store.saveReadingPosition()
        let rebuilt = makeAdapter(U03ThreadSource(), cache: ContentPageCache(directory: directory))
        let reopened = SubpostsStore(route: route, repository: rebuilt)
        await reopened.loadIfNeeded()
        #expect(reopened.snapshot == store.snapshot)
        #expect(reopened.readAnchor == .reply(10_025))
        await reopened.refresh()
        #expect(reopened.snapshot?.items.count == 30 && reopened.snapshot?.pageNumber == 2)
        #expect(reopened.readAnchor == .reply(10_025))
        #expect(await rebuilt.restoreSubposts(.init(threadID: route.threadID, postID: 9_003)) == nil)
        reopened.setReadAnchor(.parent(route.postID))
        await reopened.saveReadingPosition()
        let top = SubpostsStore(route: route, repository: rebuilt)
        await top.loadIfNeeded()
        #expect(top.readAnchor == nil)
    }

    @Test func confirmedDeletedFirstPostCannotKeepPreviouslyCachedFloorsVisible() async throws {
        let source = U03ThreadSource()
        let adapter = makeAdapter(source)
        let store = ThreadReaderStore(threadID: threadID, repository: adapter)
        await store.loadIfNeeded()
        await store.loadNextPage()
        await source.markDeleted()
        store.setReadAnchor(try #require(store.listPresentation?.rows.first?.id))
        await store.reload()
        #expect(store.state.snapshot == nil)
        #expect(await adapter.restoreThread(threadID) == nil)
    }

    private func makeAdapter(_ source: U03ThreadSource, cache: ContentPageCache = ContentPageCache(directory: nil),
                             clock: any AppClock = U03ReadingClock(),
                             context: @escaping @MainActor @Sendable () -> ContentCacheContext = { .anonymous }
    ) -> CachedReadingRepository {
        .init(threads: source, subposts: FixtureSubpostsRepository(), cache: cache, clock: clock, context: context)
    }

    private struct Manifest: Decodable {
        let records: [Record]
    }
    private struct Record: Decodable { let locator: ReadingPageLocator; let key: String }
}

@MainActor
private final class U03ReadingContext {
    var value = ContentCacheContext.anonymous
}

private actor U03ReadingClock: AppClock {
    var now = Date(timeIntervalSince1970: 1_780_000_000)
    func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
    func sleep(for duration: Duration) async throws { try Task.checkCancellation() }
}

private actor U03ThreadSource: ThreadReaderRepository {
    var requests: [ThreadReaderPageRequest] = []
    private var failure: EndpointExecutionError?
    private var suspended = false
    private var deleted = false
    func markDeleted() { deleted = true }
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    func setFailure(_ value: EndpointExecutionError?) { failure = value }
    func suspendNext() { suspended = true }
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        requests.append(request)
        if suspended { started.succeed(()); try await release.wait(); suspended = false }
        if let failure { throw failure }
        let page = try await FixtureThreadReaderRepository().loadPage(request)
        guard deleted, let first = page.posts.first else { return page }
        let unavailable = ThreadReaderPost(floorNumber: 1, author: first.author, metadata: first.metadata,
                                           document: .init(source: first.id, availability: .unavailable(.deletedFirstPost(rawFlag: 1)),
                                                           nodes: [], poll: nil))
        return .init(threadID: page.threadID, title: page.title, forumName: page.forumName, author: page.author,
                     replyCount: page.replyCount, posts: [unavailable], currentPage: page.currentPage)
    }
}
