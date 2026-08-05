struct FixtureForumHomeRepository: ForumHomeRepository {
    func loadForumHome(route: ForumRoute) async throws -> ForumHomeSnapshot {
        try Task.checkCancellation()
        let forumName = route.forumName.rawValue
        let seeds = FixtureReadingCatalog.forumThreadSeeds(for: route)
        let threads = seeds.enumerated().map { index, seed in
            ForumThreadSummary(
                itemID: seed.threadID - 126_000,
                threadID: seed.threadID,
                title: seed.title,
                forumName: forumName,
                authorName: seed.authorName,
                replyCount: seed.replyCount,
                viewCount: Int32(200 + index * 37),
                isPinned: index < 2
            )
        }
        return ForumHomeSnapshot(
            forum: ForumSummary(
                forumID: route.forumID?.rawValue,
                name: forumName,
                slogan: "一个用于学习 Swift 与 Apple 平台开发的 Fixture 吧首页。",
                avatarResourceID: nil,
                memberCount: 123_456,
                threadCount: 7_890,
                postCount: 456_789
            ),
            threads: threads
        )
    }
}
