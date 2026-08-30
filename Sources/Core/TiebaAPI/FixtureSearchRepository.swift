struct FixtureSearchRepository: SearchRepository {
    func search(keyword: SearchKeyword) async throws -> SearchSnapshot {
        try Task.checkCancellation()
        return SearchSnapshot(
            keyword: keyword,
            forums: Self.forums,
            threads: Self.threadPages[0],
            currentThreadPage: 1,
            hasMoreThreads: Self.threadPages.count > 1
        )
    }

    func loadThreadPage(
        _ request: SearchThreadPageRequest
    ) async throws -> ThreadSearchPage {
        try Task.checkCancellation()
        let index = request.page - 1
        guard Self.threadPages.indices.contains(index) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return ThreadSearchPage(
            items: Self.threadPages[index],
            currentPage: request.page,
            hasMore: index + 1 < Self.threadPages.count
        )
    }

    private static let forums = [
        ForumSearchResult(
            forumID: 13_001,
            name: "Swift开发",
            displayName: "Swift 开发吧",
            summary: "学习 Swift 与 Apple 平台开发的 Fixture 吧。",
            memberCountText: "123456",
            postCountText: "456789"
        ),
        ForumSearchResult(
            forumID: 13_002,
            name: "摄影练习",
            displayName: "摄影练习吧",
            summary: "固定的离线搜索结果。",
            memberCountText: "1200",
            postCountText: "3400"
        )
    ]

    private static let threadPages = [
        [
            makeThread(seed: FixtureReadingCatalog.recommendationSeeds[2]),
            makeThread(seed: FixtureReadingCatalog.recommendationSeeds[5])
        ],
        [
            makeThread(seed: FixtureReadingCatalog.recommendationSeeds[5]),
            makeThread(seed: FixtureReadingCatalog.recommendationSeeds[11])
        ]
    ]

    private static func makeThread(
        seed: FixtureThreadSeed
    ) -> ThreadSearchResult {
        ThreadSearchResult(
            threadID: seed.threadID,
            title: seed.title,
            summary: "Fixture 搜索摘要",
            forumID: nil,
            forumName: seed.forumName,
            authorName: seed.authorName,
            replyCount: Int(seed.replyCount)
        )
    }
}
