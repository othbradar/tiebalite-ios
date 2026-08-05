import Observation

@MainActor
@Observable
final class ForumHomeStore {
    private(set) var route: ForumRoute
    private(set) var state: ForumHomeState = .initialLoading
    private(set) var scrollAnchor: Int64?

    private let repository: any ForumHomeRepository
    @ObservationIgnored private var hasCompletedLoad = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0
    @ObservationIgnored private var cancellationState: ForumHomeState =
        .initialLoading

    init(
        route: ForumRoute,
        repository: any ForumHomeRepository
    ) {
        self.route = route
        self.repository = repository
    }

    func synchronize(with route: ForumRoute) async {
        if self.route != route {
            cancelCurrentLoad()
            self.route = route
            state = .initialLoading
            scrollAnchor = nil
            hasCompletedLoad = false
        }

        guard !hasCompletedLoad,
              activeGeneration == nil else {
            return
        }
        await replaceLoad(previous: nil)
    }

    func reload() async {
        let previous = retainedSnapshot
        hasCompletedLoad = false
        await replaceLoad(previous: previous)
    }

    func cancel() {
        guard activeGeneration != nil else {
            return
        }
        let restoredState = cancellationState
        cancelCurrentLoad()
        state = restoredState
        hasCompletedLoad = restoredState.hasCompletedLoad
    }

    func setScrollAnchor(_ itemID: Int64?) {
        guard scrollAnchor != itemID else {
            return
        }
        scrollAnchor = itemID
    }

    private var retainedSnapshot: ForumHomeSnapshot? {
        switch state {
        case let .loaded(snapshot),
             let .refreshFailure(snapshot, _),
             let .refreshing(snapshot):
            snapshot
        case .empty, .initialFailure, .initialLoading:
            nil
        }
    }

    private func replaceLoad(previous: ForumHomeSnapshot?) async {
        loadTask?.cancel()
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        cancellationState = previous.map(ForumHomeState.loaded)
            ?? .initialLoading
        state = previous.map(ForumHomeState.refreshing)
            ?? .initialLoading

        let repository = repository
        let route = route
        let task = Task { @MainActor [weak self] in
            do {
                let snapshot = try await repository.loadForumHome(route: route)
                try Task.checkCancellation()
                self?.finish(
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
                self?.finish(
                    generation: generation,
                    previous: previous,
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
        previous: ForumHomeSnapshot?,
        result: Result<ForumHomeSnapshot, ForumHomeLoadFailure>
    ) {
        guard activeGeneration == generation else {
            return
        }
        switch result {
        case let .success(snapshot):
            state = snapshot.threads.isEmpty
                ? .empty(snapshot.forum)
                : .loaded(snapshot)
        case let .failure(failure):
            state = previous.map {
                .refreshFailure($0, failure)
            } ?? .initialFailure(failure)
        }
        hasCompletedLoad = true
        finishOperation(generation: generation)
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        state = cancellationState
        hasCompletedLoad = cancellationState.hasCompletedLoad
        finishOperation(generation: generation)
    }

    private func finishOperation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        loadTask = nil
    }

    private func cancelCurrentLoad() {
        loadTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nil
        loadTask = nil
    }
}

private extension ForumHomeState {
    var hasCompletedLoad: Bool {
        switch self {
        case .empty, .initialFailure, .loaded, .refreshFailure:
            true
        case .initialLoading, .refreshing:
            false
        }
    }
}
