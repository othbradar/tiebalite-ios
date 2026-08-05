struct FixtureFollowedForumsRepository: FollowedForumsRepository {
    func loadFollowedForums(
        authentication: AuthContext
    ) async throws -> [FollowedForum] {
        try Task.checkCancellation()
        guard case .active = authentication else {
            throw FollowedForumsRepositoryError.authenticationRequired
        }
        return Self.forums
    }

    private static let forums = [
        FollowedForum(
            forumID: 13_001,
            name: "Swift开发",
            avatarResourceID: "fixture://forum/swift",
            hotCount: 321,
            memberCount: 123_456,
            threadCount: 7_890,
            levelID: 8,
            levelName: "八级",
            isSignedToday: true
        ),
        FollowedForum(
            forumID: 13_002,
            name: "iOS技术",
            avatarResourceID: "fixture://forum/ios",
            hotCount: 210,
            memberCount: 65_432,
            threadCount: 4_321,
            levelID: 5,
            levelName: "五级",
            isSignedToday: false
        ),
        FollowedForum(
            forumID: 13_003,
            name: "开源软件",
            avatarResourceID: nil,
            hotCount: 99,
            memberCount: 24_680,
            threadCount: 1_357,
            levelID: nil,
            levelName: nil,
            isSignedToday: false
        )
    ]
}
