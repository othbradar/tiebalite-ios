#if DEBUG
actor FixtureExploreRepository: ExploreFeedRepository {
    func cached(_ feed: ExploreFeed, scope: ContentCacheContext) -> ExploreCachedPage? { nil }
    func invalidate(_ feed: ExploreFeed, scope: ContentCacheContext) {}
    func load(_ feed: ExploreFeed, cursor: ExploreCursor?, scope: ContentCacheContext) -> ExplorePage {
        let start: Int64 = feed == .following ? 100_000 : 100_020
        let range = cursor == nil ? 1...12 : 12...24
        return .init(items: range.map { index in
            .init(threadID: start + Int64(index), title: "\(feed.title)测试帖子 \(index)", forumName: "测试吧",
                  authorName: "\(feed.title)作者 \(index)", replyCount: Int32(index), thumbnail: nil,
                  author: .init(rawUserID: 300_000 + Int64(index), displayName: "测试作者", levelID: 5),
                  feed: .init(abstractText: "这是一条用于验证切换与阅读位置的合成帖子，来源为\(feed.title)。"))
        }, next: feed == .following && cursor == nil ? .init(pageTag: "following-next", requestUnix: 100) : nil)
    }
}
#endif
