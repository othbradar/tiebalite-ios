#if DEBUG
import Foundation

actor FixtureProfileContentRepository: ProfileContentRepository {
    func cached(_ route: ProfileListRoute, scope: ContentCacheContext) async -> ProfileContentPage? { nil }
    func load(_ route: ProfileListRoute, cursor: ProfileCursor?, scope: ContentCacheContext) async throws -> ProfileContentPage {
        let page = cursor?.page ?? 1
        guard route.section != .replies || route.user.userID.rawValue == 12_001 else { throw ProfileContentFailure.privateContent }
        if route.section == .forums {
            // The first ordinary fixture thread's author has no viewable forum list.
            if route.user.userID.rawValue == 1_100_001 {
                return try NativeProfileProtocol.forums(Data(#"{"error_code":"0","ctime":0,"time":0}"#.utf8), cursor: cursor)
            }
            let bytes = Data("""
            {"error_code":"0","has_more":0,
             "forum_list":[{"id":"13001","name":"开源开发","member_count":10,"level_id":7}]}
            """.utf8)
            return try NativeProfileProtocol.forums(bytes, cursor: cursor)
        }
        let posts = (0..<20).compactMap { index -> ProfilePost? in
            let offset = (page - 1) * 20 + index
            let seeds = FixtureReadingCatalog.allThreadSeeds
            guard seeds.indices.contains(offset) else { return nil }
            let id = seeds[offset].threadID
            let pid = id + 30_000
            return .init(id: route.section == .replies ? pid : id, postID: route.section == .replies ? pid : nil,
                         summary: .init(itemID: id, threadID: id, title: "示例\(route.section.title) \(id)",
                                        summary: "固定测试内容", forumName: "示例吧", authorName: route.user.fallbackDisplayName,
                                        replyCount: 5, viewCount: 10, isPinned: false,
                                        author: .init(rawUserID: route.user.userID.rawValue, displayName: route.user.fallbackDisplayName)))
        }
        return .init(posts: posts, forums: [], next: page == 1 ? .init(page: 2, lastThreadTime: nil) : nil)
    }
    func relationship(_ user: UserProfileRoute, scope: ContentCacheContext) async throws -> ProfileRelationship {
        .init(userID: user.userID.rawValue, portrait: "fixture", isFollowed: false)
    }
    func setFollowing(_ followed: Bool, user: UserProfileRoute, portrait: String, scope: ContentCacheContext) async throws {}
    func invalidate(userID: Int64, scope: ContentCacheContext) async {}
}
#endif
