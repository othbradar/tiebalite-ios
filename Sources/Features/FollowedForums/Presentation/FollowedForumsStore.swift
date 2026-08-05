import Observation

@MainActor
@Observable
final class FollowedForumsStore {
    typealias ExpireSession = @MainActor @Sendable (AuthContext) async -> Void

    private(set) var state: FollowedForumsState = .signedOut
    private(set) var scrollAnchor: Int64?

    private let repository: any FollowedForumsRepository
    private let expireSession: ExpireSession

    @ObservationIgnored private var currentAccess: FollowedForumsSessionAccess =
        .signedOut
    @ObservationIgnored private var hasCompletedLoad = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0
    @ObservationIgnored private var cancellationState: FollowedForumsState =
        .initialLoading

    init(
        repository: any FollowedForumsRepository,
        expireSession: @escaping ExpireSession = { _ in }
    ) {
        self.repository = repository
        self.expireSession = expireSession
    }

    func synchronize(with access: FollowedForumsSessionAccess) async {
        if currentAccess != access {
            cancelCurrentLoad()
            currentAccess = access
            hasCompletedLoad = false
            scrollAnchor = nil
            switch access {
            case .active:
                state = .initialLoading
            case .expired:
                state = .expired
            case .signedOut:
                state = .signedOut
            case .signingIn:
                state = .signingIn
            }
        }

        guard case let .active(authentication) = currentAccess,
              !hasCompletedLoad,
              activeGeneration == nil else {
            return
        }
        await replaceLoad(authentication: authentication, previous: nil)
    }

    func reload() async {
        guard case let .active(authentication) = currentAccess else {
            return
        }
        let previous = retainedForums
        hasCompletedLoad = false
        await replaceLoad(
            authentication: authentication,
            previous: previous
        )
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

    func setScrollAnchor(_ forumID: Int64?) {
        guard scrollAnchor != forumID else {
            return
        }
        scrollAnchor = forumID
    }

    private var retainedForums: [FollowedForum]? {
        switch state {
        case let .loaded(forums),
             let .refreshFailure(forums, _),
             let .refreshing(forums):
            forums
        case .empty, .expired, .initialFailure, .initialLoading,
             .signedOut, .signingIn:
            nil
        }
    }

    private func replaceLoad(
        authentication: AuthContext,
        previous: [FollowedForum]?
    ) async {
        loadTask?.cancel()
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        cancellationState = previous.map(FollowedForumsState.loaded)
            ?? .initialLoading
        state = previous.map(FollowedForumsState.refreshing)
            ?? .initialLoading

        let repository = repository
        let expireSession = expireSession
        let task = Task { @MainActor [weak self] in
            do {
                let forums = try await repository.loadFollowedForums(
                    authentication: authentication
                )
                try Task.checkCancellation()
                self?.finish(
                    generation: generation,
                    previous: previous,
                    result: .success(forums)
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch FollowedForumsRepositoryError.sessionExpired {
                guard self?.finishExpired(generation: generation) == true else {
                    return
                }
                await expireSession(authentication)
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
        previous: [FollowedForum]?,
        result: Result<[FollowedForum], FollowedForumsLoadFailure>
    ) {
        guard activeGeneration == generation else {
            return
        }
        switch result {
        case let .success(forums):
            state = forums.isEmpty ? .empty : .loaded(forums)
        case let .failure(failure):
            state = previous.map {
                .refreshFailure($0, failure)
            } ?? .initialFailure(failure)
        }
        hasCompletedLoad = true
        finishOperation(generation: generation)
    }

    private func finishExpired(generation: UInt64) -> Bool {
        guard activeGeneration == generation else {
            return false
        }
        currentAccess = .expired
        state = .expired
        scrollAnchor = nil
        hasCompletedLoad = true
        finishOperation(generation: generation)
        return true
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

private extension FollowedForumsState {
    var hasCompletedLoad: Bool {
        switch self {
        case .empty, .initialFailure, .loaded, .refreshFailure:
            true
        case .expired, .initialLoading, .refreshing, .signedOut, .signingIn:
            false
        }
    }
}
