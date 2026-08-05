struct FollowedForum: Identifiable, Equatable, Sendable {
    let forumID: Int64
    let name: String
    let avatarResourceID: String?
    let hotCount: Int
    let memberCount: Int
    let threadCount: Int
    let levelID: Int?
    let levelName: String?
    let isSignedToday: Bool

    var id: Int64 {
        forumID
    }
}

enum FollowedForumsRepositoryError: Error, Equatable, Sendable {
    case authenticationRequired
    case sessionExpired
}

protocol FollowedForumsRepository: Sendable {
    func loadFollowedForums(
        authentication: AuthContext
    ) async throws -> [FollowedForum]
}
