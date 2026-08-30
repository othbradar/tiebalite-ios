import Foundation

struct UserID: Codable, Hashable, Sendable {
    let rawValue: Int64

    init?(_ value: Int64) {
        guard value > 0 else {
            return nil
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid user ID"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct UserProfileRoute: Codable, Hashable, Sendable {
    let userID: UserID
    let fallbackDisplayName: String
    let portraitResourceID: String?

    init?(
        userID: Int64,
        fallbackDisplayName: String,
        portraitResourceID: String? = nil
    ) {
        guard let validatedID = UserID(userID) else {
            return nil
        }
        self.userID = validatedID
        self.fallbackDisplayName = Self.normalizedName(fallbackDisplayName)
        self.portraitResourceID = Self.nonempty(portraitResourceID)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.userID == rhs.userID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(userID)
    }

    private static func normalizedName(_ value: String) -> String {
        nonempty(value) ?? "未知用户"
    }

    private static func nonempty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

enum UserProfileSex: String, Codable, Equatable, Sendable {
    case female
    case male
}

struct UserProfile: Equatable, Sendable {
    let userID: UserID
    let displayName: String
    let portraitResourceID: String?
    let introduction: String?
    let sex: UserProfileSex?
    let followingCount: Int?
    let followerCount: Int?
    let postCount: Int?
    let threadCount: Int?
    let totalAgreeCount: Int?
    let displayTiebaID: String?
}

protocol UserProfileRepository: Sendable {
    func loadProfile(route: UserProfileRoute) async throws -> UserProfile
}

enum UserProfileRepositoryError: Error, Equatable, Sendable {
    case empty
}

struct FixtureUserProfileRepository: UserProfileRepository {
    func loadProfile(route: UserProfileRoute) async throws -> UserProfile {
        try Task.checkCancellation()
        return UserProfile(
            userID: route.userID,
            displayName: route.fallbackDisplayName,
            portraitResourceID: route.portraitResourceID,
            introduction: "这是用于离线导航验证的 Fixture 用户资料。",
            sex: nil,
            followingCount: 12,
            followerCount: 34,
            postCount: nil,
            threadCount: nil,
            totalAgreeCount: 56,
            displayTiebaID: nil
        )
    }
}
