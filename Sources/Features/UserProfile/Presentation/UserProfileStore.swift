import Observation

@MainActor
@Observable
final class UserProfileStore {
    private(set) var route: UserProfileRoute
    private(set) var state: UserProfileState

    private let repository: any UserProfileRepository
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var displayedUserID: UserID?

    init(
        route: UserProfileRoute,
        repository: any UserProfileRepository
    ) {
        self.route = route
        self.repository = repository
        state = .idle(route)
    }

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }
        await load(route: route)
    }

    func retry() async {
        await load(route: route)
    }

    func load(route newRoute: UserProfileRoute) async {
        loadTask?.cancel()
        generation &+= 1
        let operationGeneration = generation
        if route.userID != newRoute.userID {
            displayedUserID = nil
        }
        route = newRoute
        state = .loading(newRoute)
        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let profile = try await repository.loadProfile(route: newRoute)
                try Task.checkCancellation()
                self?.finish(
                    .success(profile),
                    route: newRoute,
                    generation: operationGeneration
                )
            } catch is CancellationError {
                self?.finishCancellation(
                    route: newRoute,
                    generation: operationGeneration
                )
            } catch UserProfileRepositoryError.empty {
                guard !Task.isCancelled else {
                    self?.finishCancellation(
                        route: newRoute,
                        generation: operationGeneration
                    )
                    return
                }
                self?.finish(
                    .empty,
                    route: newRoute,
                    generation: operationGeneration
                )
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(
                        route: newRoute,
                        generation: operationGeneration
                    )
                    return
                }
                self?.finish(
                    .failure,
                    route: newRoute,
                    generation: operationGeneration
                )
            }
        }
        loadTask = task
        await task.value
    }

    func cancel() {
        loadTask?.cancel()
        generation &+= 1
        loadTask = nil
        if case .loading = state {
            state = .idle(route)
        }
    }

    func claimDisplayedUser(_ userID: UserID) -> Bool {
        guard userID == route.userID,
              displayedUserID != userID else {
            return false
        }
        displayedUserID = userID
        return true
    }

    private func finish(
        _ result: LoadResult,
        route expectedRoute: UserProfileRoute,
        generation operationGeneration: UInt64
    ) {
        guard generation == operationGeneration,
              route == expectedRoute else {
            return
        }
        switch result {
        case let .success(profile):
            guard profile.userID == expectedRoute.userID else {
                state = .failed(expectedRoute)
                loadTask = nil
                return
            }
            state = .loaded(profile)
        case .empty:
            state = .empty(expectedRoute)
        case .failure:
            state = .failed(expectedRoute)
        }
        loadTask = nil
    }

    private func finishCancellation(
        route expectedRoute: UserProfileRoute,
        generation operationGeneration: UInt64
    ) {
        guard generation == operationGeneration,
              route == expectedRoute else {
            return
        }
        state = .idle(expectedRoute)
        loadTask = nil
    }
}

private enum LoadResult: Sendable {
    case success(UserProfile)
    case empty
    case failure
}
