import Observation

enum ThreadReaderLoadFailure: Equatable, Sendable {
    case unavailable
}

enum ThreadReaderState: Equatable, Sendable {
    case initialFailure(ThreadReaderLoadFailure)
    case initialLoading
    case loaded(ThreadReaderSnapshot)

    var snapshot: ThreadReaderSnapshot? {
        guard case let .loaded(snapshot) = self else {
            return nil
        }
        return snapshot
    }
}

@MainActor
@Observable
final class ThreadReaderStore {
    let threadID: Int64
    private(set) var state: ThreadReaderState = .initialLoading
    private(set) var readAnchor: ThreadContentSource?

    private let repository: any ThreadReaderRepository
    @ObservationIgnored private var hasCompletedInitialLoad = false
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0

    init(
        threadID: Int64,
        repository: any ThreadReaderRepository
    ) {
        self.threadID = threadID
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

    func setReadAnchor(_ source: ThreadContentSource?) {
        guard readAnchor != source else {
            return
        }
        readAnchor = source
    }

    private func load() async {
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        state = .initialLoading

        do {
            let snapshot = try await repository.loadThread(threadID: threadID)
            try Task.checkCancellation()
            guard activeGeneration == generation else {
                return
            }
            if snapshot.threadID == threadID {
                state = .loaded(snapshot)
            } else {
                state = .initialFailure(.unavailable)
            }
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
