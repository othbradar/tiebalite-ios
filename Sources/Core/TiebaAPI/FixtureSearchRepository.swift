struct FixtureSearchRepository: SearchRepository {
    func search(_ query: SearchQuery) async throws -> SearchSnapshot {
        try Task.checkCancellation()
        guard query.scope == .global else { throw SearchWebProtocolError.unsupportedScope }
        return SearchSnapshot(
            query: query,
            forums: Self.forums,
            threads: Self.pages(for: query.sort)[0],
            users: Self.users,
            currentThreadPage: 1,
            hasMoreThreads: Self.threadPages.count > 1
        )
    }

    func loadThreadPage(
        _ request: SearchThreadPageRequest
    ) async throws -> ThreadSearchPage {
        try Task.checkCancellation()
        guard request.query.scope == .global else { throw SearchWebProtocolError.unsupportedScope }
        let index = request.page - 1
        guard Self.threadPages.indices.contains(index) else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return ThreadSearchPage(
            items: Self.pages(for: request.query.sort)[index],
            currentPage: request.page,
            hasMore: index + 1 < Self.threadPages.count
        )
    }

    private static let users: [UserSearchResult] = (1...24).compactMap { index in
        guard let route = UserProfileRoute(userID: Int64(14_000 + index), fallbackDisplayName: "Fixture 用户 \(index)") else {
            return nil
        }
        return UserSearchResult(route: route, introduction: index.isMultiple(of: 2) ? "用于验证搜人及主页返回位置。" : nil,
                                isExactMatch: index == 1)
    }

    private static let forums = [
        ForumSearchResult(
            forumID: 13_001,
            name: "Swift开发",
            displayName: "Swift 开发吧",
            summary: "学习 Swift 与 Apple 平台开发的 Fixture 吧。",
            memberCountText: "123456",
            postCountText: "456789",
            isExactMatch: true
        ),
        ForumSearchResult(
            forumID: 13_002,
            name: "摄影练习",
            displayName: "摄影练习吧",
            summary: "固定的离线搜索结果。",
            memberCountText: "1200",
            postCountText: "3400"
        )
    ] + (3...12).map { index in
        ForumSearchResult(forumID: Int64(13_000 + index), name: "Fixture吧\(index)", displayName: "Fixture 吧 \(index)",
                          summary: "用于验证搜索类型切换后位置保持。", memberCountText: "1200", postCountText: "3400")
    }

    private static let threadPages = [
        [2, 5, 0, 1, 3, 4].map { makeThread(seed: FixtureReadingCatalog.recommendationSeeds[$0]) },
        [5, 11, 6, 7, 8, 9, 10].map { makeThread(seed: FixtureReadingCatalog.recommendationSeeds[$0]) }
    ]

    private static func pages(for sort: SearchSort) -> [[ThreadSearchResult]] {
        switch sort {
        case .newest: threadPages
        case .oldest: threadPages.reversed().map { Array($0.reversed()) }
        case .relevance: threadPages.map { Array($0.dropFirst()) + $0.prefix(1) }
        }
    }

    private static func makeThread(
        seed: FixtureThreadSeed
    ) -> ThreadSearchResult {
        ThreadSearchResult(
            threadID: seed.threadID,
            title: seed.title,
            summary: "Fixture 搜索摘要",
            forumID: 13_001,
            forumName: seed.forumName,
            authorName: seed.authorName,
            replyCount: Int(seed.replyCount),
            timeUnixSeconds: 1_700_000_000, likeCount: 7, shareCount: 0
        )
    }
}
