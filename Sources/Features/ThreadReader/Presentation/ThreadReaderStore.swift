import Observation

enum ThreadReaderLoadFailure: Error, Equatable, Sendable {
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
    @ObservationIgnored private var loadTask: Task<Void, Never>?
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

    func setReadAnchor(_ source: ThreadContentSource?) {
        guard readAnchor != source else {
            return
        }
        readAnchor = source
    }

    private func replaceLoad() async {
        loadTask?.cancel()
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        state = .initialLoading

        let repository = repository
        let threadID = threadID
        let task = Task { @MainActor [weak self] in
            do {
                let snapshot = try await repository.loadThread(
                    threadID: threadID
                )
                try Task.checkCancellation()
                self?.finish(
                    generation: generation,
                    snapshot: snapshot
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(generation: generation)
                    return
                }
                self?.finishFailure(generation: generation)
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
        snapshot: ThreadReaderSnapshot
    ) {
        guard activeGeneration == generation else {
            return
        }
        state = snapshot.threadID == threadID
            ? .loaded(snapshot)
            : .initialFailure(.unavailable)
        hasCompletedInitialLoad = true
        clearLoad(generation: generation)
    }

    private func finishFailure(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        state = .initialFailure(.unavailable)
        hasCompletedInitialLoad = true
        clearLoad(generation: generation)
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        state = .initialLoading
        hasCompletedInitialLoad = false
        clearLoad(generation: generation)
    }

    private func clearLoad(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        loadTask = nil
    }
}
