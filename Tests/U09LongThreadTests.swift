import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U09LongThreadTests {
    @Test func queriesEncodeServerModesAndKeepDefaultIdentity() throws {
        for onlyAuthor in [false, true] {
            for order in ThreadReadingOrder.allCases {
                let query = ThreadReadingQuery(onlyAuthor: onlyAuthor, order: order)
                let wire = try Tieba_PbPage_PbPageRequest(serializedBytes: PBPageProtocol.encodeRequest(
                    .init(threadID: 8001, pageNumber: 4, query: query)))
                #expect(wire.data.lz == (onlyAuthor ? 1 : 0))
                #expect(wire.data.r == order.requestValue)
                #expect(wire.data.pn == 4 && wire.data.pid == 0)
                #expect(wire.data.isCommReverse == 0 && wire.data.floorSortType == 1)
            }
        }
        #expect(ThreadReadingQuery().cacheKey == "all-ascending")
    }

    @Test(arguments: [Int32(0), 2, 5])
    func reverseResponseUsesServerOrderAndReverseCursor(totalPages: Int32) throws {
        var response = Tieba_PbPage_PbPageResponse()
        response.data.thread.id = 8001
        response.data.thread.pids = "9900,9800,9700"
        response.data.page.currentPage = 1
        response.data.page.newTotalPage = totalPages
        response.data.page.hasMore_p = 1
        response.data.firstFloorPost.id = 9001
        response.data.firstFloorPost.floor = 1
        response.data.postList = [91, 90, 89].map { floor in
            var post = Tieba_Post()
            post.id = UInt64(9000 + floor)
            post.floor = UInt32(floor)
            return post
        }
        let request = ThreadReaderPageRequest(threadID: 8001, pageNumber: 0, postID: 0,
                                              query: .init(order: .descending))
        let page = try PBPageProtocol.map(response, request: request)
        #expect(page.currentPage == 1 && page.nextPostID == 9900)
        #expect(page.totalPage == (totalPages > 0 ? Int(totalPages) : nil))
        #expect(page.posts.map(\.floorNumber) == [1, 91, 90, 89])
        response.data.page.currentPage = 4
        response.data.page.newTotalPage = 5
        let jump = ThreadReaderPageRequest(threadID: 8001, pageNumber: 4, postID: 0, query: request.query)
        #expect(try PBPageProtocol.map(response, request: jump).currentPage == 4)
        response.data.page.currentPage = 3
        #expect(throws: PBPageProtocolError.pageIdentityMismatch(requested: 4, received: 3)) {
            try PBPageProtocol.map(response, request: jump)
        }
    }

    @Test func modesHaveIndependentPagesPositionsAndSingleRequestJump() async throws {
        let source = U09Source()
        let cache = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                            cache: ContentPageCache(directory: nil), clock: U09Clock())
        let store = ThreadReaderStore(threadID: 100001, repository: cache)
        await store.loadIfNeeded()
        await store.jumpToPage(4)
        #expect(await source.requests.map(\.pageNumber) == [0, 4])
        let anchor = try #require(store.listPresentation?.rows.first { $0.id.isPost }?.id)
        #expect(store.readAnchor == anchor)
        store.setReadAnchor(anchor)
        await store.saveReadingPosition()
        let onlyAuthor = ThreadReadingQuery(onlyAuthor: true)
        await store.selectQuery(onlyAuthor)
        #expect(store.query == onlyAuthor)
        #expect(store.readAnchor == store.listPresentation?.rows.first { $0.id.isPost }?.id)
        #expect(store.state.snapshot?.posts.allSatisfy { $0.author == store.state.snapshot?.author } == true)
        await store.selectQuery(.init(order: .descending))
        let reversed = try #require(store.state.snapshot?.posts.dropFirst().map(\.floorNumber))
        #expect(reversed == reversed.sorted(by: >))
        await store.selectQuery(.init())
        #expect(store.readAnchor == anchor && store.state.snapshot?.currentPage == 4)
        #expect(await source.requests.count == 4)
        let reopened = ThreadReaderStore(threadID: 100001, repository: cache)
        await reopened.loadIfNeeded()
        #expect(reopened.readAnchor == anchor && reopened.state.snapshot?.currentPage == 4)
        #expect(await cache.readingPosition(.init(threadID: 100001))?.floorNumber == 47)
        #expect(await cache.restoreThread(100001, query: onlyAuthor)?.pages.count == 1)
    }

    @Test func jumpFailureLastPageAndCancellationPreserveExistingReading() async throws {
        let source = U09Source()
        let store = ThreadReaderStore(threadID: 100001, repository: source)
        await store.loadIfNeeded()
        let initial = store.state.snapshot
        await source.setFailure(true)
        await store.jumpToPage(4)
        #expect(store.navigationMessage != nil && store.state.snapshot == initial)
        await source.setFailure(false)
        await source.holdNext()
        let jumping = Task { await store.jumpToPage(4) }
        try await source.started.wait()
        store.cancel()
        source.release.succeed(())
        await jumping.value
        #expect(store.state.snapshot == initial && !store.isNavigating)
        await store.jumpToPage(5)
        #expect(store.state.snapshot?.hasMore == false && store.state.snapshot?.currentPage == 5)
        let count = await source.requests.count
        await store.loadNextPage()
        await store.jumpToPage(6)
        #expect(await source.requests.count == count)
        await store.returnToFirstPost()
        #expect(store.state.snapshot?.posts.first?.floorNumber == 1)
    }

    @Test func messageTargetBeatsSavedPageAndUsesOneDirectLookup() async throws {
        let source = U09Source()
        let cache = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                            cache: ContentPageCache(directory: nil), clock: U09Clock())
        let reader = ThreadReaderStore(threadID: 100001, repository: cache)
        await reader.loadIfNeeded()
        let target = try #require(reader.state.snapshot?.posts.first { $0.floorNumber == 3 }?.id.postID)
        await reader.jumpToPage(4)
        await reader.saveReadingPosition()
        let old = await cache.readingPosition(.init(threadID: 100001))
        let notification = NotificationDestinationStore(target: .init(threadID: 100001, postID: target, isSubpost: false),
                                                        repository: FixtureNotificationTargetRepository(), threads: cache)
        let count = await source.requests.count
        await notification.load()
        #expect(notification.thread?.readAnchor == .post(threadID: 100001, postID: target))
        #expect(await source.requests.count == count + 1)
        #expect(await source.requests.last?.isPostLookup == true)
        #expect(await cache.readingPosition(.init(threadID: 100001)) == old)
        await notification.thread?.loadIfNeeded()
        #expect(await source.requests.count == count + 1)
    }

    @Test(arguments: [false, true])
    func invalidatedNavigationCannotPublishOrRefillCache(changeAccount: Bool) async throws {
        let context = U09Context()
        let bytes = ContentPageCache(directory: nil)
        let source = U09Source()
        let cache = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                            cache: bytes, clock: U09Clock(), context: { context.value })
        let reader = ThreadReaderStore(threadID: 100001, repository: cache)
        await reader.loadIfNeeded()
        let old = reader.state.snapshot
        await source.holdNext()
        let mode = ThreadReadingQuery(onlyAuthor: true)
        let navigation = Task { await reader.selectQuery(mode) }
        try await source.started.wait()
        if changeAccount { context.value = .init(namespace: "other", revision: 1) } else { await bytes.clear() }
        source.release.succeed(())
        await navigation.value
        #expect(reader.query == .init() && reader.state.snapshot == old && !reader.isNavigating)
        #expect(await cache.restoreThread(100001, query: mode) == nil)
    }

    @Test func readingPreferencePreservesExistingSettingsAndRoundTrips() async throws {
        let name = "u09-settings-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        let repository = UserDefaultsAppSettingsRepository(suiteName: name)
        #expect(await repository.load().resumesThreadReading)
        var settings = AppSettingsSnapshot.defaults
        settings.appearance = .dark
        settings.readingTextSize = .large
        try await repository.save(settings)
        #expect(await repository.load() == settings)
        settings.resumeThreadReading = false
        try await repository.save(settings)
        #expect(await repository.load() == settings)
        #expect(await repository.load().resumesThreadReading == false)
    }

    @Test func topPreferenceDoesNotEraseSavedProgressOrOverrideExplicitAnchor() async throws {
        let source = U09Source()
        let cache = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(),
                                            cache: ContentPageCache(directory: nil), clock: U09Clock())
        let reader = ThreadReaderStore(threadID: 100001, repository: cache)
        await reader.loadIfNeeded()
        await reader.jumpToPage(4)
        await reader.saveReadingPosition()
        let position = await cache.readingPosition(.init(threadID: 100001))
        let top = ThreadReaderStore(threadID: 100001, repository: cache, readingPreferences: U09TopPreference())
        await top.loadIfNeeded()
        #expect(top.state.snapshot?.currentPage == 1 && top.readAnchor == nil)
        #expect(await cache.readingPosition(.init(threadID: 100001)) == position)
        let target = try #require(top.listPresentation?.rows.first { $0.post?.floorNumber == 3 }?.id)
        top.setInitialReadAnchor(target)
        await top.loadIfNeeded()
        #expect(top.readAnchor == target)
    }

}

private actor U09Clock: AppClock {
    let now = Date(timeIntervalSince1970: 1780000000)
    func sleep(for duration: Duration) async throws { try Task.checkCancellation() }
}

@MainActor private final class U09Context {
    var value = ContentCacheContext.anonymous
}

@MainActor private final class U09TopPreference: ThreadReadingPreferences {
    let resumesThreadReading = false
}

private actor U09Source: ThreadReaderRepository {
    nonisolated let supportsPostLookup = true
    var requests: [ThreadReaderPageRequest] = []
    private var fails = false
    private var held = false
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    func setFailure(_ value: Bool) { fails = value }
    func holdNext() { held = true }
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        requests.append(request)
        if held { held = false; started.succeed(()); try await release.wait() }
        if fails { throw FixtureReadingRepositoryError.unavailable }
        return try await FixtureThreadReaderRepository().loadPage(request)
    }
}
