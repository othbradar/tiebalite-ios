import Observation

@MainActor
@Observable
final class SearchStore {
    let scope: SearchScope
    private(set) var selectedType: SearchResultType = .threads
    private(set) var selectedForumMode: ForumSearchMode = .topics
    private(set) var selectedSort: SearchSort = .newest
    private(set) var draftKeyword = ""
    private(set) var submittedKeyword: SearchKeyword?
    private var entries: [SearchEntryKey: SearchEntry] = [:]

    var state: SearchState { entry.state }
    var listPresentation: SearchListPresentation? { entry.presentation }
    var scrollAnchor: SearchRowID? { entry.anchor }
    var query: SearchQuery? {
        submittedKeyword.flatMap {
            SearchQuery(scope: scope, type: selectedType, keyword: $0, sort: selectedSort, forumMode: selectedForumMode)
        }
    }

    private var entryKey: SearchEntryKey {
        SearchEntryKey(type: selectedType, sort: selectedType == .threads ? selectedSort : .newest, forumMode: selectedForumMode)
    }
    private var entry: SearchEntry { entries[entryKey] ?? SearchEntry() }
    private let repository: any SearchRepository
    private let historyRepository: any SearchHistoryRepository
    private(set) var searchHistory: [String] = []
    private var historyGeneration: UInt64 = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0
    @ObservationIgnored private var cancellationEntry = SearchEntry()

    init(repository: any SearchRepository, scope: SearchScope = .global,
         historyRepository: any SearchHistoryRepository = LocalSearchHistoryRepository()) {
        self.repository = repository
        self.scope = scope
        self.historyRepository = historyRepository
    }

    func makeScopedStore(_ scope: SearchScope) -> SearchStore {
        SearchStore(repository: repository, scope: scope, historyRepository: historyRepository)
    }

    func setDraftKeyword(_ value: String) {
        draftKeyword = value
        if value.isEmpty, scope != .global {
            cancel()
            submittedKeyword = nil
            entries = [:]
        }
    }

    func loadHistory() async {
        let generation = historyGeneration
        let history = await historyRepository.load()
        guard generation == historyGeneration else { return }
        searchHistory = history
    }

    func clearHistory() async {
        historyGeneration &+= 1
        searchHistory = await historyRepository.clear()
    }

    private func recordHistory(_ keyword: SearchKeyword) async {
        guard case .forum = scope else { return }
        historyGeneration &+= 1
        let generation = historyGeneration
        let history = await historyRepository.record(keyword)
        guard generation == historyGeneration else { return }
        searchHistory = history
    }

    func submit() async {
        guard let keyword = SearchKeyword(draftKeyword) else {
            cancel()
            submittedKeyword = nil
            entries = [:]
            return
        }
        if keyword != submittedKeyword {
            cancel()
            entries = [:]
            submittedKeyword = keyword
            draftKeyword = keyword.rawValue
        }
        await recordHistory(keyword)
        guard submittedKeyword == keyword, state == .idle, activeGeneration == nil, let query else { return }
        await replaceSearch(query)
    }

    func selectType(_ type: SearchResultType) async {
        guard type != selectedType, scope == .global || type == .threads else { return }
        cancel()
        selectedType = type
        guard state == .idle, let query else { return }
        await replaceSearch(query)
    }

    func selectForumMode(_ mode: ForumSearchMode) async {
        guard case .forum = scope, mode != selectedForumMode else { return }
        cancel()
        selectedForumMode = mode
        guard state == .idle, let query else { return }
        await replaceSearch(query)
    }

    func selectSort(_ sort: SearchSort) async {
        guard selectedType == .threads, sort != selectedSort, scope == .global || sort != .oldest else { return }
        cancel()
        selectedSort = sort
        guard state == .idle, let query else { return }
        await replaceSearch(query)
    }

    func retry() async {
        guard activeGeneration == nil else { return }
        if case let .failed(_, _, retained?) = state {
            await loadNextPage(retaining: retained)
        } else if case .failed = state, let query {
            await replaceSearch(query)
        } else if state == .idle {
            await submit()
        }
    }

    func loadNextPage() async {
        guard selectedType == .threads, let retained = state.snapshot else { return }
        await loadNextPage(retaining: retained)
    }

    func setScrollAnchor(_ rowID: SearchRowID?) {
        guard let query else { return }
        setScrollAnchor(rowID, for: query)
    }

    /// A callback from a departing hosted list cannot overwrite the newly selected type's position.
    func setScrollAnchor(_ rowID: SearchRowID?, for source: SearchQuery) {
        guard source == query, let presentation = listPresentation,
              rowID == nil || presentation.rows.contains(where: { $0.id == rowID }) else { return }
        entries[entryKey, default: SearchEntry()].anchor = rowID
    }

    func cancel() {
        guard activeGeneration != nil else { return }
        loadTask?.cancel()
        entries[entryKey] = cancellationEntry
        nextGeneration &+= 1
        activeGeneration = nil
        loadTask = nil
    }

    private func beginOperation() -> UInt64 {
        cancellationEntry = entry
        nextGeneration &+= 1
        activeGeneration = nextGeneration
        return nextGeneration
    }

    private func replaceSearch(_ query: SearchQuery) async {
        let generation = beginOperation()
        publish(.searching(query.keyword), presentation: nil)
        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let snapshot = try await repository.search(query)
                try Task.checkCancellation()
                guard snapshot.query == query else { throw SearchLoadFailure.unavailable }
                self?.finishSearch(generation: generation, query: query, result: .success(snapshot))
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finishSearch(generation: generation, query: query, result: .failure(.unavailable))
            }
        }
        loadTask = task
        await wait(for: task)
    }

    private func loadNextPage(retaining retained: SearchSnapshot) async {
        guard activeGeneration == nil, retained.hasMoreThreads, retained.query == query,
              let request = SearchThreadPageRequest(query: retained.query, page: retained.currentThreadPage + 1) else {
            return
        }
        let generation = beginOperation()
        publish(.loadingMore(retained), presentation: SearchListPresentation(snapshot: retained, pagination: .loading))
        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let page = try await repository.loadThreadPage(request)
                try Task.checkCancellation()
                self?.finishNextPage(generation: generation, request: request, retained: retained, result: .success(page))
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finishNextPage(generation: generation, request: request, retained: retained,
                                     result: .failure(.unavailable))
            }
        }
        loadTask = task
        await wait(for: task)
    }

    private func wait(for task: Task<Void, Never>) async {
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    private func finishSearch(generation: UInt64, query: SearchQuery, result: Result<SearchSnapshot, SearchLoadFailure>) {
        guard activeGeneration == generation, self.query == query else { return }
        switch result {
        case let .success(snapshot):
            if snapshot.forums.isEmpty && snapshot.threads.isEmpty && snapshot.users.isEmpty {
                publish(.empty(query.keyword), presentation: nil)
            } else {
                publish(.loaded(snapshot), presentation: SearchListPresentation(
                    snapshot: snapshot, pagination: snapshot.hasMoreThreads ? .idle : .end))
            }
        case let .failure(failure):
            publish(.failed(keyword: query.keyword, failure: failure, retained: nil), presentation: nil)
        }
        finishOperation(generation: generation)
    }

    private func finishNextPage(generation: UInt64, request: SearchThreadPageRequest,
                                retained: SearchSnapshot, result: Result<ThreadSearchPage, SearchLoadFailure>) {
        guard activeGeneration == generation, query == request.query else { return }
        switch result {
        case let .success(page) where page.currentPage == request.page:
            let existingIDs = Set(retained.threads.map(\.id))
            let madeProgress = page.items.contains { !existingIDs.contains($0.id) }
            let effectivePage = ThreadSearchPage(items: page.items, currentPage: page.currentPage,
                                                 hasMore: page.hasMore && madeProgress)
            let aggregate = retained.appending(effectivePage)
            publish(.loaded(aggregate), presentation: SearchListPresentation(
                snapshot: aggregate, pagination: aggregate.hasMoreThreads ? .idle : .end))
        default:
            publish(.failed(keyword: retained.keyword, failure: .unavailable, retained: retained),
                    presentation: SearchListPresentation(snapshot: retained, pagination: .failure))
        }
        finishOperation(generation: generation)
    }

    private func publish(_ state: SearchState, presentation: SearchListPresentation?) {
        entries[entryKey, default: SearchEntry()].state = state
        entries[entryKey, default: SearchEntry()].presentation = presentation
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else { return }
        entries[entryKey] = cancellationEntry
        finishOperation(generation: generation)
    }

    private func finishOperation(generation: UInt64) {
        guard activeGeneration == generation else { return }
        activeGeneration = nil
        loadTask = nil
    }
}

private struct SearchEntryKey: Hashable {
    let type: SearchResultType
    let sort: SearchSort
    let forumMode: ForumSearchMode
}

private struct SearchEntry {
    var state: SearchState = .idle
    var presentation: SearchListPresentation?
    var anchor: SearchRowID?
}
