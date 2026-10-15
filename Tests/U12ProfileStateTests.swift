import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U12ProfileStateTests {
    private let scope = ContentCacheContext(namespace: "fixture-a", revision: 1)
    private var user: UserProfileRoute { get throws { try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture")) } }

    @Test func independentSubpagesKeepAnchorsAndRawCursorWhenAllRowsAreBlocked() async throws {
        let repository = ProfileStateRepository()
        let details = ProfileDetailsStore(user: try user, repository: repository, context: { scope }, accountID: { 9 })
        let threads = details.list(.threads), forums = details.list(.forums)
        await threads.activate()
        threads.setAnchor(.post(111))
        await forums.activate()
        await threads.activate()
        #expect(await repository.reads == [.threads, .forums])
        #expect(threads.anchor == .post(111))
        threads.setBlocked([42])
        #expect(threads.posts.count == 2)
        #expect(threads.rows.count == 1)
        #expect(threads.next?.page == 2)
        await threads.loadMore()
        #expect(threads.next == nil)
        #expect(threads.posts.count == 3)
        threads.setBlocked([])
        #expect(threads.rows.count == 4)
        #expect(threads.anchor == .post(111))
    }

    @Test func permissionDenialHidesPreviouslyLoadedContent() async throws {
        let repository = ProfileStateRepository()
        let store = ProfileListStore(route: .init(user: try user, section: .threads), repository: repository, context: { scope })
        await store.activate()
        #expect(!store.posts.isEmpty)
        await repository.deny()
        await store.refresh()
        #expect(store.state == .privateContent)
        #expect(store.posts.isEmpty && store.rows.isEmpty && store.next == nil)
    }

    @Test func followingFailureRollsBackAndDuplicateTapDoesNotSubmitTwice() async throws {
        let repository = ProfileStateRepository()
        let details = ProfileDetailsStore(user: try user, repository: repository, context: { scope }, accountID: { 9 })
        await details.activate()
        let operation = Task { await details.toggleFollowing() }
        await repository.waitForWrite()
        #expect(details.changingFollow)
        #expect(details.relationship?.isFollowed == true)
        await details.toggleFollowing()
        #expect(await repository.writes == 1)
        await repository.finishWrite(success: false)
        await operation.value
        #expect(details.followFailed)
        #expect(details.relationship?.isFollowed == false)
        #expect(!details.changingFollow)
    }

    @Test func accountChangeRejectsLateFollowResultAndReloadsRelationship() async throws {
        let repository = ProfileStateRepository()
        let current = ProfileScopeBox(scope)
        let details = ProfileDetailsStore(user: try user, repository: repository, context: { current.value }, accountID: { 9 })
        await details.activate()
        let operation = Task { await details.toggleFollowing() }
        await repository.waitForWrite()
        current.value = .init(namespace: "fixture-b", revision: 2)
        await details.activate()
        await repository.finishWrite(success: true)
        await operation.value
        #expect(details.relationship?.isFollowed == false)
        #expect(!details.changingFollow)
        #expect(await repository.relationScopes == ["fixture-a", "fixture-b"])
    }

    @Test func localBlockingPersistsAndRemainsAccountScoped() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalBlockingRepository(directory: directory)
        let entry = BlockedProfile(id: 42, name: "Fixture")
        _ = try await repository.set(entry, blocked: true, namespace: "fixture-a")
        let restored = LocalBlockingRepository(directory: directory)
        #expect(try await restored.load(namespace: "fixture-a") == [entry])
        #expect(try await restored.load(namespace: "fixture-b").isEmpty)
        _ = try await restored.set(entry, blocked: false, namespace: "fixture-a")
        #expect(try await restored.load(namespace: "fixture-a").isEmpty)
    }

    @Test func profileNavigationReusesExistingReaderAndForumPaths() throws {
        let list = ProfileListRoute(user: try user, section: .threads)
        let routes: [RouteIdentity] = [.userProfile(try user), .profileList(list), .thread(try #require(ThreadID(110)))]
        #expect(RouteGrammar.isValid(routes, for: .recommendations))
        #expect(SettingsRouteGrammar.canonical([.accountProfile, .content(.profileList(.init(user: try user, section: .replies))),
                                                .content(.profileReply(.init(threadID: 110, postID: 111))) ]).count == 3)
        let other = try #require(UserProfileRoute(userID: 43, fallbackDisplayName: "Other"))
        #expect(!RouteGrammar.permitsContentAction(from: .userProfile(other), to: .profileList(list)))
        let thread = try #require(ThreadID(110)), post = try #require(PostID(111))
        let forum = try #require(ForumRoute(forumID: 9, forumName: "Fixture"))
        let deep: [RouteIdentity] = [.forum(forum), .thread(thread), .subposts(threadID: thread, postID: post),
                                     .userProfile(try user), .profileList(list), .thread(try #require(ThreadID(112)))]
        #expect(RouteGrammar.isValid(deep, for: .followedForums))
        #expect(SettingsRouteGrammar.canonical([.history] + deep.map(SettingsRoute.content)).count == 7)
    }

    @Test func localFilteringKeepsReaderSnapshotAndCachedNormalProjection() async throws {
        let visibility = LocalUserVisibility.shared, originalIDs = LocalUserVisibility.shared.ids
        visibility.update([])
        defer { visibility.update(originalIDs) }
        let store = ThreadReaderStore(threadID: 100_001, repository: FixtureThreadReaderRepository())
        await store.loadIfNeeded()
        let snapshot = try #require(store.state.snapshot)
        let first = store.configuredRows(textSize: .standard)
        #expect(store.configuredRows(textSize: .standard) == first)
        #expect(store.configuredRowsBuildCount == 1)
        let target = try #require(snapshot.posts.last)
        visibility.update([target.author.rawUserID])
        let filtered = store.configuredRows(textSize: .standard)
        #expect(filtered.count == first.count - 1)
        #expect(store.state.snapshot == snapshot)
        visibility.update([])
        #expect(store.configuredRows(textSize: .standard) == first)
        store.cancel()
    }
}

actor ProfileStateRepository: ProfileContentRepository {
    private(set) var reads: [ProfileSection] = []
    private(set) var writes = 0
    private(set) var relationScopes: [String?] = []
    private var continuation: CheckedContinuation<Void, any Error>?
    private var writeWaiter: CheckedContinuation<Void, Never>?
    private var denied = false
    func deny() { denied = true }
    func cached(_ route: ProfileListRoute, scope: ContentCacheContext) async -> ProfileContentPage? { nil }
    func load(_ route: ProfileListRoute, cursor: ProfileCursor?, scope: ContentCacheContext) async throws -> ProfileContentPage {
        reads.append(route.section)
        if denied { throw ProfileContentFailure.privateContent }
        if route.section == .forums { return .init(posts: [], forums: [], next: nil) }
        let ids: [Int64] = cursor == nil ? [110, 111] : [111, 112]
        return .init(posts: ids.map { id in
            .init(id: id, postID: id, summary: .init(itemID: id, threadID: id, title: "Fixture", forumName: "Fixture",
                                                     authorName: "Fixture", replyCount: 0, viewCount: 0, isPinned: false,
                                                     author: .init(rawUserID: 42, displayName: "Fixture")))
        }, forums: [], next: cursor == nil ? .init(page: 2, lastThreadTime: nil) : nil)
    }
    func relationship(_ user: UserProfileRoute, scope: ContentCacheContext) async throws -> ProfileRelationship {
        relationScopes.append(scope.namespace)
        return .init(userID: user.userID.rawValue, portrait: "fixture", isFollowed: false)
    }
    func setFollowing(_ followed: Bool, user: UserProfileRoute, portrait: String, scope: ContentCacheContext) async throws {
        writes += 1
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation; writeWaiter?.resume(); writeWaiter = nil
        }
    }
    func waitForWrite() async {
        if continuation != nil { return }
        await withCheckedContinuation { writeWaiter = $0 }
    }
    func finishWrite(success: Bool) {
        let value = continuation; continuation = nil
        if success { value?.resume() } else { value?.resume(throwing: ProfileContentFailure.relationshipUnavailable) }
    }
    func invalidate(userID: Int64, scope: ContentCacheContext) async {}
}

@MainActor final class ProfileScopeBox {
    var value: ContentCacheContext
    init(_ value: ContentCacheContext) { self.value = value }
}
