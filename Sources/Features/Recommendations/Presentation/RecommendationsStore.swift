import Observation

enum RecommendationsLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum RecommendationsState: Equatable, Sendable {
    case empty
    case initialFailure(RecommendationsLoadFailure)
    case initialLoading
    case loaded([RecommendationSummary])
}

@MainActor
@Observable
final class RecommendationsStore {
    private(set) var state: RecommendationsState = .initialLoading
    private(set) var scrollAnchor: Int64?

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
        await replaceLoad()
    }

    func reload() async {
        hasCompletedInitialLoad = false
        await replaceLoad()
    }

    func prepareRetry() {
        guard activeGeneration == nil else {
            return
        }
        hasCompletedInitialLoad = false
        state = .initialLoading
    }

    func setScrollAnchor(_ threadID: Int64?) {
        guard scrollAnchor != threadID else {
            return
        }
        scrollAnchor = threadID
    }

    private func replaceLoad() async {
        loadTask?.cancel()
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        state = .initialLoading

        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let items = try await repository.loadRecommendations()
                try Task.checkCancellation()
                self?.finish(
                    generation: generation,
                    result: .success(items)
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finish(
                    generation: generation,
                    result: .failure(.unavailable)
                )
            }
        }
        loadTask = task

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func finish(
        generation: UInt64,
        result: Result<
            [RecommendationSummary],
            RecommendationsLoadFailure
        >
    ) {
        guard activeGeneration == generation else {
            return
        }
        switch result {
        case let .success(items):
            state = items.isEmpty ? .empty : .loaded(items)
        case let .failure(failure):
            state = .initialFailure(failure)
        }
        hasCompletedInitialLoad = true
        activeGeneration = nil
        loadTask = nil
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        state = .initialLoading
        hasCompletedInitialLoad = false
        activeGeneration = nil
        loadTask = nil
    }
}
