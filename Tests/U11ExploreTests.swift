import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U11ExploreTests {
    @Test func switchingKeepsIndependentPagesAndAnchorsWithoutReloading() async {
        let repository = ExploreTestRepository()
        let following = ExploreFeedStore(feed: .following, repository: repository)
        let hot = ExploreFeedStore(feed: .hot, repository: repository)
        let scope = ContentCacheContext(namespace: "account-a", revision: 1)
        await following.activate(scope: scope)
        following.setAnchor(.thread(110))
        await hot.activate(scope: scope)
        await following.activate(scope: scope)
        #expect(await repository.calls == [.following, .hot])
        #expect(following.items.map(\.threadID) == [110, 111])
        #expect(hot.items.map(\.threadID) == [210, 211])
        #expect(following.anchor == 110)
        await following.loadMore()
        #expect(following.items.map(\.threadID) == [110, 111, 112])
        await hot.loadMore()
        #expect(await repository.calls == [.following, .hot, .following])
    }

    @Test func anonymousFollowingDoesNotRequestAndAccountChangeDropsOldContent() async {
        let repository = ExploreTestRepository()
        let store = ExploreFeedStore(feed: .following, repository: repository)
        await store.activate(scope: .anonymous)
        #expect(store.state == .loginRequired)
        #expect(await repository.calls.isEmpty)
        await store.activate(scope: .init(namespace: "a", revision: 1))
        store.setAnchor(.thread(111))
        store.reset(scope: .init(namespace: "b", revision: 2))
        #expect(store.items.isEmpty)
        #expect(store.anchor == nil)
        await store.activate(scope: .init(namespace: "b", revision: 2))
        #expect(await repository.scopes.map(\.namespace) == ["a", "b"])
    }

    @Test func refreshedContentWaitsForSafeViewportAndFailuresKeepRows() async throws {
        let repository = ExploreTestRepository()
        let store = ExploreFeedStore(feed: .following, repository: repository)
        await store.activate(scope: .init(namespace: "a", revision: 1))
        store.setAnchor(.thread(111))
        await store.refresh(automatic: true)
        let commit = try #require(store.pendingRefreshCommit)
        #expect(commit.takeRows(.dragging) == nil)
        #expect(commit.takeRows(.settled(isAtTop: false)) == nil)
        #expect(store.anchor == 111)
        #expect(commit.takeRows(.settled(isAtTop: true)) != nil)
        await repository.fail()
        await store.refresh()
        #expect(store.items.map(\.threadID) == [110, 111])
        #expect(store.state == .refreshFailure)
    }
}

actor ExploreTestRepository: ExploreFeedRepository {
    var calls: [ExploreFeed] = []
    var scopes: [ContentCacheContext] = []
    var fails = false
    func fail() { fails = true }
    func cached(_ feed: ExploreFeed, scope: ContentCacheContext) -> ExploreCachedPage? { nil }
    func invalidate(_ feed: ExploreFeed, scope: ContentCacheContext) {}
    func load(_ feed: ExploreFeed, cursor: ExploreCursor?, scope: ContentCacheContext) throws -> ExplorePage {
        calls.append(feed); scopes.append(scope)
        if fails { throw ExploreFailure.invalidData }
        let ids: [Int64] = cursor != nil ? [111, 112] : feed == .following ? [110, 111] : [210, 211]
        let items = ids.map {
            RecommendationSummary(threadID: $0, title: "测试帖子", forumName: "测试吧", authorName: "测试作者",
                                  replyCount: 0, thumbnail: nil)
        }
        return .init(items: items, next: feed == .following && cursor == nil ? .init(pageTag: "next", requestUnix: 1) : nil)
    }
}
