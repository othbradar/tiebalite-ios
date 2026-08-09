struct FixtureForumHomeRepository: ForumHomeRepository {
    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        try Task.checkCancellation()
        guard request.pageNumber == 1 else {
            throw FixtureReadingRepositoryError.unavailable
        }
        let route = request.route
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
                isPinned: index < 2,
                mediaCount: seed.imageResources.count,
                hasVideo: false
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

#if DEBUG
actor DebugStage14PLongForumFixtureRepository: ForumHomeRepository {
    private let totalThreadCount: Int
    private let pageSize: Int
    private let failOnceOnPage: Int?
    private var failedPages: Set<Int> = []
    private var requestedPages: [Int] = []

    init(
        totalThreadCount: Int = 1_000,
        pageSize: Int = 100,
        failOnceOnPage: Int? = nil
    ) {
        self.totalThreadCount = max(0, totalThreadCount)
        self.pageSize = max(1, pageSize)
        self.failOnceOnPage = failOnceOnPage
    }

    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        try Task.checkCancellation()
        requestedPages.append(request.pageNumber)
        if request.pageNumber == failOnceOnPage,
           failedPages.insert(request.pageNumber).inserted {
            throw FixtureReadingRepositoryError.unavailable
        }

        let start = max(0, (request.pageNumber - 1) * pageSize)
        let end = min(totalThreadCount, start + pageSize)
        let threads = start < end
            ? (start..<end).map { makeThread(index: $0, route: request.route) }
            : []
        return ForumHomeSnapshot(
            forum: ForumSummary(
                forumID: request.route.forumID?.rawValue,
                name: request.route.forumName.rawValue,
                slogan: "1000 帖、10 页的 Debug-only 长列表 Fixture。",
                avatarResourceID: nil,
                memberCount: 100_000,
                threadCount: totalThreadCount,
                postCount: totalThreadCount * 12
            ),
            threads: threads,
            currentPage: request.pageNumber,
            hasMore: end < totalThreadCount
        )
    }

    func requestedPageNumbers() -> [Int] {
        requestedPages
    }

    private func makeThread(
        index: Int,
        route: ForumRoute
    ) -> ForumThreadSummary {
        let mediaCount: Int
        switch index % 4 {
        case 1:
            mediaCount = 1
        case 2:
            mediaCount = 4
        default:
            mediaCount = 0
        }
        let longText = index.isMultiple(of: 7)
            ? "这是一段用于验证五行摘要上限、动态高度和 Cell 复用稳定性的较长固定文本。"
            : "预计算摘要 \(index + 1)"
        return ForumThreadSummary(
            itemID: Int64(890_000 + index),
            threadID: Int64(990_000 + index),
            title: index.isMultiple(of: 9)
                ? "长标题 Fixture \(index + 1)：验证大量帖子快速滚动时排版仍然稳定"
                : "性能 Fixture 帖子 \(index + 1)",
            summary: longText,
            forumName: route.forumName.rawValue,
            authorName: "Fixture 作者 \((index % 31) + 1)",
            replyCount: Int32(index % 10_000),
            viewCount: Int32((index * 17) % 100_000),
            isPinned: index < 3,
            mediaCount: mediaCount,
            hasVideo: mediaCount == 0 && index.isMultiple(of: 11)
        )
    }
}
#endif
