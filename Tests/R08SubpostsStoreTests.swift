import Testing

@testable import TiebaLite

@MainActor
struct R08SubpostsStoreTests {
    private let route = SubpostsRoute(threadID: 8_001, postID: 9_002)

    @Test func appendsDeduplicatedStableRowsAndIgnoresFooterAnchor() async throws {
        let store = SubpostsStore(route: route, repository: FixtureSubpostsRepository())
        await store.loadIfNeeded()
        #expect(store.snapshot?.items.count == 15)
        let original = store.rows.filter { if case .reply = $0.id { true } else { false } }
        store.setReadAnchor(.reply(10_010))
        await store.loadNextPage()
        #expect(store.snapshot?.items.count == 30 && store.snapshot?.hasMore == false)
        #expect(Array(store.rows.filter { if case .reply = $0.id { true } else { false } }.prefix(15)) == original)
        store.setReadAnchor(.footer)
        #expect(store.readAnchor == .reply(10_010))
        let item = try #require(store.snapshot?.items[17])
        #expect(store.replyIntent(for: item)?.subPostID == 10_018)
        #expect(store.replyIntent(for: item)?.route == route)
    }

    @Test func paginationFailureRetainsRowsAndRequiresExplicitRetry() async throws {
        let repository = R08ControlledSubpostsRepository()
        let store = SubpostsStore(route: route, repository: repository)
        let initial = Task { await store.loadIfNeeded() }
        await repository.started.waitValue()
        try await repository.finish(page: 1, route: route)
        await initial.value
        let next = Task { await store.loadNextPage() }
        await repository.started.waitValue()
        await store.loadNextPage()
        #expect(await repository.count == 2)
        await repository.fail()
        await next.value
        #expect(store.phase == .nextPageFailure && store.snapshot?.items.count == 15)
        await store.prefetch([.reply(10_015)])
        #expect(await repository.count == 2)
        let retry = Task { await store.loadNextPage() }
        await repository.started.waitValue()
        try await repository.finish(page: 2, route: route)
        await retry.value
        #expect(store.phase == .loaded && store.snapshot?.items.count == 30)
    }

    @Test func initialFailureCanRetryIntoAnEmptyPageWithItsParent() async throws {
        let repository = R08ControlledSubpostsRepository()
        let store = SubpostsStore(route: route, repository: repository)
        let initial = Task { await store.loadIfNeeded() }
        await repository.started.waitValue()
        await repository.fail()
        await initial.value
        #expect(store.phase == .initialFailure && store.snapshot == nil)
        #expect(store.failure == .transport(.timedOut))
        let retry = Task { await store.refresh() }
        await repository.started.waitValue()
        try await repository.finish(page: 1, route: route, empty: true)
        await retry.value
        #expect(store.phase == .empty && store.snapshot?.parent != nil)
    }

    @Test func cancelRejectsLateResultsAndRefreshKeepsLoadedContent() async throws {
        let repository = R08ControlledSubpostsRepository()
        let store = SubpostsStore(route: route, repository: repository)
        let old = Task { await store.loadIfNeeded() }
        await repository.started.waitValue()
        store.cancel()
        try await repository.finish(page: 1, route: route)
        await old.value
        #expect(store.phase == .idle && store.snapshot == nil)
        let load = Task { await store.loadIfNeeded() }
        await repository.started.waitValue()
        try await repository.finish(page: 1, route: route)
        await load.value
        let refresh = Task { await store.refresh() }
        await repository.started.waitValue()
        #expect(store.phase == .refreshing && store.snapshot?.items.count == 15)
        await repository.fail()
        await refresh.value
        #expect(store.phase == .refreshFailure && store.snapshot?.items.count == 15)
    }
}

private actor R08ControlledSubpostsRepository: SubpostsRepository {
    let started = R08CallSignal()
    var count = 0
    private var pending: CheckedContinuation<SubpostsPage, any Error>?

    func loadPage(route: SubpostsRoute, page: Int) async throws -> SubpostsPage {
        count += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            Task { await started.signal() }
        }
    }

    func finish(page: Int, route: SubpostsRoute, empty: Bool = false) async throws {
        let value = try await FixtureSubpostsRepository().loadPage(route: route, page: page)
        let result =
            empty
            ? SubpostsPage(
                route: value.route, parent: value.parent,
                threadAuthorID: value.threadAuthorID, forumID: value.forumID, forumName: value.forumName,
                items: [], pageNumber: 1, totalPages: 1, totalCount: 0) : value
        pending?.resume(returning: result)
        pending = nil
    }

    func fail() {
        pending?.resume(throwing: EndpointExecutionError.transport(.timedOut))
        pending = nil
    }
}

private actor R08CallSignal {
    private var pendingSignals = 0
    private var waiter: CheckedContinuation<Void, Never>?
    func signal() {
        if let waiter {
            self.waiter = nil
            waiter.resume()
        } else {
            pendingSignals += 1
        }
    }
    func waitValue() async {
        if pendingSignals > 0 {
            pendingSignals -= 1
            return
        }
        await withCheckedContinuation { waiter = $0 }
    }
}
