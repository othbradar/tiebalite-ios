import Observation

@MainActor
@Observable
final class SearchStore {
    private(set) var state: SearchState = .idle
    private(set) var draftKeyword = ""
    private(set) var submittedKeyword: SearchKeyword?
    private(set) var listPresentation: SearchListPresentation?
    private(set) var scrollAnchor: SearchRowID?

    private let repository: any SearchRepository
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0
    @ObservationIgnored private var cancellationState: SearchState = .idle
    @ObservationIgnored private var cancellationPresentation:
        SearchListPresentation?

    init(repository: any SearchRepository) {
        self.repository = repository
    }

    func setDraftKeyword(_ value: String) {
        draftKeyword = value
    }

    func submit() async {
        guard let keyword = SearchKeyword(draftKeyword) else {
            resetToIdle()
            return
        }
        guard shouldStartSearch(for: keyword) else {
            return
        }
        await replaceSearch(keyword: keyword)
    }

    func retry() async {
        if case let .failed(_, _, retained?) = state {
            await loadNextPage(retaining: retained)
            return
        }
        guard let keyword = submittedKeyword ?? SearchKeyword(draftKeyword) else {
            resetToIdle()
            return
        }
        await replaceSearch(keyword: keyword)
    }

    func loadNextPage() async {
        guard let retained = state.snapshot else {
            return
        }
        await loadNextPage(retaining: retained)
    }

    func setScrollAnchor(_ rowID: SearchRowID?) {
        guard scrollAnchor != rowID else {
            return
        }
        scrollAnchor = rowID
    }

    func cancel() {
        guard activeGeneration != nil else {
            return
        }
        let restoredState = cancellationState
        let restoredPresentation = cancellationPresentation
        cancelCurrentLoad()
        state = restoredState
        listPresentation = restoredPresentation
    }

    private func shouldStartSearch(for keyword: SearchKeyword) -> Bool {
        guard activeGeneration == nil else {
            return keyword != submittedKeyword
        }
        guard keyword == submittedKeyword else {
            return true
        }
        switch state {
        case .failed(_, _, nil):
            return false
        case .empty, .failed, .loaded, .loadingMore, .searching:
            return false
        case .idle:
            return true
        }
    }

    private func replaceSearch(keyword: SearchKeyword) async {
        let changesKeyword = keyword != submittedKeyword
        beginOperation()
        let generation = nextGeneration
        cancellationState = changesKeyword ? .idle : state
        cancellationPresentation = changesKeyword ? nil : listPresentation
        if changesKeyword {
            scrollAnchor = nil
        }
        submittedKeyword = keyword
        draftKeyword = keyword.rawValue
        state = .searching(keyword)
        listPresentation = nil

        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let snapshot = try await repository.search(keyword: keyword)
                try Task.checkCancellation()
                self?.finishSearch(
                    generation: generation,
                    keyword: keyword,
                    result: .success(snapshot)
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finishSearch(
                    generation: generation,
                    keyword: keyword,
                    result: .failure(.unavailable)
                )
            }
        }
        loadTask = task
        await wait(for: task)
    }

    private func loadNextPage(retaining retained: SearchSnapshot) async {
        guard activeGeneration == nil,
              retained.hasMoreThreads,
              retained.keyword == submittedKeyword,
              let request = SearchThreadPageRequest(
                keyword: retained.keyword,
                page: retained.currentThreadPage + 1
              ) else {
            return
        }
        beginOperation()
        let generation = nextGeneration
        cancellationState = state
        cancellationPresentation = listPresentation
        state = .loadingMore(retained)
        listPresentation = SearchListPresentation(
            snapshot: retained,
            pagination: .loading
        )

        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let page = try await repository.loadThreadPage(request)
                try Task.checkCancellation()
                self?.finishNextPage(
                    generation: generation,
                    request: request,
                    retained: retained,
                    result: .success(page)
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
                    request: request,
                    retained: retained,
                    result: .failure(.unavailable)
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

    private func finishSearch(
        generation: UInt64,
        keyword: SearchKeyword,
        result: Result<SearchSnapshot, SearchLoadFailure>
    ) {
        guard activeGeneration == generation,
              submittedKeyword == keyword else {
            return
        }
        switch result {
        case let .success(snapshot):
            let normalized = SearchSnapshot(
                keyword: keyword,
                forums: snapshot.forums,
                threads: snapshot.threads,
                currentThreadPage: snapshot.currentThreadPage,
                hasMoreThreads: snapshot.hasMoreThreads
            )
            if normalized.forums.isEmpty && normalized.threads.isEmpty {
                state = .empty(keyword)
                listPresentation = nil
            } else {
                state = .loaded(normalized)
                listPresentation = SearchListPresentation(
                    snapshot: normalized,
                    pagination: normalized.hasMoreThreads ? .idle : .end
                )
            }
        case let .failure(failure):
            state = .failed(
                keyword: keyword,
                failure: failure,
                retained: nil
            )
            listPresentation = nil
        }
        finishOperation(generation: generation)
    }

    private func finishNextPage(
        generation: UInt64,
        request: SearchThreadPageRequest,
        retained: SearchSnapshot,
        result: Result<ThreadSearchPage, SearchLoadFailure>
    ) {
        guard activeGeneration == generation,
              submittedKeyword == request.keyword else {
            return
        }
        switch result {
        case let .success(page):
            guard page.currentPage == request.page else {
                finishNextPageFailure(
                    generation: generation,
                    retained: retained
                )
                return
            }
            let existingIDs = Set(retained.threads.map(\.threadID))
            let madeProgress = page.items.contains {
                !existingIDs.contains($0.threadID)
            }
            let effectivePage = ThreadSearchPage(
                items: page.items,
                currentPage: page.currentPage,
                hasMore: page.hasMore && madeProgress
            )
            let aggregate = retained.appending(effectivePage)
            state = .loaded(aggregate)
            listPresentation = SearchListPresentation(
                snapshot: aggregate,
                pagination: aggregate.hasMoreThreads ? .idle : .end
            )
            finishOperation(generation: generation)
        case .failure:
            finishNextPageFailure(
                generation: generation,
                retained: retained
            )
        }
    }

    private func finishNextPageFailure(
        generation: UInt64,
        retained: SearchSnapshot
    ) {
        state = .failed(
            keyword: retained.keyword,
            failure: .unavailable,
            retained: retained
        )
        listPresentation = SearchListPresentation(
            snapshot: retained,
            pagination: .failure
        )
        finishOperation(generation: generation)
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        state = cancellationState
        listPresentation = cancellationPresentation
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

    private func resetToIdle() {
        cancelCurrentLoad()
        submittedKeyword = nil
        state = .idle
        listPresentation = nil
        scrollAnchor = nil
    }

    private func cancelCurrentLoad() {
        loadTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nil
        loadTask = nil
        cancellationPresentation = nil
    }
}
