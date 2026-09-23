import Testing
@testable import TiebaLite

@MainActor
struct R05ForumStoreTests {
    @Test
    func tabsLoadOnlyWhenSelectedAndKeepIndependentPagingAndAnchors() async throws {
        let repository = R05ForumFixture()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let latest = ForumHomeStore(route: route, repository: repository)
        await latest.synchronize(with: route)
        let firstID = try #require(latest.state.snapshot?.threads.last?.threadID)
        latest.setScrollAnchor(.thread(firstID))
        #expect(await repository.recordedRequests().count == 1)
        let good = try #require(latest.pageStore(for: .good))
        #expect(good.listPresentation == nil)
        latest.selectPage(.good)
        await latest.activateSelectedPage()
        await good.loadNextPage()
        good.setScrollAnchor(.thread(firstID + 100))
        #expect(good.state.snapshot?.currentPage == 2)
        #expect(latest.state.snapshot?.currentPage == 1)
        latest.selectPage(.latest)
        await latest.activateSelectedPage()
        #expect(await repository.recordedRequests().count == 3)
        await latest.changeQuery(.latest(.creation))
        #expect(good.state.snapshot?.currentPage == 2)
        #expect(good.scrollAnchor == firstID + 100)
        latest.selectPage(.good)
        await latest.activateSelectedPage()
        #expect(await repository.recordedRequests().count == 4)
        #expect(latest.pageStore(for: .good) === good)
        good.setScrollAnchor(.pagination("fixture"))
        good.setScrollAnchor(.thread(-1))
        #expect(good.scrollAnchor == firstID + 100)
    }

    @Test
    func ordinaryCategoryForwardsRawCursorAndPreservesOtherTabs() async throws {
        let repository = R05ForumFixture()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let store = ForumHomeStore(route: route, repository: repository)
        await store.synchronize(with: route)
        store.selectPage(.category(21))
        await store.activateSelectedPage()
        let page = try #require(store.pageStore(for: .category(21)))
        let cursor = try #require(page.state.snapshot?.lastThreadID)
        await page.loadNextPage()
        let request = try #require(await repository.recordedRequests().last)
        #expect(request.pageNumber == 2)
        #expect(request.lastThreadID == cursor)
        #expect(request.knownForum?.forumID == 13_001)
        #expect(store.state.snapshot?.currentPage == 1)
        #expect(store.pageStore(for: .good)?.listPresentation == nil)
    }

    @Test
    func lateSortResponseAndCancelledSortCannotReplaceTheCurrentList() async throws {
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let fixture = R05ForumFixture()
        let initial = try await fixture.loadForumHomePage(.init(route: route))
        let repository = R05SuspendedSortRepository(snapshot: initial)
        let store = ForumHomeStore(route: route, repository: repository)
        await store.synchronize(with: route)
        let stale = Task { await store.changeQuery(.latest(.creation)) }
        try await repository.started.wait()
        await store.changeQuery(.latest(.lastReply))
        repository.release.succeed(initial)
        await stale.value
        #expect(store.query == .latest(.lastReply))
        #expect(store.state.snapshot == initial)
        #expect(store.listPresentation?.threadRows.map(\.threadID) == initial.threads.map(\.threadID))
    }
}

private actor R05SuspendedSortRepository: ForumHomeRepository {
    let started = HarnessContinuationGate<Void>()
    let release = HarnessContinuationGate<ForumHomeSnapshot>()
    let snapshot: ForumHomeSnapshot

    init(snapshot: ForumHomeSnapshot) { self.snapshot = snapshot }

    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        if request.query == .latest(.creation) {
            started.succeed(())
            return try await release.wait()
        }
        return snapshot
    }
}
