import Foundation
import Testing
@testable import TiebaLite

struct U14ContentActionTests {
    @Test func deletionNeedsFreshPositiveOwnershipAndValidIdentity() {
        func value(_ author: Int64, account: Int64 = 42, permission: Bool = true) -> ContentActionInspection {
            .init(target: .init(kind: .post, threadID: 10, postID: 11), accountID: account,
                  authorID: author, forumID: 9, forumName: "Fixture", firstPostID: 1,
                  likeCount: 2, liked: false, permitsOwnDeletion: permission)
        }
        #expect(value(42).canDelete)
        #expect(!value(41).canDelete)
        #expect(!value(42, permission: false).canDelete)
        #expect(!value(0, account: 0).canDelete)
    }
}

@MainActor
@Suite(.serialized)
struct U14ContentActionStateTests {
    private let target = ContentActionTarget(kind: .post, threadID: 10, postID: 11)
    private func store(_ repository: U14ActionMock, session: U14Session = U14Session()) -> ContentActionStore {
        .init(repository: repository, ledger: .init(file: nil), visibility: ContentRemovalVisibility(),
              context: { session.value }, account: { repository.account })
    }
    @Test func duplicateTapsCoalesceAndDefiniteFailureKeepsAcceptedState() async {
        let repository = U14ActionMock(), gate = U14ActionGate()
        let store = store(repository)
        repository.writeGate = gate
        let operation = Task { await store.toggleLike(target) }
        await gate.waitForEntry()
        await store.toggleLike(target)
        #expect(repository.writes == 1 && store.likes[target] == nil)
        gate.release(); await operation.value
        #expect(store.likes[target] == .init(count: 3, selected: true))
        repository.writeGate = nil; repository.failure = .rejected
        await store.toggleLike(target)
        #expect(store.likes[target] == .init(count: 3, selected: true))
        #expect(store.feedback != nil && store.busy.isEmpty)
    }
    @Test func unknownResultNextTapOnlyReadsAndSessionChangeDiscardsLateInspection() async {
        let repository = U14ActionMock(), session = U14Session(), gate = U14ActionGate()
        let store = store(repository, session: session)
        repository.failure = .outcomeUnknown
        await store.toggleLike(target)
        #expect(store.uncertain.contains(target) && repository.writes == 1)
        repository.failure = nil; repository.liked = true
        await store.toggleLike(target)
        #expect(repository.writes == 1 && store.likes[target]?.selected == true)
        repository.inspectGate = gate
        let operation = Task { await store.toggleLike(target) }
        await gate.waitForEntry()
        session.value = .init(namespace: "fixture-b", revision: 2)
        store.sessionChanged()
        gate.release(); await operation.value
        #expect(repository.writes == 1 && store.likes.isEmpty && store.permissions.isEmpty)
    }
    @Test func ownDeletionRequiresFreshPermissionAndExplicitConfirmation() async throws {
        let repository = U14ActionMock(), store = store(repository)
        await store.prepareDeletion(target, authorID: 41)
        #expect(repository.inspections == 0 && store.permissions.isEmpty)
        await store.prepareDeletion(target, authorID: 42)
        store.askToDelete(target)
        #expect(repository.deletes == 0)
        let confirmation = try #require(store.pendingDeletion)
        store.pendingDeletion = nil // Cancel performs no write.
        #expect(repository.deletes == 0)
        repository.author = 41 // Permission changed while confirmation was visible.
        await store.confirmDeletion(confirmation)
        #expect(repository.deletes == 0)
        repository.author = 42
        await store.confirmDeletion(confirmation)
        #expect(repository.deletes == 1 && store.permissions[target] == nil)
    }
    @Test func confirmedRemovalPersistsAndOldPagesCannotReturnFromCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("u14-removal-test")
        try? FileManager.default.removeItem(at: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("removed.json")
        let ledger = ContentRemovalRepository(file: file)
        let cache = ContentPageCache(directory: directory.appendingPathComponent("cache"))
        let seed = FixtureThreadSeed(threadID: 100_001, title: "Fixture", forumName: "Fixture", authorName: "Fixture",
                                     replyCount: 40, imageResources: [])
        let snapshot = FixtureThreadReaderPages.firstPage(from: seed)
        let removed = ContentActionTarget(kind: .post, threadID: 100_001, postID: 120_001)
        let page = CachedReadingPage(locator: ReadingPageLocator(page: 1, postID: 0),
                                     fetchedAt: Date(timeIntervalSince1970: 1), value: snapshot)
        let bytes = try JSONEncoder().encode(page)
        let key = "fixture|thread-v1|100001|thread|all-ascending|pn:1|pid:0|body"
        let position = Data("{\"position\":{\"postID\":130001}}".utf8)
        #expect(await cache.write(bytes, key: key, epoch: 0))
        #expect(await cache.write(position, key: "fixture|thread-v1|100001|thread|all-ascending", epoch: 0))
        try await ledger.prepare()
        _ = try await ledger.record(removed)
        let reloaded = try await ContentRemovalRepository(file: file).load()
        #expect(reloaded.map(\.target) == [removed])
        await cache.excludeConfirmedRemovals(Set(reloaded.map(\.target)))
        #expect(await cache.read(key: key) == nil)
        #expect(await cache.write(bytes, key: key + "late-prefetch", epoch: 0) == false)
        #expect(await cache.read(key: "fixture|thread-v1|100001|thread|all-ascending") == position)
        let reopened = ContentPageCache(directory: directory.appendingPathComponent("cache"))
        await reopened.excludeConfirmedRemovals(Set(reloaded.map(\.target)))
        #expect(await reopened.read(key: key) == nil)
        let profileBytes = Data("{\"posts\":[{\"postID\":120001,\"thread\":{\"threadID\":100001}}]}".utf8)
        #expect(await reopened.write(profileBytes, key: "profile-v1:fixture:42:replies:1:0", epoch: 0) == false)
    }
    @Test func deletingAReplyOutsideInlinePreviewUpdatesParentCountOnce() throws {
        let seed = FixtureThreadSeed(threadID: 100_001, title: "Fixture", forumName: "Fixture", authorName: "Fixture",
                                     replyCount: 40, imageResources: [])
        let snapshot = FixtureThreadReaderPages.firstPage(from: seed)
        let reader = ThreadReaderStore(threadID: seed.threadID, repository: FixtureThreadReaderRepository(), initialSnapshot: snapshot)
        reader.listPresentation = .init(snapshot: snapshot, pagination: .end, presentedAt: Date(timeIntervalSince1970: 10))
        let visibility = ContentRemovalVisibility.shared
        visibility.update([])
        defer { visibility.update([]) }
        let target = ContentActionTarget(kind: .subpost, threadID: seed.threadID, postID: 999_999, parentPostID: 120_001)
        visibility.update([.init(target: target, date: Date(timeIntervalSince1970: 11))])
        let parent = try #require(reader.configuredRows(textSize: .standard).first { $0.row.post?.source.postID == 120_001 }?.row.post)
        #expect(parent.inlineSubposts.count == 2)
        #expect(parent.totalSubpostCount == 3 && parent.remainingSubpostCount == 1)
        let repeated = reader.configuredRows(textSize: .standard).first { $0.row.post?.source.postID == 120_001 }?.row.post
        #expect(repeated?.totalSubpostCount == 3)
        // A freshly read server total is authoritative, even if another reply kept it unchanged.
        reader.listPresentation = .init(snapshot: snapshot, pagination: .end, presentedAt: Date(timeIntervalSince1970: 12))
        let refreshed = reader.configuredRows(textSize: .standard).first { $0.row.post?.source.postID == 120_001 }?.row.post
        #expect(refreshed?.totalSubpostCount == 4)
        let policy = ContentRemovalCachePolicy(targets: [target], dates: visibility.dates)
        func cached(_ date: TimeInterval) throws -> Data {
            try JSONEncoder().encode(CachedReadingPage(locator: ReadingPageLocator(page: 1, postID: 0),
                                                       fetchedAt: Date(timeIntervalSince1970: date), value: snapshot))
        }
        #expect(try !policy.allows(cached(10), key: "fixture|thread-v1|100001|thread|all-ascending|pn:1|pid:0|body"))
        #expect(try policy.allows(cached(12), key: "fixture|thread-v1|100001|thread|all-ascending|pn:1|pid:0|body"))
    }
}
