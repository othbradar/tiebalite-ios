import Observation

@MainActor @Observable
final class ExploreFeedStore {
    enum State { case idle, loading, loaded, empty, failed, refreshing, refreshFailure, loadingMore, nextFailure, loginRequired }
    let feed: ExploreFeed
    private(set) var state = State.idle
    private(set) var items: [RecommendationSummary] = []
    private(set) var next: ExploreCursor?
    private(set) var anchor: Int64?
    private(set) var scope: ContentCacheContext?
    private(set) var presentation: RecommendationsListPresentation?
    private let repository: any ExploreFeedRepository
    private let prefetch: ContentPrefetchSession?
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var visited = Set<String>()
    private var requestUnix: UInt64 = 0
    private var pending: PendingRefresh?
    private var blockedUsers = Set<Int64>()
    func setBlockedUsers(_ ids: Set<Int64>) { blockedUsers = ids; updatePresentation() }
    private struct PendingRefresh {
        let page: ExplorePage
        let automatic: Bool
        let generation: UInt64
    }

    init(feed: ExploreFeed, repository: any ExploreFeedRepository, prefetch: ContentPrefetchSession? = nil) {
        self.feed = feed; self.repository = repository; self.prefetch = prefetch
    }

    func reset(scope: ContentCacheContext) {
        deactivate()
        self.scope = scope; items = []; next = nil; anchor = nil; pending = nil; presentation = nil; visited = []
        requestUnix = 0
        state = feed == .following && (scope.namespace == nil || scope.namespace == "anonymous") ? .loginRequired : .idle
    }

    func activate(scope: ContentCacheContext) async {
        if self.scope != scope { reset(scope: scope) }
        guard state == .idle else { return }
        await start(restore: true, automatic: true)
    }

    func refresh(automatic: Bool = false) async {
        guard state != .loginRequired, scope != nil else { return }
        deactivate()
        await start(restore: false, automatic: automatic)
    }

    func loadMore() async {
        guard task == nil, pending == nil, let cursor = next else { return }
        await start(restore: false, automatic: false, cursor: cursor)
    }

    func invalidate() async {
        guard let scope else { return }
        deactivate()
        await repository.invalidate(feed, scope: scope)
        guard self.scope == scope else { return }
        // Keep the current snapshot readable until the next selected-page refresh.
        state = .idle
    }

    func deactivate() {
        task?.cancel(); task = nil; generation &+= 1; prefetch?.cancel(); pending = nil
        if state == .loading || state == .refreshing || state == .loadingMore {
            state = items.isEmpty ? .idle : .loaded
            updatePresentation()
        }
    }

    func setAnchor(_ id: RecommendationsRowID?) {
        guard case let .thread(value) = id, items.contains(where: { $0.threadID == value }) else { return }
        anchor = value
        prefetchNearby()
    }

    func prefetchRows(_ ids: [RecommendationsRowID]) {
        guard ids.contains(where: { id in items.suffix(4).contains { id == .thread($0.threadID) } }),
              task == nil, pending == nil, next != nil else { return }
        Task { await loadMore() }
    }

    var pendingRefreshCommit: VirtualListRefreshCommit<RecommendationsRowModel>? {
        guard let pending else { return nil }
        let token = pending.generation
        return .init { [weak self] viewport in
            guard let self, let pending = self.pending, token == self.generation,
                  case let .settled(atTop) = viewport, !pending.automatic || atTop else { return nil }
            self.pending = nil
            self.apply(pending.page, appending: false)
            return self.presentation?.rows ?? []
        }
    }

    private func start(restore: Bool, automatic: Bool, cursor: ExploreCursor? = nil) async {
        guard task == nil, let scope else { return }
        generation &+= 1
        let token = generation
        state = cursor != nil ? .loadingMore : items.isEmpty ? .loading : .refreshing
        updatePresentation()
        let operation = Task { @MainActor [weak self, repository, feed] in
            guard let self else { return }
            do {
                if restore, let cached = await repository.cached(feed, scope: scope) {
                    guard self.valid(token, scope) else { return }
                    self.apply(cached.page, appending: false)
                    if cached.isFresh { self.task = nil; return }
                }
                let requestedCursor = cursor ?? self.refreshCursor
                let page = try await repository.load(feed, cursor: requestedCursor, scope: scope)
                guard self.valid(token, scope) else { return }
                self.receive(page, cursor: cursor, automatic: automatic, token: token)
            } catch is CancellationError {
                guard self.valid(token, scope, requireRunning: false) else { return }
                self.state = self.items.isEmpty ? .idle : .loaded
                self.updatePresentation()
            } catch {
                guard self.valid(token, scope) else { return }
                self.state = cursor != nil ? .nextFailure : self.items.isEmpty ? .failed : .refreshFailure
                self.updatePresentation()
            }
            if self.generation == token { self.task = nil }
        }
        task = operation
        await operation.value
    }

    private func receive(_ page: ExplorePage, cursor: ExploreCursor?, automatic: Bool, token: UInt64) {
        if let cursor {
            visited.insert(cursor.pageTag)
            apply(page, appending: true)
        } else if !items.isEmpty {
            pending = .init(page: page, automatic: automatic, generation: token)
            state = .loaded
            updatePresentation()
        } else { apply(page, appending: false) }
    }

    private var refreshCursor: ExploreCursor? {
        feed == .following && requestUnix > 0 ? .init(pageTag: "", requestUnix: requestUnix) : nil
    }

    private func valid(_ token: UInt64, _ scope: ContentCacheContext, requireRunning: Bool = true) -> Bool {
        generation == token && self.scope == scope && (!requireRunning || !Task.isCancelled)
    }

    private func apply(_ page: ExplorePage, appending: Bool) {
        if !appending { items = []; visited = []; anchor = nil }
        var seen = Set(items.map(\.threadID))
        items += page.items.filter { $0.threadID > 0 && seen.insert($0.threadID).inserted }
        next = page.next.flatMap { visited.contains($0.pageTag) ? nil : $0 }
        requestUnix = page.requestUnix
        state = items.isEmpty ? .empty : .loaded
        updatePresentation()
        prefetchNearby()
    }

    private func prefetchNearby() {
        let index = items.firstIndex { $0.threadID == anchor } ?? 0
        prefetch?.nearbyThreads(Array(items.dropFirst(index).prefix(2).map(\.threadID)))
    }

    private func updatePresentation() {
        guard !items.isEmpty || pending != nil else { presentation = nil; return }
        let footer: PaginationFooterState = state == .loadingMore ? .loading : state == .nextFailure ? .failure : next == nil ? .end : .idle
        presentation = .init(items: items.filter { !blockedUsers.contains($0.author?.rawUserID ?? 0) }, pagination: footer)
    }
}

enum ExploreTab: String, CaseIterable, Sendable {
    case following, recommendations, hot
    var title: String {
        switch self {
        case .following: "关注"
        case .recommendations: "推荐"
        case .hot: "热榜"
        }
    }
}

@MainActor @Observable
final class ExploreStore {
    var recommendationsVisited = false
    var selected: ExploreTab? = .recommendations
    var selectionGeneration: UInt64 = 0
    let following: ExploreFeedStore
    let hot: ExploreFeedStore
    init(repository: any ExploreFeedRepository, makePrefetch: () -> ContentPrefetchSession? = { nil }) {
        following = .init(feed: .following, repository: repository, prefetch: makePrefetch())
        hot = .init(feed: .hot, repository: repository, prefetch: makePrefetch())
    }
    func select(_ tab: ExploreTab) { selected = tab; selectionGeneration &+= 1 }
}
