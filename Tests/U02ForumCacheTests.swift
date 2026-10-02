import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U02ForumCacheTests {
    @Test(arguments: [false, true])
    func reentryAutomaticallyShowsNewPostsAtTopEvenWithFreshCache(stale: Bool) async throws {
        let directory = temporaryDirectory("automatic-\(stale)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U02ForumSource()
        let clock = U02CacheClock()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
        let first = ForumHomeStore(route: route, repository: repository)
        await first.synchronize(with: route)
        await source.addNewPost()
        if stale { await clock.advance(61) }
        let reopened = ForumHomeStore(route: route, repository: repository)
        await reopened.synchronize(with: route)
        #expect(reopened.state.snapshot?.threads.first?.threadID == 199_001)
        #expect(reopened.scrollAnchor == nil)
        #expect(await source.count == 2)
        await reopened.synchronize(with: route)
        #expect(await source.count == 2)
        let cached = await repository.restoreReading(.init(route: route))
        #expect(cached?.snapshot?.threads.first?.threadID == 199_001)
    }

    @Test(arguments: [1, 2, 3])
    func returningToTopReplacesOldDiskAnchor(cycle: Int) async throws {
        let directory = temporaryDirectory("top-\(cycle)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U02ForumSource()
        let clock = U02CacheClock()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
        for query in [ForumThreadQuery.latest(.lastReply), .latest(.creation)] {
            let store = ForumHomeStore(route: route, repository: repository, query: query)
            await store.synchronize(with: route)
            await store.loadNextPage()
            let deepAnchor = try #require(store.state.snapshot?.threads.last?.threadID)
            store.setScrollAnchor(.thread(deepAnchor))
            await store.saveReadingPosition()
            // Transient nil or an unrelated row is not evidence that the user reached the top.
            store.setScrollAnchor(nil)
            store.setScrollAnchor(.rule("another-forum"))
            #expect(store.scrollAnchor == deepAnchor)
            let topRow = try #require(store.listPresentation?.rows.first?.id)
            store.setScrollAnchor(topRow)
            #expect(store.scrollAnchor == nil)
            await store.saveReadingPosition()
            let rebuiltRepository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
            let cached = try #require(await rebuiltRepository.restoreReading(.init(route: route, query: query)))
            #expect(cached.anchor == nil)
            #expect(cached.snapshot?.currentPage == 2)
            #expect(cached.snapshot == store.state.snapshot)
            let rebuilt = ForumHomeStore(route: route, repository: rebuiltRepository, query: query)
            await rebuilt.synchronize(with: route)
            #expect(rebuilt.scrollAnchor == nil)
            #expect(rebuilt.state.snapshot?.currentPage == 1)
            #expect(rebuilt.state.snapshot?.threads == cached.pages.first?.page.snapshot.threads)
        }
        #expect(await source.count == 6)
    }

    @Test
    func freshDiskReadingRestoresDeepPagesWhileCheckingOnce() async throws {
        let directory = temporaryDirectory("fresh")
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = U02CacheClock()
        let source = U02ForumSource()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let cache = ContentPageCache(directory: directory)
        let repository = CachedForumHomeRepository(source: source, cache: cache, clock: clock)
        let first = ForumHomeStore(route: route, repository: repository)
        await first.synchronize(with: route)
        await first.loadNextPage()
        let anchor = try #require(first.state.snapshot?.threads.last?.threadID)
        first.setScrollAnchor(.thread(anchor))
        await first.saveReadingPosition()
        let rebuiltRepository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
        let rebuilt = ForumHomeStore(route: route, repository: rebuiltRepository)
        await rebuilt.synchronize(with: route)
        #expect(await source.count == 3)
        #expect(rebuilt.state.snapshot?.currentPage == 2)
        #expect(rebuilt.scrollAnchor == anchor)
        #expect(rebuilt.state.snapshot == first.state.snapshot)
    }

    @Test
    func staleReadingKeepsDeepPagesThenAppliesUpdateWhenScrolledToTop() async throws {
        let directory = temporaryDirectory("stale")
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = U02CacheClock()
        let source = U02ForumSource()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
        let first = ForumHomeStore(route: route, repository: repository)
        await first.synchronize(with: route)
        await first.loadNextPage()
        let previous = first.state.snapshot
        first.setScrollAnchor(.thread(try #require(previous?.threads.last?.threadID)))
        await first.saveReadingPosition()
        await source.addNewPost()
        await clock.advance(61)
        await source.suspendNext()
        let reopened = ForumHomeStore(route: route, repository: repository)
        let load = Task { await reopened.synchronize(with: route) }
        try await source.started.wait()
        #expect(reopened.state.snapshot == previous)
        await reopened.synchronize(with: route)
        #expect(await source.count == 3)
        source.release.succeed(())
        await load.value
        #expect(reopened.state.snapshot == previous)
        reopened.setScrollAnchor(try #require(reopened.listPresentation?.rows.first?.id))
        #expect(reopened.state.snapshot?.currentPage == 1)
        #expect(reopened.state.snapshot?.threads.first?.threadID == 199_001)
        #expect(reopened.scrollAnchor == nil)
        #expect(await source.count == 3)
    }

    @Test
    func failedUpdateKeepsReadableSnapshotAndExplicitRefreshBypassesFreshCache() async throws {
        let directory = temporaryDirectory("failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = U02CacheClock()
        let source = U02ForumSource()
        let route = try #require(ForumRoute("Swift开发"))
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
        let store = ForumHomeStore(route: route, repository: repository)
        await store.synchronize(with: route)
        let previous = store.state.snapshot
        await source.setFailure(true)
        await store.reload()
        #expect(store.state.snapshot == previous)
        #expect(await source.count == 2)
        await clock.advance(61)
        let rebuilt = ForumHomeStore(route: route, repository: repository)
        await rebuilt.synchronize(with: route)
        #expect(rebuilt.state.snapshot == previous)
        #expect(rebuilt.state == .loaded(try #require(previous)))
        #expect(await source.count == 3)
    }

    @Test
    func sortCategoryAccountAndNameAliasUseIndependentKeys() async throws {
        let directory = temporaryDirectory("keys")
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = U02CacheContext()
        let source = U02ForumSource()
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory),
                                                   clock: U02CacheClock(), context: { context.value })
        let name = try #require(ForumRoute("Swift开发"))
        let identified = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let request = ForumHomePageRequest(route: name)
        let first = try await repository.fetchPage(request, continuing: nil)
        await repository.saveReading(first, request: request)
        #expect(await repository.restoreReading(.init(route: identified)) != nil)
        #expect(await repository.restoreReading(.init(route: identified, query: .latest(.creation))) == nil)
        #expect(await repository.restoreReading(.init(route: identified, query: .good(0))) == nil)
        let wrongPage = ForumHomePageRequest(route: name, pageNumber: 2, query: .latest(.creation),
                                             lastThreadID: first.pages.last?.page.lastThreadID ?? 0)
        await #expect(throws: CancellationError.self) { try await repository.fetchPage(wrongPage, continuing: first) }
        context.value = .init(namespace: "account-B", revision: 2)
        #expect(await repository.restoreReading(request) == nil)
        context.value = .init(namespace: nil, revision: 3)
        #expect(await repository.restoreReading(request) == nil)
    }

    @Test
    func clearAndAccountChangeRejectLateResponsesAndCheckpoints() async throws {
        let directory = temporaryDirectory("clear")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U02ForumSource()
        let context = U02CacheContext()
        let cache = ContentPageCache(directory: directory)
        let repository = CachedForumHomeRepository(source: source, cache: cache, clock: U02CacheClock(), context: { context.value })
        let route = try #require(ForumRoute("Swift开发"))
        let request = ForumHomePageRequest(route: route)
        let old = try await repository.fetchPage(request, continuing: nil)
        await repository.saveReading(old, request: request)
        await source.suspendNext()
        let late = Task { try await repository.fetchPage(request, continuing: nil) }
        try await source.started.wait()
        await cache.clear()
        source.release.succeed(())
        await #expect(throws: CancellationError.self) { try await late.value }
        await repository.saveReading(old, request: request)
        #expect(await repository.restoreReading(request) == nil)
        context.value = .init(namespace: "account-B", revision: 2)
        await repository.saveReading(old, request: request)
        #expect(await repository.restoreReading(request) == nil)
    }

    @Test
    func accountNamespaceSurvivesRestoreAndCredentialRotationButNotNewLogin() throws {
        let name = "U02.cache-namespace-test"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let credential = try #require(SessionCredential(bduss: "fx-cache-b", stoken: "fx-cache-s"))
        let auth = SessionAuthContextProvider(cacheNamespaceStore: LocalContentCacheAccountNamespace(defaults: defaults))
        auth.install(credential, restoring: true)
        let original = auth.contentCacheContext
        let restored = SessionAuthContextProvider(cacheNamespaceStore: LocalContentCacheAccountNamespace(defaults: defaults))
        let rotated = try #require(SessionCredential(bduss: "fx-cache-rotated-b", stoken: "fx-cache-rotated-s"))
        restored.install(rotated, restoring: true)
        #expect(restored.contentCacheContext.namespace == original.namespace)
        restored.install(rotated)
        #expect(restored.contentCacheContext.namespace != original.namespace)
        #expect(restored.contentCacheContext.revision > original.revision)
        #expect(restored.expire(context: restored.context()))
        #expect(restored.contentCacheContext.namespace == nil)
        restored.revoke()
        #expect(restored.contentCacheContext.namespace == "anonymous")
    }

    @Test
    func diskBudgetAndExpiryAreBoundedAndCorruptionIsAMiss() async throws {
        let directory = temporaryDirectory("budget")
        defer { try? FileManager.default.removeItem(at: directory) }
        var policy = ContentCachePolicy()
        policy.diskBytes = 100
        policy.maximumEntryBytes = 80
        policy.memoryBytes = 50
        policy.memoryPages = 1
        let cache = ContentPageCache(directory: directory, policy: policy)
        let epoch = await cache.epoch
        await cache.write(Data(repeating: 1, count: 60), key: "first", epoch: epoch)
        await cache.write(Data(repeating: 2, count: 60), key: "second", epoch: epoch)
        #expect(await cache.read(key: "first") == nil)
        #expect(await cache.read(key: "second")?.count == 60)
        let file = directory.appendingPathComponent(ContentPageCache.digest(Data("second".utf8)) + ".cache")
        try Data([0]).write(to: file, options: .atomic)
        let rebuilt = ContentPageCache(directory: directory, policy: policy)
        #expect(await rebuilt.read(key: "second") == nil)
        await cache.clear()
        #expect(await cache.read(key: "second") == nil)
        let source = U02ForumSource()
        let clock = U02CacheClock()
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory), clock: clock)
        let request = ForumHomePageRequest(route: try #require(ForumRoute("Swift开发")))
        let page = try await repository.fetchPage(request, continuing: nil)
        await repository.saveReading(page, request: request)
        await clock.advance(8 * 24 * 60 * 60)
        #expect(await repository.restoreReading(request) == nil)
    }

    private func temporaryDirectory(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("U02-\(name)", isDirectory: true)
    }
}

private actor U02CacheClock: AppClock {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
    func sleep(for duration: Duration) async throws { try Task.checkCancellation() }
}

@MainActor
private final class U02CacheContext {
    var value = ContentCacheContext(namespace: "account-A", revision: 1)
}

private actor U02ForumSource: ForumHomeRepository {
    private(set) var count = 0
    private var fails = false
    private var includesNewPost = false
    private var suspends = false
    let started = HarnessContinuationGate<Void>()
    let release = HarnessContinuationGate<Void>()
    private let fixture = R05ForumFixture()
    func setFailure(_ value: Bool) { fails = value }
    func addNewPost() { includesNewPost = true }
    func suspendNext() { suspends = true }
    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        count += 1
        // A real name-only response resolves a canonical ID; the base fixture only echoes its route.
        let resolved = ForumHomePageRequest(
            route: ForumRoute(forumID: 13_001, forumName: request.route.forumName.rawValue) ?? request.route,
            pageNumber: request.pageNumber, query: request.query, lastThreadID: request.lastThreadID
        )
        let page = try await fixture.loadForumHomePage(resolved)
        if suspends {
            suspends = false
            started.succeed(())
            try await release.wait()
        }
        if fails { throw ForumHomeLoadFailure.unavailable }
        guard includesNewPost, request.pageNumber == 1 else { return page }
        let newPost = ForumThreadSummary(itemID: 199_001, threadID: 199_001, title: "自动刷新的新帖",
                                         forumName: page.forum.name, authorName: "Fixture", replyCount: 0,
                                         viewCount: 0, isPinned: false)
        return ForumHomeSnapshot(forum: page.forum, threads: [newPost] + page.threads,
                                 currentPage: 1, hasMore: page.hasMore, lastThreadID: page.lastThreadID)
    }
}
