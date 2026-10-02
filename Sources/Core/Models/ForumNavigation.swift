import Foundation

enum ForumSortOrder: Int32, Codable, CaseIterable, Sendable {
    case lastReply = 0
    case creation = 1

    var title: String { self == .lastReply ? "最新回复" : "最新发布" }
}

struct ForumCategory: Codable, Hashable, Sendable, Identifiable {
    let id: Int32
    let title: String
    let isDefault: Int32
    let sorts: [ForumCategorySort]
}

struct ForumCategorySort: Codable, Hashable, Sendable, Identifiable {
    let id: Int32
    let title: String
}

struct ForumGoodCategory: Codable, Equatable, Sendable, Identifiable {
    let id: Int32
    let title: String
}

struct ForumNavigation: Codable, Equatable, Sendable {
    var categories: [ForumCategory] = []
    var goodCategories: [ForumGoodCategory] = []
    var ruleTitle: String?
}

struct ForumMembership: Codable, Equatable, Sendable {
    let currentScore: Int
    let levelUpScore: Int
    let isFollowed: Bool
    let signedDays: Int?

    var progress: Double? {
        guard isFollowed, currentScore >= 0, levelUpScore > 0 else { return nil }
        return min(1, Double(currentScore) / Double(levelUpScore))
    }
}

enum ForumPageID: Hashable, Sendable {
    case latest
    case good
    case category(Int32)

    var accessibilityKey: String {
        switch self {
        case .latest: "latest"
        case .good: "good"
        case let .category(id): "category.\(id)"
        }
    }
}

enum ForumThreadQuery: Equatable, Sendable {
    case latest(ForumSortOrder)
    case good(Int32)
    case category(ForumCategory, sort: Int32)
}

struct ForumThreadMetadata: Codable, Equatable, Sendable {
    var showsTitle = true
    var timeUnixSeconds: UInt32?
    var agreeCount: Int64?
    var shareCount: Int64?
}
