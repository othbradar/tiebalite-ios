import Foundation

enum ProfileSection: String, Codable, CaseIterable, Sendable {
    case threads, replies, forums
    var title: String {
        switch self {
        case .threads: "主题"
        case .replies: "回复"
        case .forums: "关注的吧"
        }
    }
}

struct ProfileListRoute: Codable, Hashable, Sendable {
    let user: UserProfileRoute
    let section: ProfileSection
}

struct ProfileCursor: Codable, Equatable, Sendable {
    let page: Int
    let lastThreadTime: UInt32?
}

struct ProfilePost: Equatable, Sendable, Identifiable {
    let id: Int64
    let postID: Int64?
    let summary: ForumThreadSummary
}

struct ProfileContentPage: Equatable, Sendable {
    let posts: [ProfilePost]
    let forums: [FollowedForum]
    let next: ProfileCursor?
}

struct ProfileRelationship: Equatable, Sendable {
    let userID: Int64
    let portrait: String?
    let isFollowed: Bool?
}

enum ProfileContentFailure: Error, Equatable, Sendable {
    case invalidData, loginRequired, privateContent, contentUnavailable, identityUnavailable, relationshipUnavailable
}

protocol ProfileContentRepository: Sendable {
    func cached(_ route: ProfileListRoute, scope: ContentCacheContext) async -> ProfileContentPage?
    func load(_ route: ProfileListRoute, cursor: ProfileCursor?, scope: ContentCacheContext) async throws -> ProfileContentPage
    func relationship(_ user: UserProfileRoute, scope: ContentCacheContext) async throws -> ProfileRelationship
    func setFollowing(_ followed: Bool, user: UserProfileRoute, portrait: String, scope: ContentCacheContext) async throws
    func invalidate(userID: Int64, scope: ContentCacheContext) async
}

struct BlockedProfile: Codable, Equatable, Sendable, Identifiable {
    let id: Int64
    let name: String
}
