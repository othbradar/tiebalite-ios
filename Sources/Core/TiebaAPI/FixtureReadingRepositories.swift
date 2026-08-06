import Foundation

enum FixtureReadingRepositoryError: Error, Equatable, Sendable {
    case threadNotFound
    case unavailable
}

struct FixtureRecommendationRepository: RecommendationRepository {
    func loadRecommendations() async throws -> [RecommendationSummary] {
        try Task.checkCancellation()
        return FixtureReadingCatalog.recommendationSeeds.map(\.recommendation)
    }
}

struct FixtureThreadReaderRepository: ThreadReaderRepository {
    private let failsNextPage: Bool

    init(failsNextPage: Bool = false) {
        self.failsNextPage = failsNextPage
    }

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        try Task.checkCancellation()
        guard let seed = FixtureReadingCatalog.allThreadSeeds.first(where: {
            $0.threadID == request.threadID
        }) else {
            throw FixtureReadingRepositoryError.threadNotFound
        }
        switch request.pageNumber {
        case 0:
            return FixtureThreadReaderPages.firstPage(from: seed)
        case 2:
            guard request.postID == FixtureThreadReaderPages.nextPostID(
                for: seed
            ) else {
                throw FixtureReadingRepositoryError.unavailable
            }
            if failsNextPage {
                throw FixtureReadingRepositoryError.unavailable
            }
            return FixtureThreadReaderPages.secondPage(from: seed)
        default:
            throw FixtureReadingRepositoryError.unavailable
        }
    }
}

enum FixtureReadingCatalog {
    static let recommendationSeeds: [FixtureThreadSeed] = [
        FixtureThreadSeed(
            threadID: 100_001,
            title: "把一个周末小项目整理成开源仓库的过程",
            forumName: "开源开发",
            authorName: "海边调试",
            replyCount: 18,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 100_002,
            title: "傍晚散步时拍到的一束光",
            forumName: "摄影练习",
            authorName: "光圈记录",
            replyCount: 6,
            imageResources: [FixtureReadingImageResource.orange]
        ),
        FixtureThreadSeed(
            threadID: 100_003,
            title: "城市漫步：三张照片记录从老街到河岸的傍晚",
            forumName: "城市漫步",
            authorName: "慢行者",
            replyCount: 24,
            imageResources: [
                FixtureReadingImageResource.blue,
                FixtureReadingImageResource.green,
                FixtureReadingImageResource.orange
            ]
        ),
        FixtureThreadSeed(
            threadID: 100_004,
            title: "这是一个用来确认超长标题在大字体和窄屏幕下仍然可以自然换行并且不会遮挡作者、吧名以及回复统计信息的固定演示帖子",
            forumName: "文字排版",
            authorName: "长标题测试",
            replyCount: 3,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 100_005,
            title: "今天读到的一句话",
            forumName: "随便聊聊",
            authorName: "清茶",
            replyCount: 0,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 100_006,
            title: "深色模式下的界面细节记录",
            forumName: "iOS开发",
            authorName: "夜航",
            replyCount: 42,
            imageResources: [FixtureReadingImageResource.blue]
        ),
        FixtureThreadSeed(
            threadID: 100_007,
            title: "一本短篇集的三则阅读笔记",
            forumName: "阅读笔记",
            authorName: "纸页",
            replyCount: 11,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 100_008,
            title: "大字体不仅是把字号放大：一次无障碍排版观察",
            forumName: "无障碍设计",
            authorName: "字号观察员",
            replyCount: 9,
            imageResources: [FixtureReadingImageResource.green]
        ),
        FixtureThreadSeed(
            threadID: 100_009,
            title: "固定失败图片占位是否仍然保持页面几何",
            forumName: "测试实验室",
            authorName: "红绿灯",
            replyCount: 5,
            imageResources: [FixtureReadingImageResource.fetchFailure]
        ),
        FixtureThreadSeed(
            threadID: 100_010,
            title: "两种宽高比的风景记录",
            forumName: "风景记录",
            authorName: "远山",
            replyCount: 13,
            imageResources: [
                FixtureReadingImageResource.orange,
                FixtureReadingImageResource.blue
            ]
        ),
        FixtureThreadSeed(
            threadID: 100_011,
            title: "最近用过的键盘布局集中讨论",
            forumName: "数码闲聊",
            authorName: "键帽",
            replyCount: 12_345,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 100_012,
            title: "列表末尾的返回位置验证帖",
            forumName: "路线验证",
            authorName: "回程",
            replyCount: 1,
            imageResources: [FixtureReadingImageResource.green]
        )
    ]

    static let forumThreadSeeds: [FixtureThreadSeed] = [
        FixtureThreadSeed(
            threadID: 140_001,
            title: "置顶：Swift 6 严格并发迁移经验汇总",
            forumName: "Swift开发",
            authorName: "并发实验室",
            replyCount: 48,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 140_002,
            title: "置顶：新人提问与资料索引",
            forumName: "Swift开发",
            authorName: "版务小组",
            replyCount: 26,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 140_003,
            title: "Observation 在中型 SwiftUI 项目里的实际用法",
            forumName: "Swift开发",
            authorName: "类型推导",
            replyCount: 19,
            imageResources: [FixtureReadingImageResource.blue]
        ),
        FixtureThreadSeed(
            threadID: 140_004,
            title: "一个可取消 Store 如何防止旧响应覆盖",
            forumName: "Swift开发",
            authorName: "Actor 信箱",
            replyCount: 12,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 140_005,
            title: "Swift Testing 的几个小型测试组织技巧",
            forumName: "Swift开发",
            authorName: "红绿循环",
            replyCount: 8,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 140_006,
            title: "用稳定业务 ID 恢复列表返回位置",
            forumName: "Swift开发",
            authorName: "路线记录员",
            replyCount: 15,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 140_007,
            title: "深色模式下卡片背景的一次排查",
            forumName: "Swift开发",
            authorName: "夜间构建",
            replyCount: 7,
            imageResources: []
        ),
        FixtureThreadSeed(
            threadID: 140_008,
            title: "吧首页返回位置 Fixture 验证帖",
            forumName: "Swift开发",
            authorName: "回程线",
            replyCount: 4,
            imageResources: []
        )
    ]

    static let iosForumThreadSeeds = remapForumThreadSeeds(
        baseThreadID: 150_000,
        forumName: "iOS技术"
    )

    static let openSourceForumThreadSeeds = remapForumThreadSeeds(
        baseThreadID: 160_000,
        forumName: "开源软件"
    )

    static func forumThreadSeeds(
        for route: ForumRoute
    ) -> [FixtureThreadSeed] {
        let forumID = route.forumID?.rawValue
        switch (forumID, route.forumName.rawValue) {
        case (13_001, "Swift开发"), (nil, "Swift开发"):
            return forumThreadSeeds
        case (13_002, "iOS技术"), (nil, "iOS技术"):
            return iosForumThreadSeeds
        case (13_003, "开源软件"), (nil, "开源软件"):
            return openSourceForumThreadSeeds
        default:
            return []
        }
    }

    static var allThreadSeeds: [FixtureThreadSeed] {
        recommendationSeeds
            + forumThreadSeeds
            + iosForumThreadSeeds
            + openSourceForumThreadSeeds
    }

    private static func remapForumThreadSeeds(
        baseThreadID: Int64,
        forumName: String
    ) -> [FixtureThreadSeed] {
        forumThreadSeeds.enumerated().map { index, seed in
            FixtureThreadSeed(
                threadID: baseThreadID + Int64(index) + 1,
                title: "\(forumName)：\(seed.title)",
                forumName: forumName,
                authorName: seed.authorName,
                replyCount: seed.replyCount,
                imageResources: seed.imageResources
            )
        }
    }

    static func snapshot(
        from seed: FixtureThreadSeed
    ) -> ThreadReaderSnapshot {
        FixtureThreadReaderPages.firstPage(from: seed)
    }
}

struct FixtureThreadSeed: Sendable {
    let threadID: Int64
    let title: String
    let forumName: String
    let authorName: String
    let replyCount: Int32
    let imageResources: [String]

    var author: ThreadReaderAuthor {
        ThreadReaderAuthor(
            rawUserID: threadID + 1_000_000,
            displayName: authorName
        )
    }

    var recommendation: RecommendationSummary {
        RecommendationSummary(
            threadID: threadID,
            title: title,
            forumName: forumName,
            authorName: authorName,
            replyCount: replyCount,
            thumbnail: imageResources.first.map {
                RecommendationThumbnail(
                    resourceID: $0,
                    alternativeText: "\(title) 的缩略图"
                )
            }
        )
    }
}
