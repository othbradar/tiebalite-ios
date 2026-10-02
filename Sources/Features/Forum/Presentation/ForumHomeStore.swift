import Observation

@MainActor
@Observable
final class ForumHomeStore {
    private(set) var route: ForumRoute
    private(set) var state: ForumHomeState = .initialLoading
    private(set) var listPresentation: ForumHomeListPresentation?
    private(set) var scrollAnchor: Int64?
    private(set) var query: ForumThreadQuery
    var selectedPage: ForumPageID? = .latest
    var selectionGeneration: UInt64 = 0
    private(set) var tabStores: [ForumPageID: ForumHomeStore] = [:]
    private var knownForum: ForumSummary?
    private let sortPreferences: (any ForumSortPreferenceProviding)?

    private let repository: any ForumHomeRepository
    @ObservationIgnored private var hasCompletedLoad = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0
    @ObservationIgnored private var cancellationState: ForumHomeState =
        .initialLoading
    @ObservationIgnored private var cancellationPresentation:
        ForumHomeListPresentation?
    @ObservationIgnored private var displayedForumID: Int64?

    init(
        route: ForumRoute,
        repository: any ForumHomeRepository,
        query: ForumThreadQuery? = nil,
        knownForum: ForumSummary? = nil,
        sortPreferences: (any ForumSortPreferenceProviding)? = nil
    ) {
        self.route = route
        self.repository = repository
        self.query = query ?? .latest(sortPreferences?.forumSortPreferences.order(for: route) ?? .lastReply)
        self.sortPreferences = sortPreferences
        self.knownForum = knownForum
    }

    func synchronize(with route: ForumRoute) async {
        if self.route != route {
            tabStores.values.forEach { $0.cancel() }
            tabStores = [:]
            selectedPage = .latest
            knownForum = nil
            query = .latest(sortPreferences?.forumSortPreferences.order(for: route) ?? .lastReply)
            cancelCurrentLoad()
            self.route = route
            state = .initialLoading
            listPresentation = nil
            scrollAnchor = nil
            displayedForumID = nil
            hasCompletedLoad = false
        }

        if let sortPreferences, case .latest = query {
            await sortPreferences.loadIfNeeded()
            guard self.route == route, !Task.isCancelled else { return }
            if let id = route.forumID?.rawValue {
                sortPreferences.associateForumSort(route: route, forumID: id, canonicalName: route.forumName.rawValue)
            }
            let preferred = ForumThreadQuery.latest(preferredLatestSort)
            if query != preferred {
                await applyQuery(preferred)
                return
            }
        }
        guard !hasCompletedLoad,
              activeGeneration == nil else {
            return
        }
        await replaceInitialLoad(previous: nil)
    }

    func reload() async {
        let previous = state.snapshot
        hasCompletedLoad = false
        await replaceInitialLoad(previous: previous)
    }

    func loadNextPage() async {
        guard activeGeneration == nil,
              let previous = state.snapshot,
              previous.hasMore else {
            return
        }
        let nextPage = previous.currentPage + 1
        await replaceNextPageLoad(previous: previous, pageNumber: nextPage)
    }

    func cancel() {
        tabStores.values.forEach { $0.cancel() }
        guard activeGeneration != nil else {
            return
        }
        let restoredState = cancellationState
        let restoredPresentation = cancellationPresentation
        cancelCurrentLoad()
        state = restoredState
        listPresentation = restoredPresentation
        hasCompletedLoad = restoredState.hasCompletedLoad
    }

    func setScrollAnchor(_ rowID: ForumHomeRowID?) {
        guard case let .thread(threadID)? = rowID,
              listPresentation?.threadRows.contains(where: { $0.threadID == threadID }) == true,
              scrollAnchor != threadID else { return }
        scrollAnchor = threadID
    }

    func claimDisplayedForum(_ forumID: Int64) -> Bool {
        guard forumID > 0,
              displayedForumID != forumID else {
            return false
        }
        displayedForumID = forumID
        return true
    }

    var pageIDs: [ForumPageID] {
        [.latest, .good] + (displayedForum?.navigation.categories ?? []).map { .category($0.id) }
    }

    func pageStore(for id: ForumPageID) -> ForumHomeStore? {
        id == .latest ? self : tabStores[id]
    }

    func selectPage(_ id: ForumPageID) {
        guard pageIDs.contains(id), selectedPage != id else { return }
        selectedPage = id
        selectionGeneration &+= 1
    }

    func activateSelectedPage() async {
        guard let id = selectedPage, let page = pageStore(for: id) else { return }
        await page.synchronize(with: route)
    }

    private func applyQuery(_ query: ForumThreadQuery) async {
        guard self.query != query else { return }
        cancelCurrentLoad()
        self.query = query
        scrollAnchor = nil
        state = .initialLoading
        listPresentation = nil
        hasCompletedLoad = false
        await replaceInitialLoad(previous: nil)
    }

    private func configureTabs(_ forum: ForumSummary) {
        guard case .latest = query else { return }
        if tabStores[.good] == nil {
            tabStores[.good] = ForumHomeStore(route: route, repository: repository, query: .good(0), knownForum: forum)
        }
        for category in forum.navigation.categories where tabStores[.category(category.id)] == nil {
            tabStores[.category(category.id)] = ForumHomeStore(
                route: route, repository: repository, query: .category(category, sort: 0), knownForum: forum
            )
        }
    }

    private func replaceInitialLoad(previous: ForumHomeSnapshot?) async {
        beginOperation()
        let generation = nextGeneration
        cancellationState = previous.map(ForumHomeState.loaded)
            ?? .initialLoading
        cancellationPresentation = listPresentation
        state = previous.map(ForumHomeState.refreshing)
            ?? .initialLoading
        listPresentation?.setRetainedStatus(.refreshing)

        let repository = repository
        let request = ForumHomePageRequest(route: route, query: query, knownForum: knownForum)
        let task = Task { @MainActor [weak self] in
            do {
                let snapshot = try await repository.loadForumHomePage(request)
                try Task.checkCancellation()
                self?.finishInitial(
                    generation: generation,
                    previous: previous,
                    result: .success(snapshot)
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finishInitial(
                    generation: generation,
                    previous: previous,
                    result: .failure(.unavailable)
                )
            }
        }
        loadTask = task
        await wait(for: task)
    }

    private func replaceNextPageLoad(
        previous: ForumHomeSnapshot,
        pageNumber: Int
    ) async {
        beginOperation()
        let generation = nextGeneration
        cancellationState = state
        cancellationPresentation = listPresentation
        state = .loadingNextPage(previous)
        listPresentation?.setPagination(.loading)

        let repository = repository
        let request = ForumHomePageRequest(
            route: route,
            pageNumber: pageNumber, query: query,
            lastThreadID: previous.lastThreadID, knownForum: knownForum
        )
        let task = Task { @MainActor [weak self] in
            do {
                let page = try await repository.loadForumHomePage(request)
                try Task.checkCancellation()
                self?.finishNextPage(
                    generation: generation,
                    previous: previous,
                    page: page,
                    failure: nil
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finishNextPage(
                    generation: generation,
                    previous: previous,
                    page: nil,
                    failure: .unavailable
                )
            }
        }
        loadTask = task
        await wait(for: task)
    }

    private func beginOperation() {
        loadTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nextGeneration
    }

    private func wait(for task: Task<Void, Never>) async {
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func finishInitial(
        generation: UInt64,
        previous: ForumHomeSnapshot?,
        result: Result<ForumHomeSnapshot, ForumHomeLoadFailure>
    ) {
        guard activeGeneration == generation else {
            return
        }
        switch result {
        case let .success(snapshot):
            knownForum = snapshot.forum
            if let id = snapshot.forum.forumID {
                sortPreferences?.associateForumSort(route: route, forumID: id, canonicalName: snapshot.forum.name)
            }
            configureTabs(snapshot.forum)
            state = snapshot.threads.isEmpty
                ? .empty(snapshot.forum)
                : .loaded(snapshot)
            listPresentation = ForumHomeListPresentation(
                snapshot: snapshot,
                pagination: snapshot.hasMore ? .idle : .end
            )
        case let .failure(failure):
            if let previous {
                state = .refreshFailure(previous, failure)
                listPresentation = cancellationPresentation
                listPresentation?.setRetainedStatus(.refreshFailure)
            } else {
                state = .initialFailure(failure)
                listPresentation = nil
            }
        }
        hasCompletedLoad = true
        finishOperation(generation: generation)
    }

    private func finishNextPage(
        generation: UInt64,
        previous: ForumHomeSnapshot,
        page: ForumHomeSnapshot?,
        failure: ForumHomeLoadFailure?
    ) {
        guard activeGeneration == generation else {
            return
        }
        if let page {
            let previousCount = previous.threads.count
            let aggregate = previous.appending(page)
            var presentation = cancellationPresentation
                ?? ForumHomeListPresentation(
                    snapshot: previous,
                    pagination: .loading
                )
            presentation.append(
                threads: Array(aggregate.threads.dropFirst(previousCount)),
                pagination: aggregate.hasMore ? .idle : .end
            )
            listPresentation = presentation
            state = .loaded(aggregate)
        } else if let failure {
            state = .nextPageFailure(previous, failure)
            listPresentation = cancellationPresentation
            listPresentation?.setPagination(.failure)
        }
        hasCompletedLoad = true
        finishOperation(generation: generation)
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        state = cancellationState
        listPresentation = cancellationPresentation
        hasCompletedLoad = cancellationState.hasCompletedLoad
        finishOperation(generation: generation)
    }

    private func finishOperation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        loadTask = nil
        cancellationPresentation = nil
    }

    private func cancelCurrentLoad() {
        loadTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nil
        loadTask = nil
        cancellationPresentation = nil
    }
}

extension ForumHomeStore {
    var displayedForum: ForumSummary? { state.displayedForum ?? knownForum }

    private var preferenceRoute: ForumRoute {
        guard let id = knownForum?.forumID,
              let resolved = ForumRoute(forumID: id, forumName: route.forumName.rawValue) else { return route }
        return resolved
    }

    var preferredLatestSort: ForumSortOrder {
        sortPreferences?.forumSortPreferences.order(for: preferenceRoute) ?? {
            if case let .latest(order) = query { return order }
            return .lastReply
        }()
    }

    var hasRememberedSort: Bool {
        sortPreferences?.forumSortPreferences.override(for: preferenceRoute) != nil
    }

    var queryIdentity: ForumQueryIdentity {
        ForumQueryIdentity(route: preferenceRoute, query: query, preferences: sortPreferences?.forumSortPreferences ?? .init())
    }

    func changeQuery(_ query: ForumThreadQuery) async {
        if case let .latest(order) = query {
            sortPreferences?.updateForumSort(order, for: preferenceRoute)
        }
        await applyQuery(query)
    }

    func followGlobalSort() async {
        sortPreferences?.updateForumSort(nil, for: preferenceRoute)
        await applyQuery(.latest(preferredLatestSort))
    }

}

private extension ForumHomeState {
    var hasCompletedLoad: Bool {
        switch self {
        case .empty,
             .initialFailure,
             .loaded,
             .nextPageFailure,
             .refreshFailure:
            true
        case .initialLoading, .loadingNextPage, .refreshing:
            false
        }
    }
}
