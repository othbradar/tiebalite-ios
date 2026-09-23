struct RecentForum: Identifiable, Equatable, Sendable {
    static let maximumCount = 20

    let id: Int64
    let route: ForumRoute
    let avatarResource: ImageResourceDescriptor?

    var name: String { route.forumName.rawValue }

    static func project(
        _ history: [BrowsingHistoryEntry],
        followedForums: [FollowedForum]
    ) -> [RecentForum] {
        var avatars: [Int64: ImageResourceDescriptor] = [:]
        for forum in followedForums where avatars[forum.forumID] == nil {
            avatars[forum.forumID] = forum.avatarResource
        }
        var seen = Set<Int64>()
        return Array(history.sorted { $0.visitedAt > $1.visitedAt }.compactMap { entry in
            guard case let .forum(route) = entry.destination,
                  let forumID = route.forumID?.rawValue, forumID > 0,
                  seen.insert(forumID).inserted else { return nil }
            return RecentForum(
                id: forumID,
                route: route,
                avatarResource: TiebaAvatarResource.forum(
                    forumID: forumID, avatar: entry.forumAvatarResourceID
                ) ?? avatars[forumID]
            )
        }.prefix(maximumCount))
    }
}
