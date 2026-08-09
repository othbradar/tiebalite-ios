import Observation

enum RecommendationsLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum RecommendationsState: Equatable, Sendable {
    case empty
    case initialFailure(RecommendationsLoadFailure)
    case initialLoading
    case loaded([RecommendationSummary])
    case loadingNextPage([RecommendationSummary])
    case nextPageFailure([RecommendationSummary])
    case refreshing([RecommendationSummary])
    case refreshFailure([RecommendationSummary])

    var items: [RecommendationSummary]? {
        switch self {
        case let .loaded(items),
             let .loadingNextPage(items),
             let .nextPageFailure(items),
             let .refreshing(items),
             let .refreshFailure(items):
            items
        case .empty, .initialFailure, .initialLoading:
            nil
        }
    }
}

@MainActor
@Observable
final class RecommendationsStore {
    private(set) var state: RecommendationsState = .initialLoading
    private(set) var scrollAnchor: Int64?
    private(set) var currentPage: UInt32?
    private(set) var nextPage: UInt32?

    private let repository: any RecommendationRepository
    @ObservationIgnored private var hasCompletedInitialLoad = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0

    init(repository: any RecommendationRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard !hasCompletedInitialLoad,
              activeGeneration == nil else {
            return
        }
        await replaceLoad(retaining: nil)
    }

    func reload() async {
        hasCompletedInitialLoad = false
        await replaceLoad(retaining: state.items)
    }

    func loadNextPage() async {
        guard let task = beginNextPage() else {
            return
        }
        await awaitCallerOwned(task)
    }

    func requestNextPage(after threadID: Int64) {
        guard shouldPrefetch(after: threadID) else {
            return
        }
        _ = beginNextPage()
    }

    private func beginNextPage() -> Task<Void, Never>? {
        guard activeGeneration == nil,
              let retained = state.items,
              let nextPage else {
            return nil
        }
        state = .loadingNextPage(retained)
        return startLoad(
            request: RecommendationPageRequest(
                loadKind: .nextPage,
                page: nextPage
            ),
            purpose: .nextPage,
            retained: retained
        )
    }

    func prepareRetry() {
        guard activeGeneration == nil else {
            return
        }
        hasCompletedInitialLoad = false
        currentPage = nil
        nextPage = nil
        state = .initialLoading
    }

    func setScrollAnchor(_ threadID: Int64?) {
        guard scrollAnchor != threadID else {
            return
        }
        scrollAnchor = threadID
    }

    func shouldPrefetch(after threadID: Int64) -> Bool {
        guard activeGeneration == nil,
              nextPage != nil,
              let items = state.items else {
            return false
        }
        return items.suffix(4).contains { $0.threadID == threadID }
    }

    private func replaceLoad(
        retaining retained: [RecommendationSummary]?
    ) async {
        loadTask?.cancel()
        state = retained.map(RecommendationsState.refreshing)
            ?? .initialLoading
        let task = startLoad(
            request: .initial,
            purpose: retained == nil ? .initial : .refresh,
            retained: retained
        )
        await awaitCallerOwned(task)
    }

    @discardableResult
    private func startLoad(
        request: RecommendationPageRequest,
        purpose: LoadPurpose,
        retained: [RecommendationSummary]?
    ) -> Task<Void, Never> {
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation

        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let page = try await repository.loadPage(request)
                try Task.checkCancellation()
                self?.finishSuccess(
                    generation: generation,
                    request: request,
                    purpose: purpose,
                    retained: retained,
                    page: page
                )
            } catch is CancellationError {
                self?.finishCancellation(
                    generation: generation,
                    retained: retained
                )
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(
                        generation: generation,
                        retained: retained
                    )
                    return
                }
                self?.finishFailure(
                    generation: generation,
                    purpose: purpose,
                    retained: retained
                )
            }
        }
        loadTask = task
        return task
    }

    private func awaitCallerOwned(_ task: Task<Void, Never>) async {
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func finishSuccess(
        generation: UInt64,
        request: RecommendationPageRequest,
        purpose: LoadPurpose,
        retained: [RecommendationSummary]?,
        page: RecommendationRepositoryPage
    ) {
        guard activeGeneration == generation,
              page.requestedPage == request.page,
              page.nextPageCandidate.map({ $0 > request.page }) ?? true else {
            finishFailure(
                generation: generation,
                purpose: purpose,
                retained: retained
            )
            return
        }
        switch purpose {
        case .initial, .refresh:
            let items = deduplicated(page.items)
            currentPage = page.requestedPage
            nextPage = items.isEmpty ? nil : page.nextPageCandidate
            state = items.isEmpty ? .empty : .loaded(items)
        case .nextPage:
            guard let retained else {
                finishFailure(
                    generation: generation,
                    purpose: purpose,
                    retained: nil
                )
                return
            }
            var seen = Set(retained.map(\.threadID))
            let unique = page.items.filter {
                $0.threadID > 0 && seen.insert($0.threadID).inserted
            }
            currentPage = page.requestedPage
            nextPage = page.items.isEmpty || unique.isEmpty
                ? nil
                : page.nextPageCandidate
            state = .loaded(retained + unique)
        }
        hasCompletedInitialLoad = true
        clearLoad(generation: generation)
    }

    private func finishFailure(
        generation: UInt64,
        purpose: LoadPurpose,
        retained: [RecommendationSummary]?
    ) {
        guard activeGeneration == generation else {
            return
        }
        switch (purpose, retained) {
        case (.nextPage, let retained?):
            state = .nextPageFailure(retained)
        case (.refresh, let retained?):
            state = .refreshFailure(retained)
        case (.initial, _), (.nextPage, nil), (.refresh, nil):
            state = .initialFailure(.unavailable)
            currentPage = nil
            nextPage = nil
        }
        hasCompletedInitialLoad = true
        clearLoad(generation: generation)
    }

    private func finishCancellation(
        generation: UInt64,
        retained: [RecommendationSummary]?
    ) {
        guard activeGeneration == generation else {
            return
        }
        if let retained {
            state = .loaded(retained)
            hasCompletedInitialLoad = true
        } else {
            state = .initialLoading
            hasCompletedInitialLoad = false
        }
        clearLoad(generation: generation)
    }

    private func clearLoad(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        loadTask = nil
    }

    private func deduplicated(
        _ items: [RecommendationSummary]
    ) -> [RecommendationSummary] {
        var seen: Set<Int64> = []
        return items.filter {
            $0.threadID > 0 && seen.insert($0.threadID).inserted
        }
    }
}

private enum LoadPurpose: Sendable {
    case initial
    case nextPage
    case refresh
}
