import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
actor R05ForumFixture: ForumHomeRepository {
    private var requests: [ForumHomePageRequest] = []
    private let tracksRefreshes: Bool

    init(tracksRefreshes: Bool = false) { self.tracksRefreshes = tracksRefreshes }

    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        try Task.checkCancellation()
        requests.append(request)
        let base = try await FixtureForumHomeRepository().loadForumHome(route: request.route)
        let marker: String = switch request.query {
        case .latest(.lastReply): "回复排序"
        case .latest(.creation): "发帖排序"
        case let .good(id): "精华\(id)"
        case let .category(category, sort): "\(category.title)\(sort)"
        }
        let refreshCount = requests.filter { $0.pageNumber == 1 && $0.query == request.query }.count
        let refreshMarker = tracksRefreshes ? "刷新\(refreshCount) · " : ""
        let forum = ForumSummary(
            forumID: base.forum.forumID, name: base.forum.name, slogan: nil,
            avatarResourceID: "https://fixture.invalid/forum.png",
            memberCount: 12_345, threadCount: 6_789, postCount: 89_012, levelID: 12, levelName: "固定样本",
            navigation: ForumNavigation(
                categories: [.init(id: 21, title: "吧友互助", isDefault: 0, sorts: []),
                             .init(id: 22, title: "技术讨论", isDefault: 0, sorts: [.init(id: 0, title: "最新")])],
                goodCategories: [.init(id: 0, title: "全部"), .init(id: 7, title: "精华资料")],
                ruleTitle: request.query == .latest(.lastReply) ? "Fixture 吧规 · 阅读交流守则" : nil
            ),
            membership: .init(currentScore: 65, levelUpScore: 100, isFollowed: true, signedDays: 12)
        )
        let threads = base.threads.enumerated().map { index, thread in
            let id = thread.threadID + Int64((request.pageNumber - 1) * 100)
            let count = index == 2 ? 8 : index == 3 ? 1 : 0
            return ForumThreadSummary(
                itemID: id - 100, threadID: id, title: refreshMarker + marker + " · " + thread.title,
                summary: "这是用于分类切换与阅读位置验证的固定摘要。", forumName: thread.forumName,
                authorName: thread.authorName, replyCount: thread.replyCount, viewCount: 123,
                isPinned: request.pageNumber == 1 && index < 2 && request.query == .latest(.lastReply),
                mediaCount: count, thumbnailResources: (0..<count).map {
                    ImageResourceDescriptor(resourceID: "forum.t\(id).media.\($0 + 1)")
                },
                author: .init(rawUserID: id, displayName: thread.authorName, portrait: "r05.fixture.\(id)", levelID: 8),
                metadata: .init(timeUnixSeconds: 1_700_000_000, agreeCount: 16, shareCount: 1)
            )
        }
        return ForumHomeSnapshot(forum: forum, threads: threads, currentPage: request.pageNumber,
                                 hasMore: request.pageNumber < 3, lastThreadID: threads.last?.itemID ?? 0)
    }

    func recordedRequests() -> [ForumHomePageRequest] { requests }
}
#endif
