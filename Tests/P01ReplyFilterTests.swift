import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct P01ReplyFilterTests {
    @Test func preferencesPersistBothGroupsAndDoNotEraseOtherSettings() async throws {
        let name = "p01-reply-filter-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        let repository = UserDefaultsAppSettingsRepository(suiteName: name)
        let settings = SettingsStore(repository: repository)
        await settings.loadIfNeeded()
        #expect(settings.replyQuery == .init())
        settings.setAppearance(.dark)
        settings.setReplyQuery(.init(onlyAuthor: true, order: .hot))
        await settings.waitForPendingSave()
        let relaunched = SettingsStore(repository: UserDefaultsAppSettingsRepository(suiteName: name))
        await relaunched.loadIfNeeded()
        #expect(relaunched.replyQuery == .init(onlyAuthor: true, order: .hot))
        #expect(relaunched.appearance == .dark)
        let first = ThreadReaderStore(threadID: 100001, repository: FixtureThreadReaderRepository())
        let second = ThreadReaderStore(threadID: 100002, repository: FixtureThreadReaderRepository())
        for reader in [first, second] {
            await reader.applyReplyPreferences(relaunched)
            await reader.loadIfNeeded()
            #expect(reader.query == relaunched.replyQuery)
        }
        await second.selectReplyQuery(.init(order: .descending), preferences: relaunched)
        await first.applyReplyPreferences(relaunched)
        #expect(first.query == .init(order: .descending))
        await first.returnToFirstPost()
        #expect(first.query == .init(order: .descending))
    }

    @Test func failureAndCancellationKeepSelectionContentAndPreference() async throws {
        let settings = SettingsStore(repository: InMemoryAppSettingsRepository())
        await settings.loadIfNeeded()
        let source = FilterSource()
        let reader = ThreadReaderStore(threadID: 100001, repository: source)
        await reader.loadIfNeeded()
        let before = reader.state.snapshot
        await source.setFailure(true)
        await reader.selectReplyQuery(.init(onlyAuthor: true, order: .hot), preferences: settings)
        #expect(reader.state.snapshot == before && reader.query == .init() && settings.replyQuery == .init())
        await source.setFailure(false)
        await source.holdNext()
        let task = Task { await reader.selectReplyQuery(.init(order: .descending), preferences: settings) }
        try await source.started.wait()
        reader.cancel()
        source.release.succeed(())
        await task.value
        #expect(reader.state.snapshot == before && reader.query == .init() && settings.replyQuery == .init())
    }

    @Test func hotModeKeepsServerRankUsesPageCursorAndSeparateCacheIdentity() throws {
        #expect(ThreadReadingOrder.hot.requestValue == 2)
        let initial = try Tieba_PbPage_PbPageRequest(serializedBytes: PBPageProtocol.encodeRequest(
            .init(threadID: 100001, query: .init(order: .hot))))
        #expect(initial.data.r == 2 && initial.data.pn == 1 && initial.data.pid == 0)
        let next = try Tieba_PbPage_PbPageRequest(serializedBytes: PBPageProtocol.encodeRequest(
            .init(threadID: 100001, pageNumber: 2, query: .init(onlyAuthor: true, order: .hot))))
        #expect(next.data.r == 2 && next.data.pn == 2 && next.data.pid == 0 && next.data.lz == 1)
        #expect(Set([false, true].flatMap { author in
            ThreadReadingOrder.allCases.map { ThreadReadingQuery(onlyAuthor: author, order: $0).cacheKey }
        }).count == 6)
        var response = Tieba_PbPage_PbPageResponse()
        response.data.thread.id = 100001
        response.data.thread.pids = "300,400,500"
        response.data.firstFloorPost.id = 100
        response.data.firstFloorPost.floor = 1
        response.data.page.currentPage = 1
        response.data.page.hasMore_p = 1
        response.data.postList = [9, 3, 7].map { floor in
            var post = Tieba_Post()
            post.floor = UInt32(floor)
            post.id = UInt64(100 + floor)
            return post
        }
        let snapshot = try PBPageProtocol.map(response, request: .init(threadID: 100001, pageNumber: 0, postID: 0,
                                                                       query: .init(order: .hot)))
        #expect(snapshot.posts.map(\.floorNumber) == [1, 9, 3, 7])
        #expect(snapshot.nextPostID == 0)
        let presentation = ThreadReaderListPresentation(snapshot: snapshot, pagination: .loadMore(nextPage: 2))
        #expect(presentation.rows[1].id == .header(threadID: 100001))
    }
}

private actor FilterSource: ThreadReaderRepository {
    private var fails = false
    private var held = false
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    func setFailure(_ value: Bool) { fails = value }
    func holdNext() { held = true }
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        if held { held = false; started.succeed(()); try await release.wait() }
        if fails { throw FixtureReadingRepositoryError.unavailable }
        return try await FixtureThreadReaderRepository().loadPage(request)
    }
}
