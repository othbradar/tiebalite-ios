import Observation

@MainActor
@Observable
final class NotificationDestinationStore {
    let target: NotificationTarget
    private(set) var thread: ThreadReaderStore?
    private(set) var failed = false
    @ObservationIgnored private let repository: any NotificationTargetRepository
    @ObservationIgnored private let threads: any ThreadReaderRepository
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    init(target: NotificationTarget, repository: any NotificationTargetRepository,
         threads: any ThreadReaderRepository) {
        self.target = target; self.repository = repository; self.threads = threads
    }

    func load() async {
        guard thread == nil, task == nil else { return }
        failed = false
        generation &+= 1
        let token = generation
        let operation = Task { @MainActor [weak self, repository, threads, target] in
            do {
                let postID = try await repository.parentPostID(for: target)
                try Task.checkCancellation()
                let store = try await Self.loadThread(threadID: target.threadID, through: postID, repository: threads)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.thread = store
            } catch is CancellationError {
                // A popped message destination must not publish its result.
            } catch {
                guard let self, self.generation == token else { return }
                self.failed = true
            }
            guard let self, self.generation == token else { return }
            self.task = nil
        }
        task = operation
        await withTaskCancellationHandler { await operation.value } onCancel: { operation.cancel() }
    }

    private static func loadThread(
        threadID: Int64, through postID: Int64, repository: any ThreadReaderRepository
    ) async throws -> ThreadReaderStore {
        let store = ThreadReaderStore(threadID: threadID, repository: repository)
        await store.loadIfNeeded()
        while true {
            try Task.checkCancellation()
            guard case let .loaded(snapshot) = store.state else { throw ThreadReaderLoadFailure.unavailable }
            if let anchor = store.listPresentation?.rows.first(where: { $0.post?.source.postID == postID })?.id {
                // Mount the existing list only once the contiguous prefix and its initial anchor are ready.
                store.setInitialReadAnchor(anchor)
                return store
            }
            guard snapshot.hasMore else { throw ThreadReaderLoadFailure.unavailable }
            await store.loadNextPage()
            guard (store.state.snapshot?.currentPage ?? 0) > snapshot.currentPage else {
                try Task.checkCancellation()
                throw ThreadReaderLoadFailure.unavailable
            }
        }
    }

    func cancel() {
        generation &+= 1
        task?.cancel(); task = nil
        thread?.cancel()
    }
}
