import Testing
@testable import TiebaLite

@MainActor
struct RecommendationsListPresentationTests {
    @Test
    func projectionKeepsBusinessIDsOrderAndCompleteNavigationValues() async throws {
        let items = try await FixtureRecommendationRepository().loadPage(.initial).items
        let presentation = RecommendationsListPresentation(items: items, pagination: .idle)
        #expect(presentation.rows.map(\.id) == items.map { .thread($0.threadID) } + [.pagination])
        #expect(presentation.rows.compactMap { row -> RecommendationSummary? in
            guard case let .thread(item) = row.content else { return nil }
            return item
        } == items)
        #expect(presentation.rows.filter(\.isFirstThread).map(\.id) == [.thread(items[0].threadID)])
    }

    @Test
    func appendingAndFooterChangesKeepExistingRowsUnchanged() async throws {
        let repository = FixtureRecommendationRepository()
        let first = try await repository.loadPage(.initial)
        let second = try await repository.loadPage(.init(loadKind: .nextPage, page: 2))
        let before = RecommendationsListPresentation(items: first.items, pagination: .idle)
        for state in [PaginationFooterState.loading, .failure, .end, .idle] {
            let updated = RecommendationsListPresentation(items: first.items, pagination: state)
            #expect(Array(updated.rows.dropLast()) == Array(before.rows.dropLast()))
            #expect(updated.rows.last?.id == .pagination)
            #expect(updated.rows.last?.content == .pagination(state))
        }
        var seen = Set(first.items.map(\.threadID))
        let appended = first.items + second.items.filter { seen.insert($0.threadID).inserted }
        let after = RecommendationsListPresentation(items: appended, pagination: .end)
        #expect(Array(after.rows.prefix(first.items.count)) == Array(before.rows.dropLast()))
        #expect(Set(after.rows.map(\.id)).count == after.rows.count)
    }

    @Test
    func footerMissingAndUnknownRowsCannotReplaceAThreadAnchor() async throws {
        let items = try await FixtureRecommendationRepository().loadPage(.initial).items
        let presentation = RecommendationsListPresentation(items: items, pagination: .end)
        let valid = try #require(items.last?.threadID)
        #expect(presentation.threadAnchor(for: .thread(valid)) == valid)
        #expect(presentation.restoredRowID(for: valid) == .thread(valid))
        for rowID in [nil, .pagination, .thread(-1), .thread(999_999)] as [RecommendationsRowID?] {
            #expect(presentation.threadAnchor(for: rowID) == nil)
        }
        #expect(presentation.restoredRowID(for: nil) == nil)
        #expect(presentation.restoredRowID(for: 999_999) == nil)
    }

    @Test
    func prefetchUsesTailBusinessIDRatherThanCellIndexOrFooter() async throws {
        let store = RecommendationsStore(repository: FixtureRecommendationRepository())
        await store.loadIfNeeded()
        await store.loadNextPage()
        let items = try #require(store.state.items)
        let presentation = RecommendationsListPresentation(items: items, pagination: .idle)
        let first = try #require(items.first?.threadID)
        let last = try #require(items.last?.threadID)
        #expect(presentation.prefetchThreadID(in: [.pagination, .thread(0), .thread(first)]) == nil)
        #expect(presentation.prefetchThreadID(in: [.pagination, .thread(last)]) == last)
        #expect(store.shouldPrefetch(after: last))
        #expect(!store.shouldPrefetch(after: 0))
    }

    @Test
    func repeatedTablePrefetchKeepsOneInFlightPageAndRejectsTheOldTail() async throws {
        let repository = Stage17ControlledRecRepository()
        let store = RecommendationsStore(repository: repository)
        let initialLoad = Task { await store.loadIfNeeded() }
        try await repository.waitForCallCount(1)
        try await repository.succeedLatest()
        await initialLoad.value
        let items = try #require(store.state.items)
        let presentation = RecommendationsListPresentation(items: items, pagination: .idle)
        let threadID = try #require(presentation.prefetchThreadID(in: presentation.rows.map(\.id)))
        for _ in 0..<20 { store.requestNextPage(after: threadID) }
        try await repository.waitForCallCount(2)
        #expect(await repository.callCount() == 2)
        #expect(store.state == .loadingNextPage(items))
        try await repository.succeedLatest()
        for _ in 0..<200 where store.currentPage != 2 { await Task.yield() }
        #expect(store.currentPage == 2)
        #expect(Array(store.state.items?.prefix(items.count) ?? []) == items)
        for _ in 0..<20 { store.requestNextPage(after: threadID) }
        await Task.yield()
        #expect(await repository.callCount() == 2)
    }
}
