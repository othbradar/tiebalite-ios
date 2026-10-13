import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U10BookmarkTests {
    @Test func addDuplicateUpdateRemoveAndPagination() async throws {
        let repository = BookmarkRepository(directory: nil)
        let store = makeStore(repository)
        await store.load()
        for id in 1...42 { await store.save(entry(Int64(id))) }
        await store.save(entry(1, postID: 9003, floor: 3))
        #expect(store.entries.count == 40 && store.hasMore)
        store.loadMore()
        #expect(store.entries.count == 42 && !store.hasMore)
        #expect(store.entries.first?.target.postID == 9003)
        await store.remove(threadID: 1)
        #expect(!store.contains(1) && store.entries.count == 41)
        #expect(try await repository.entries(account: "account-a").count == 41)
    }

    @Test func diskRestartAndAccountIsolationDoNotUseContentCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("u10-bookmark-persistence")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = BookmarkRepository(directory: directory)
        try await first.save(entry(81, postID: 8103, floor: 3), account: "account-a")
        let cache = ContentPageCache(directory: directory.appendingPathComponent("temporary-cache"))
        await cache.clear()
        let reopened = BookmarkRepository(directory: directory)
        #expect(try await reopened.entries(account: "account-a").first?.target.postID == 8103)
        #expect(try await reopened.entries(account: "account-b").isEmpty == true)
        try await reopened.save(entry(82), account: "account-b")
        #expect(try await reopened.entries(account: "account-a").map(\.id) == [81])
    }

    @Test func failedWriteKeepsPreviousBookmarkAndCanRetry() async throws {
        let repository = U10FailingRepository()
        let store = makeStore(repository)
        await store.save(entry(2))
        #expect(store.contains(2))
        await repository.setFailure(true)
        await store.remove(threadID: 2)
        #expect(store.contains(2) && store.feedback != nil && !store.isBusy)
        await repository.setFailure(false)
        await store.remove(threadID: 2)
        #expect(!store.contains(2))
    }

    @Test(arguments: [false, true])
    func changedAccountOrCancelledReadCannotPublishOldBookmarks(changesAccount: Bool) async throws {
        let context = U10Context()
        let repository = U10HeldRepository()
        let store = BookmarkStore(repository: repository, context: { context.value }, account: { "account-a" })
        let loading = Task { await store.load() }
        try await repository.started.wait()
        if changesAccount {
            context.value = .init(namespace: "other", revision: 2)
            store.sessionChanged()
        } else { loading.cancel() }
        repository.release.succeed(())
        await loading.value
        #expect(store.entries.isEmpty && !store.isBusy && store.feedback == nil)
        #expect(store.state == .idle)
    }

    @Test func bookmarkTargetWinsOverHistoryAndMissingTargetFails() async throws {
        let reader = ThreadReaderStore(threadID: 100001, repository: FixtureThreadReaderRepository())
        await reader.loadIfNeeded()
        await reader.jumpToPage(4)
        let target = ThreadBookmarkTarget(threadID: 100001, postID: 130001)
        #expect(await BookmarkNavigation.open(target, in: reader))
        #expect(reader.readAnchor == .post(threadID: 100001, postID: 130001))
        #expect(await BookmarkNavigation.open(.init(threadID: 100001, postID: 9999999), in: reader) == false)
        #expect(SettingsRouteGrammar.canonical([.bookmarks, .bookmark(target)]) == [.bookmarks, .bookmark(target)])
    }

    private func entry(_ id: Int64, postID: Int64? = nil, floor: Int? = nil) -> ThreadBookmark {
        .init(target: .init(threadID: id, postID: postID), title: "示例帖子", forumName: "示例吧", floor: floor)
    }

    private func makeStore(_ repository: any BookmarkRepositoryProtocol) -> BookmarkStore {
        BookmarkStore(repository: repository, context: { .init(namespace: "fixture", revision: 1) }, account: { "account-a" })
    }
}

@MainActor private final class U10Context {
    var value = ContentCacheContext(namespace: "fixture", revision: 1)
}

private actor U10FailingRepository: BookmarkRepositoryProtocol {
    let base = BookmarkRepository(directory: nil)
    var fails = false
    func setFailure(_ value: Bool) { fails = value }
    func entries(account: String) async throws -> [ThreadBookmark] { try await base.entries(account: account) }
    func save(_ entry: ThreadBookmark, account: String) async throws {
        if fails { throw BookmarkFailure.storage }
        try await base.save(entry, account: account)
    }
    func remove(threadID: Int64, account: String) async throws {
        if fails { throw BookmarkFailure.storage }
        try await base.remove(threadID: threadID, account: account)
    }
}

private actor U10HeldRepository: BookmarkRepositoryProtocol {
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let release = HarnessContinuationGate<Void>()
    func entries(account: String) async throws -> [ThreadBookmark] {
        started.succeed(())
        try await release.wait()
        return [.init(target: .init(threadID: 1, postID: 2), title: "示例", forumName: "示例吧", floor: 2)]
    }
    func save(_ entry: ThreadBookmark, account: String) async throws {}
    func remove(threadID: Int64, account: String) async throws {}
}
