import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U04ContentPrefetchTests {
    @Test func prefetchedThreadIsOneRequestAcrossTakeoverCancellationAndReentry() async throws {
        let scheduler = ContentLoadScheduler()
        let source = U04ThreadSource(suspended: true)
        let cache = ContentPageCache(directory: nil)
        let repository = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: cache, scheduler: scheduler)
        let request = ThreadReaderPageRequest.initial(threadID: 140_001)
        let speculative = Task { try await repository.prefetchThread(request) }
        try await source.started.wait()
        let foreground = Task { try await repository.loadPage(request) }
        for _ in 0..<10_000 {
            if await scheduler.diagnostics().merged == 1 { break }
            await Task.yield()
        }
        #expect(await scheduler.diagnostics().merged == 1)
        speculative.cancel()
        source.release.succeed(())
        let page = try await foreground.value
        _ = try? await speculative.value
        #expect(try await repository.loadPage(request) == page)
        #expect(await source.requests.count == 1)
        #expect(await repository.restoreThread(request.threadID)?.position == nil)
        let reopened = ThreadReaderStore(threadID: request.threadID, repository: repository)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot == page)
        #expect(await source.requests.count == 1)
        let counts = await scheduler.diagnostics()
        #expect(counts.speculative == 1 && counts.foreground == 0 && counts.cacheHits >= 1)
    }

    @Test func firstPagePreloadPreservesLaterPagesPositionAndDoesNotUpdateDisplayedList() async throws {
        let source = U04ThreadSource()
        let clock = U04PrefetchClock()
        let repository = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                                 cache: ContentPageCache(directory: nil), clock: clock)
        let store = ThreadReaderStore(threadID: 140_001, repository: repository)
        await store.loadIfNeeded()
        let first = try #require(store.state.snapshot)
        let next = ThreadReaderPageRequest(
            threadID: first.threadID, pageNumber: first.currentPage + 1,
            postID: try #require(first.nextPostID), loadedPostIDs: Set(first.posts.map(\.id.postID)))
        try await repository.prefetchThread(next)
        #expect(store.state.snapshot == first)
        #expect(store.readAnchor == nil)
        await store.loadNextPage()
        #expect(await source.requests.count == 2)
        let anchor = try #require(store.listPresentation?.rows.last(where: { $0.id.isPost })?.id)
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        let before = try #require(await repository.restoreThread(first.threadID))
        await clock.advance(301)
        try await repository.prefetchThread(.initial(threadID: first.threadID))
        let after = try #require(await repository.restoreThread(first.threadID))
        #expect(after.position == before.position && after.position != nil)
        #expect(after.pages.map(\.locator) == before.pages.map(\.locator))
        #expect(store.readAnchor == anchor)
        #expect(await source.requests.count == 3)
    }

    @Test(arguments: [false, true])
    func latePreloadCannotRepopulateAfterAccountChangeOrClear(clear: Bool) async throws {
        let context = U04Context()
        let source = U04ThreadSource(suspended: true)
        let cache = ContentPageCache(directory: nil)
        let repository = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: cache,
                                                 context: { context.value })
        let task = Task { try await repository.prefetchThread(.initial(threadID: 140_001)) }
        try await source.started.wait()
        if clear { await cache.clear() } else { context.value = .init(namespace: "other", revision: 1) }
        source.release.succeed(())
        do { try await task.value; Issue.record("Stale preload was accepted") } catch is CancellationError {}
        #expect(await repository.restoreThread(140_001) == nil)
        context.value = .anonymous
        #expect(await repository.restoreThread(140_001) == nil)
    }

    @Test(arguments: ["account", "clear", "refresh"])
    func lateForumPreloadIsInvalidated(reason: String) async throws {
        let context = U04Context()
        let source = U04ForumSource(suspended: true)
        let cache = ContentPageCache(directory: nil)
        let repository = CachedForumHomeRepository(source: source, cache: cache, context: { context.value })
        let request = ForumHomePageRequest(route: try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发")))
        let task = Task { try await repository.prefetchForum(request) }
        try await source.started.wait()
        switch reason {
        case "account": context.value = .init(namespace: "other", revision: 1)
        case "clear": await cache.clear()
        default: await repository.invalidatePrefetch(request)
        }
        source.release.succeed(())
        do { try await task.value; Issue.record("Invalidated forum preload was accepted") } catch is CancellationError {}
        #expect(await repository.restoreReading(request) == nil)
        _ = try await repository.fetchPage(request, continuing: nil)
        #expect(await source.requests.count == 2)
    }

    @Test func forumPreloadPreservesReadingChainAndSortAndForegroundConsumesPreparedPageOnce() async throws {
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let source = U04ForumSource()
        let clock = U04PrefetchClock()
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: nil), clock: clock)
        let firstRequest = ForumHomePageRequest(route: route)
        let first = try await repository.fetchPage(firstRequest, continuing: nil)
        let secondRequest = ForumHomePageRequest(
            route: route, pageNumber: 2,
            lastThreadID: try #require(first.pages.last?.page.lastThreadID))
        var reading = try await repository.fetchPage(secondRequest, continuing: first)
        reading.anchor = reading.snapshot?.threads.last?.threadID
        await repository.saveReading(reading, request: firstRequest)
        await clock.advance(61)
        try await repository.prefetchForum(firstRequest)
        let retained = try #require(await repository.restoreReading(firstRequest))
        #expect(retained.anchor == reading.anchor && retained.pages.count == 2 && retained.generation == reading.generation)
        #expect(await source.requests.count == 3)
        _ = try await repository.fetchPage(firstRequest, continuing: nil)
        #expect(await source.requests.count == 3)
        // The next reentry still performs U02 automatic revalidation, even with fresh reading data.
        _ = try await repository.fetchPage(firstRequest, continuing: nil)
        #expect(await source.requests.count == 4)
        let creation = ForumHomePageRequest(route: route, query: .latest(.creation))
        try await repository.prefetchForum(creation)
        _ = try await repository.fetchPage(firstRequest, continuing: nil)
        #expect(await source.requests.count == 6)
        _ = try await repository.fetchPage(creation, continuing: nil)
        #expect(await source.requests.count == 6)
    }
}

@MainActor
private final class U04Context { var value = ContentCacheContext.anonymous }

private actor U04PrefetchClock: AppClock {
    var now = Date(timeIntervalSince1970: 1_780_000_000)
    func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
    func sleep(for duration: Duration) async throws { try Task.checkCancellation() }
}

private actor U04ThreadSource: ThreadReaderRepository {
    var requests: [ThreadReaderPageRequest] = []
    let suspended: Bool
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    init(suspended: Bool = false) { self.suspended = suspended }
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        requests.append(request)
        if suspended { started.succeed(()); try await release.wait() }
        return try await FixtureThreadReaderRepository().loadPage(request)
    }
}

private actor U04ForumSource: ForumHomeRepository {
    private var suspended: Bool
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    init(suspended: Bool = false) { self.suspended = suspended }
    var requests: [ForumHomePageRequest] = []
    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        requests.append(request)
        if suspended {
            suspended = false
            started.succeed(())
            try await release.wait()
        }
        return try await R05ForumFixture().loadForumHomePage(request)
    }
}
