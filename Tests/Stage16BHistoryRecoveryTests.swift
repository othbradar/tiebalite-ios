import Foundation
import Testing
@testable import TiebaLite

struct Stage16BHistoryRecoveryTests {
    @Test @MainActor
    func recordFailureIsObservableAndClearRecoversTheStore() async throws {
        let repository = Stage16BFailingHistoryRepository()
        let store = BrowsingHistoryStore(
            repository: repository,
            clock: HarnessControlledClock()
        )
        let route = try #require(ForumRoute(
            forumID: 818,
            forumName: "Fixture forum"
        ))
        let forum = ForumSummary(
            forumID: 818,
            name: "Fixture forum",
            slogan: nil,
            avatarResourceID: nil,
            memberCount: 0,
            threadCount: 0,
            postCount: 0
        )

        await store.recordForum(route: route, forum: forum)

        #expect(store.hasPersistenceFailure)
        #expect(store.canClearHistory)
        await repository.allowOperations()
        await store.clear()
        #expect(!store.hasPersistenceFailure)
        #expect(store.entries.isEmpty)
    }

    @Test @MainActor
    func corruptJSONCanBeClearedAndRebuilt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("stage16b-corrupt-history-json")
        try? FileManager.default.removeItem(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent("history.json")
        try Data("not-json".utf8).write(to: fileURL, options: .atomic)
        let repository = JSONBrowsingHistoryRepository(fileURL: fileURL)
        let store = BrowsingHistoryStore(
            repository: repository,
            clock: HarnessControlledClock()
        )

        await store.reload()
        #expect(store.state == .failed)
        #expect(store.canClearHistory)

        await store.clear()
        #expect(store.state == .loaded([]))
        #expect(try await repository.load().isEmpty)

        try await repository.record(.thread(
            threadID: 828,
            title: "Recovered history",
            forumName: nil,
            visitedAt: Date(timeIntervalSince1970: 8_280)
        ))
        let rebuilt = JSONBrowsingHistoryRepository(fileURL: fileURL)
        #expect(try await rebuilt.load().map(\.identity) == [.thread(828)])
    }

    @Test @MainActor
    func recordFailureRetainsLoadedEntriesAndSurfacesIssue() async throws {
        let existing = try BrowsingHistoryEntry.thread(
            threadID: 838,
            title: "Existing history",
            forumName: nil,
            visitedAt: Date(timeIntervalSince1970: 8_380)
        )
        let repository = Stage16BRecordFailingHistoryRepository(
            entries: [existing],
            failure: .unavailable
        )
        let store = BrowsingHistoryStore(
            repository: repository,
            clock: HarnessControlledClock()
        )
        await store.reload()
        let route = try #require(ForumRoute(
            forumID: 839,
            forumName: "New forum"
        ))

        await store.recordForum(
            route: route,
            forum: forumSummary(id: 839, name: "New forum")
        )

        #expect(store.entries == [existing])
        #expect(store.persistenceIssue == .recordFailed)
    }

    @Test @MainActor
    func recordCancellationDoesNotSurfacePersistenceIssue() async throws {
        let repository = Stage16BRecordFailingHistoryRepository(
            entries: [],
            failure: .cancelled
        )
        let store = BrowsingHistoryStore(
            repository: repository,
            clock: HarnessControlledClock()
        )
        let route = try #require(ForumRoute(
            forumID: 848,
            forumName: "Cancelled forum"
        ))

        await store.recordForum(
            route: route,
            forum: forumSummary(id: 848, name: "Cancelled forum")
        )

        #expect(store.persistenceIssue == nil)
    }

    @Test @MainActor
    func lateInitialLoadCannotOverwriteASuccessfulRecord() async throws {
        let repository = Stage16BStaleLoadHistoryRepository()
        let store = BrowsingHistoryStore(
            repository: repository,
            clock: HarnessControlledClock()
        )
        let route = try #require(ForumRoute(
            forumID: 858,
            forumName: "Newest forum"
        ))
        let reloadTask = Task { @MainActor in
            await store.reload()
        }
        try await repository.waitUntilInitialLoadStarts()

        await store.recordForum(
            route: route,
            forum: forumSummary(id: 858, name: "Newest forum")
        )
        #expect(store.entries.map(\.identity) == [.forum(858)])

        await repository.finishInitialLoad(with: [])
        await reloadTask.value

        #expect(store.entries.map(\.identity) == [.forum(858)])
        #expect(store.persistenceIssue == nil)
    }

    private func forumSummary(id: Int64, name: String) -> ForumSummary {
        ForumSummary(
            forumID: id,
            name: name,
            slogan: nil,
            avatarResourceID: nil,
            memberCount: 0,
            threadCount: 0,
            postCount: 0
        )
    }
}

private enum Stage16BHistoryRepositoryError: Error {
    case unavailable
}

private actor Stage16BFailingHistoryRepository: BrowsingHistoryRepository {
    private var shouldFail = true

    func load() throws -> [BrowsingHistoryEntry] {
        if shouldFail {
            throw Stage16BHistoryRepositoryError.unavailable
        }
        return []
    }

    func record(_ entry: BrowsingHistoryEntry) throws {
        _ = entry
        if shouldFail {
            throw Stage16BHistoryRepositoryError.unavailable
        }
    }

    func delete(_ identity: BrowsingHistoryIdentity) throws {
        _ = identity
        if shouldFail {
            throw Stage16BHistoryRepositoryError.unavailable
        }
    }

    func clear() throws {
        if shouldFail {
            throw Stage16BHistoryRepositoryError.unavailable
        }
    }

    func allowOperations() {
        shouldFail = false
    }
}

private actor Stage16BRecordFailingHistoryRepository:
    BrowsingHistoryRepository {
    enum Failure {
        case cancelled
        case unavailable
    }

    private let entries: [BrowsingHistoryEntry]
    private let failure: Failure

    init(entries: [BrowsingHistoryEntry], failure: Failure) {
        self.entries = entries
        self.failure = failure
    }

    func load() -> [BrowsingHistoryEntry] {
        entries
    }

    func record(_ entry: BrowsingHistoryEntry) throws {
        _ = entry
        switch failure {
        case .cancelled:
            throw CancellationError()
        case .unavailable:
            throw Stage16BHistoryRepositoryError.unavailable
        }
    }

    func delete(_ identity: BrowsingHistoryIdentity) {
        _ = identity
    }

    func clear() {}
}

private actor Stage16BStaleLoadHistoryRepository:
    BrowsingHistoryRepository {
    private let initialLoadStarted = HarnessContinuationGate<Void>()
    private let initialLoadResult =
        HarnessContinuationGate<[BrowsingHistoryEntry]>()
    private var entries: [BrowsingHistoryEntry] = []
    private var loadCount = 0

    func load() async throws -> [BrowsingHistoryEntry] {
        loadCount += 1
        guard loadCount == 1 else {
            return entries
        }
        initialLoadStarted.succeed(())
        return try await initialLoadResult.wait()
    }

    func record(_ entry: BrowsingHistoryEntry) {
        entries = [entry]
    }

    func delete(_ identity: BrowsingHistoryIdentity) {
        entries.removeAll { $0.identity == identity }
    }

    func clear() {
        entries.removeAll(keepingCapacity: false)
    }

    func waitUntilInitialLoadStarts() async throws {
        try await initialLoadStarted.wait()
    }

    func finishInitialLoad(with entries: [BrowsingHistoryEntry]) {
        initialLoadResult.succeed(entries)
    }
}
