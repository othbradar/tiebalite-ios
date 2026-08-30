import Observation

@MainActor
@Observable
final class BrowsingHistoryStore {
    private(set) var state: BrowsingHistoryState = .idle
    private(set) var persistenceIssue: BrowsingHistoryPersistenceIssue?

    private let repository: any BrowsingHistoryRepository
    private let clock: any AppClock
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0

    init(
        repository: any BrowsingHistoryRepository,
        clock: any AppClock
    ) {
        self.repository = repository
        self.clock = clock
    }

    var entries: [BrowsingHistoryEntry] {
        state.entries
    }

    var count: Int {
        entries.count
    }

    var hasPersistenceFailure: Bool {
        persistenceIssue != nil
    }

    var canClearHistory: Bool {
        !entries.isEmpty || state == .failed || hasPersistenceFailure
    }

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }
        await reload()
    }

    func reload() async {
        loadTask?.cancel()
        generation &+= 1
        let operationGeneration = generation
        state = .loading
        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let entries = try await repository.load()
                try Task.checkCancellation()
                self?.finishLoad(
                    entries,
                    generation: operationGeneration
                )
            } catch is CancellationError {
                self?.finishCancellation(generation: operationGeneration)
            } catch {
                self?.finishFailure(generation: operationGeneration)
            }
        }
        loadTask = task
        await task.value
    }

    func recordThread(_ snapshot: ThreadReaderSnapshot) async {
        guard snapshot.threadID > 0,
              !snapshot.title.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty else {
            return
        }
        let entry: BrowsingHistoryEntry
        do {
            entry = try BrowsingHistoryEntry.thread(
                threadID: snapshot.threadID,
                title: snapshot.title,
                forumName: snapshot.forumName,
                visitedAt: await clock.now
            )
        } catch BrowsingHistoryError.invalidIdentity {
            return
        } catch {
            persistenceIssue = .recordFailed
            return
        }
        await recordAndReport(entry)
    }

    func recordForum(
        route: ForumRoute,
        forum: ForumSummary
    ) async {
        guard let forumID = forum.forumID
            ?? route.forumID?.rawValue else {
            return
        }
        let entry: BrowsingHistoryEntry
        do {
            entry = try BrowsingHistoryEntry.forum(
                forumID: forumID,
                forumName: forum.name,
                visitedAt: await clock.now
            )
        } catch BrowsingHistoryError.invalidIdentity {
            return
        } catch {
            persistenceIssue = .recordFailed
            return
        }
        await recordAndReport(entry)
    }

    func recordUser(_ profile: UserProfile) async {
        let entry: BrowsingHistoryEntry
        do {
            entry = try BrowsingHistoryEntry.user(
                userID: profile.userID.rawValue,
                displayName: profile.displayName,
                portraitResourceID: profile.portraitResourceID,
                visitedAt: await clock.now
            )
        } catch BrowsingHistoryError.invalidIdentity {
            return
        } catch {
            persistenceIssue = .recordFailed
            return
        }
        await recordAndReport(entry)
    }

    func delete(_ identity: BrowsingHistoryIdentity) async {
        do {
            try await repository.delete(identity)
            publishMutation(try await repository.load())
        } catch is CancellationError {
            return
        } catch {
            persistenceIssue = .deleteFailed
        }
    }

    func clear() async {
        do {
            try await repository.clear()
            publishMutation([])
        } catch is CancellationError {
            return
        } catch {
            persistenceIssue = .clearFailed
        }
    }

    func cancel() {
        loadTask?.cancel()
        generation &+= 1
        loadTask = nil
        if case .loading = state {
            state = .idle
        }
    }

    private func record(_ entry: BrowsingHistoryEntry) async throws {
        try await repository.record(entry)
        publishMutation(try await repository.load())
    }

    private func publishMutation(_ entries: [BrowsingHistoryEntry]) {
        generation &+= 1
        loadTask?.cancel()
        loadTask = nil
        state = .loaded(entries)
        persistenceIssue = nil
    }

    private func recordAndReport(_ entry: BrowsingHistoryEntry) async {
        do {
            try await record(entry)
        } catch is CancellationError {
            return
        } catch {
            persistenceIssue = .recordFailed
        }
    }

    private func finishLoad(
        _ entries: [BrowsingHistoryEntry],
        generation operationGeneration: UInt64
    ) {
        guard operationGeneration == generation else {
            return
        }
        state = .loaded(entries)
        loadTask = nil
    }

    private func finishCancellation(generation operationGeneration: UInt64) {
        guard operationGeneration == generation else {
            return
        }
        state = .idle
        loadTask = nil
    }

    private func finishFailure(generation operationGeneration: UInt64) {
        guard operationGeneration == generation else {
            return
        }
        state = .failed
        loadTask = nil
    }
}
