import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct NotificationThreadContextTests {
    @Test(arguments: [0, 1, 2])
    func locatingOneReplyDoesNotReplaceTheCachedWholePage(attempt: Int) async throws {
        _ = attempt
        let source = NotificationWindowSource()
        let cache = adapter(source)
        let first = try await cache.loadPage(.initial(threadID: 8_001))
        let window = try await cache.loadPage(.init(threadID: 8_001, pageNumber: 0, postID: 9_001))
        #expect(window.posts.map(\.id.postID) == [9_001])
        let restored = try #require(await cache.restoreThread(8_001))
        #expect(restored.pages.first?.value == first)
        #expect(restored.position == nil)
    }

    @Test(arguments: [false, true])
    func replyNotificationAndReopenedThreadKeepFirstAndAdjacentFloors(warm: Bool) async throws {
        let source = NotificationWindowSource()
        let cache = adapter(source)
        if warm { _ = try await cache.loadPage(.initial(threadID: 8_001)) }
        let destination = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_001, isSubpost: false),
                                                       repository: FixtureNotificationTargetRepository(), threads: cache)
        await destination.load()
        let reader = try #require(destination.thread)
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: 9_001))
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == Array(1...15))
        #expect(await cache.readingPosition(.init(threadID: 8_001)) == nil)
        await reader.saveReadingPosition()
        destination.cancel()
        let reopened = ThreadReaderStore(threadID: 8_001, repository: cache)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot?.posts.map(\.floorNumber) == Array(1...15))
        #expect(reopened.readAnchor == .post(threadID: 8_001, postID: 9_001))
        await reopened.loadNextPage()
        #expect(reopened.state.snapshot?.posts.map(\.floorNumber) == Array(1...28))
    }

    @Test func laterReplyLoadsItsWholePageWithoutWalkingEveryEarlierPage() async throws {
        let source = NotificationWindowSource()
        let cache = adapter(source)
        let destination = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_018, isSubpost: false),
                                                       repository: FixtureNotificationTargetRepository(), threads: cache)
        await destination.load()
        let reader = try #require(destination.thread)
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == Array(16...28))
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: 9_018))
        #expect(await source.requests.map(\.pageNumber) == [0, 2])
        #expect(await source.requests.map(\.postID) == [9_018, 0])
        await reader.loadNextPage()
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == Array(16...35))
        await reader.returnToFirstPost()
        #expect(reader.state.snapshot?.posts.first?.floorNumber == 1)
    }

    @Test func failedWholePageDoesNotPublishOrPersistTheReplyWindow() async throws {
        let source = NotificationWindowSource()
        let cache = adapter(source)
        await source.failNormalPages()
        let destination = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_001, isSubpost: false),
                                                       repository: FixtureNotificationTargetRepository(), threads: cache)
        await destination.load()
        #expect(destination.failed && destination.thread == nil)
        #expect(await cache.restoreThread(8_001) == nil)
    }

    @Test func newReplyRefreshesAnOlderWholePageThatDoesNotYetContainIt() async throws {
        let source = NotificationWindowSource()
        let cache = adapter(source)
        await source.omitTargetFromNormalPages(true)
        _ = try await cache.loadPage(.initial(threadID: 8_001))
        await source.omitTargetFromNormalPages(false)
        let reader = ThreadReaderStore(threadID: 8_001, repository: cache)
        await reader.locatePost(9_001)
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == Array(1...15))
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: 9_001))
        #expect(await source.requests.map(\.postID) == [0, 9_001, 0])
    }

    @Test func missingTargetInAuthoritativePageDoesNotOpenTheWrongFloor() async {
        let source = NotificationWindowSource()
        await source.omitTargetFromNormalPages(true)
        let destination = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_001, isSubpost: false),
                                                       repository: FixtureNotificationTargetRepository(), threads: adapter(source))
        await destination.load()
        #expect(destination.failed && destination.thread == nil)
    }

    @Test(arguments: [Int64(9_001), 9_018])
    func oldPersistedWindowRecoversWithoutLosingSavedPosition(postID: Int64) async throws {
        let source = NotificationWindowSource()
        let cache = try await legacyAdapter(source, postID: postID)
        let reader = ThreadReaderStore(threadID: 8_001, repository: cache)
        await reader.loadIfNeeded()
        let floors = postID == 9_001 ? Array(1...15) : Array(16...28)
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == floors)
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: postID))
        // Reopen before any new viewport checkpoint: migration must retain existing progress.
        let reopened = ThreadReaderStore(threadID: 8_001, repository: cache)
        await reopened.loadIfNeeded()
        #expect(reopened.state.snapshot == reader.state.snapshot)
        #expect(reopened.readAnchor == reader.readAnchor)
        #expect(await source.requests.count == 1)
        #expect(await source.requests.first?.postID == 0)
        await reopened.loadNextPage()
        #expect(reopened.state.snapshot?.posts.count == (postID == 9_001 ? 28 : 20))
    }

    @Test func oldWindowOfflineRepairKeepsContentAndExplicitRetryLoadsWholePage() async throws {
        let source = NotificationWindowSource()
        let cache = try await legacyAdapter(source)
        await source.failNormalPages()
        let reader = ThreadReaderStore(threadID: 8_001, repository: cache)
        await reader.loadIfNeeded()
        #expect(reader.refreshFailed && reader.state.snapshot?.posts.map(\.id.postID) == [9_001])
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: 9_001))
        await source.failNormalPages(false)
        await reader.reload()
        #expect(!reader.refreshFailed && reader.state.snapshot?.posts.map(\.floorNumber) == Array(1...15))
        #expect(await source.requests.map(\.postID) == [0, 0])
    }

    @Test func cancelledOldWindowRepairResumesWhenTheSameReaderReappears() async throws {
        let source = NotificationWindowSource()
        let cache = try await legacyAdapter(source)
        await source.holdNextNormalPage()
        let reader = ThreadReaderStore(threadID: 8_001, repository: cache)
        let loading = Task { await reader.loadIfNeeded() }
        try await source.started.wait()
        reader.cancel()
        source.release.succeed(())
        await loading.value
        #expect(reader.state.snapshot?.posts.map(\.id.postID) == [9_001])
        await reader.loadIfNeeded()
        #expect(reader.state.snapshot?.posts.map(\.floorNumber) == Array(1...15))
        #expect(reader.readAnchor == .post(threadID: 8_001, postID: 9_001))
    }

    @Test func cancellingNotificationDuringWholePageLoadCannotPublishItsReplyWindow() async throws {
        let source = NotificationWindowSource()
        await source.holdNextNormalPage()
        let cache = adapter(source)
        let destination = NotificationDestinationStore(target: .init(threadID: 8_001, postID: 9_001, isSubpost: false),
                                                       repository: FixtureNotificationTargetRepository(), threads: cache)
        let loading = Task { await destination.load() }
        try await source.started.wait()
        destination.cancel()
        source.release.succeed(())
        await loading.value
        #expect(destination.thread == nil && !destination.failed)
        #expect(await cache.restoreThread(8_001) == nil)
    }

    private func legacyAdapter(_ source: NotificationWindowSource, postID: Int64 = 9_001) async throws -> CachedReadingRepository {
        let storage = ContentPageCache(directory: nil)
        let page = try FixtureNotificationThreadPages.load(.init(threadID: 8_001, pageNumber: 0, postID: postID))
        let window = ReplyPageMerge.snapshot(metadata: page, pagination: page, posts: page.posts.filter { $0.id.postID == postID })
        let locator = ReadingPageLocator(page: page.currentPage, postID: postID)
        let now = await NotificationContextClock().now
        let record = CachedReadingPage(locator: locator, fetchedAt: now, value: window, hasKnownPageOrigin: nil)
        let identity = ReadingCacheIdentity(threadID: 8_001)
        let key = "anonymous|\(identity.key)"
        let pageKey = "\(key)|legacy-window"
        let manifest = LegacyManifest(records: [.init(locator: locator, key: pageKey, fetchedAt: now)],
                                      position: .init(identity: identity, postID: postID, locator: locator))
        let epoch = await storage.epoch
        #expect(await storage.write(try JSONEncoder().encode(record), key: pageKey, epoch: epoch))
        #expect(await storage.write(try JSONEncoder().encode(manifest), key: key, epoch: epoch))
        return .init(threads: source, subposts: FixtureSubpostsRepository(), cache: storage, clock: NotificationContextClock())
    }

    private func adapter(_ source: NotificationWindowSource) -> CachedReadingRepository {
        .init(threads: source, subposts: FixtureSubpostsRepository(), cache: ContentPageCache(directory: nil),
              clock: NotificationContextClock())
    }

    private struct LegacyRecord: Encodable {
        let locator: ReadingPageLocator
        let key: String
        let fetchedAt: Date
    }

    private struct LegacyManifest: Encodable {
        let records: [LegacyRecord]
        let position: ReadingPosition
    }
}

private actor NotificationWindowSource: ThreadReaderRepository {
    nonisolated let supportsPostLookup = true
    var requests: [ThreadReaderPageRequest] = []
    private var normalPagesFail = false
    private var omitTarget = false
    private var holdNext = false
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    func failNormalPages(_ enabled: Bool = true) { normalPagesFail = enabled }
    func omitTargetFromNormalPages(_ enabled: Bool) { omitTarget = enabled }
    func holdNextNormalPage() { holdNext = true }

    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        requests.append(request)
        try Task.checkCancellation()
        if !request.isPostLookup, holdNext {
            holdNext = false
            started.succeed(())
            try await withTaskCancellationHandler { try await release.wait() } onCancel: { release.cancel() }
            try Task.checkCancellation()
        }
        if normalPagesFail && !request.isPostLookup { throw HTTPClientError.offline }
        let page = try FixtureNotificationThreadPages.load(request)
        if !request.isPostLookup, omitTarget {
            return ReplyPageMerge.snapshot(metadata: page, pagination: page, posts: page.posts.filter { $0.id.postID != 9_001 })
        }
        guard request.isPostLookup else { return page }
        // A PID response can be a window even when current_page is a normal page number.
        return ReplyPageMerge.snapshot(metadata: page, pagination: page,
                                       posts: page.posts.filter { $0.id.postID == request.postID })
    }
}

private struct NotificationContextClock: AppClock {
    var now: Date { get async { Date(timeIntervalSince1970: 1_780_000_000) } }
    func sleep(for duration: Duration) async throws { try Task.checkCancellation() }
}
