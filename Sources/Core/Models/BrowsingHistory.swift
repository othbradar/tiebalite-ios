import Foundation

enum BrowsingHistoryIdentity: Codable, Hashable, Sendable {
    case forum(Int64)
    case thread(Int64)
    case user(Int64)
}

enum BrowsingHistoryDestination: Codable, Equatable, Sendable {
    case forum(ForumRoute)
    case thread(ThreadID)
    case user(UserProfileRoute)
}

struct BrowsingHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let destination: BrowsingHistoryDestination
    let title: String
    let subtitle: String?
    let visitedAt: Date
    let visitCount: Int

    var id: BrowsingHistoryIdentity {
        identity
    }

    var identity: BrowsingHistoryIdentity {
        switch destination {
        case let .forum(route):
            return .forum(route.forumID?.rawValue ?? 0)
        case let .thread(threadID):
            return .thread(threadID.rawValue)
        case let .user(route):
            return .user(route.userID.rawValue)
        }
    }

    var route: RouteIdentity {
        switch destination {
        case let .forum(route):
            .forum(route)
        case let .thread(threadID):
            .thread(threadID)
        case let .user(route):
            .userProfile(route)
        }
    }

    static func thread(
        threadID: Int64,
        title: String,
        forumName: String?,
        visitedAt: Date
    ) throws -> Self {
        guard let validatedID = ThreadID(threadID) else {
            throw BrowsingHistoryError.invalidIdentity
        }
        return Self(
            destination: .thread(validatedID),
            title: normalizedTitle(title, fallback: "无标题帖子"),
            subtitle: nonempty(forumName).map { "\($0)吧" },
            visitedAt: visitedAt,
            visitCount: 1
        )
    }

    static func forum(
        forumID: Int64,
        forumName: String,
        visitedAt: Date
    ) throws -> Self {
        guard let route = ForumRoute(
            forumID: forumID,
            forumName: forumName
        ) else {
            throw BrowsingHistoryError.invalidIdentity
        }
        return Self(
            destination: .forum(route),
            title: "\(route.forumName.rawValue)吧",
            subtitle: "贴吧",
            visitedAt: visitedAt,
            visitCount: 1
        )
    }

    static func user(
        userID: Int64,
        displayName: String,
        portraitResourceID: String? = nil,
        visitedAt: Date
    ) throws -> Self {
        guard let route = UserProfileRoute(
            userID: userID,
            fallbackDisplayName: displayName,
            portraitResourceID: portraitResourceID
        ) else {
            throw BrowsingHistoryError.invalidIdentity
        }
        return Self(
            destination: .user(route),
            title: route.fallbackDisplayName,
            subtitle: "用户资料",
            visitedAt: visitedAt,
            visitCount: 1
        )
    }

    func revisited(with newest: Self) -> Self {
        Self(
            destination: newest.destination,
            title: newest.title,
            subtitle: newest.subtitle,
            visitedAt: newest.visitedAt,
            visitCount: visitCount + 1
        )
    }

    private static func normalizedTitle(
        _ value: String,
        fallback: String
    ) -> String {
        nonempty(value) ?? fallback
    }

    private static func nonempty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

enum BrowsingHistoryError: Error, Equatable, Sendable {
    case invalidIdentity
    case invalidSchema
}
