import Observation

enum RecommendationsLoadFailure: Equatable, Sendable {
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
        await load()
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

    private func load() async {
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        state = .initialLoading

        do {
            let items = try await repository.loadRecommendations()
            try Task.checkCancellation()
            guard activeGeneration == generation else {
                return
            }
            state = items.isEmpty ? .empty : .loaded(items)
            hasCompletedInitialLoad = true
        } catch is CancellationError {
            guard activeGeneration == generation else {
                return
            }
            state = .initialLoading
            hasCompletedInitialLoad = false
        } catch {
            guard activeGeneration == generation else {
                return
            }
            state = .initialFailure(.unavailable)
            hasCompletedInitialLoad = true
        }

        if activeGeneration == generation {
            activeGeneration = nil
        }
    }
}
