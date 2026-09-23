import Foundation

enum ForumSortOrder: Int32, CaseIterable, Sendable {
    case lastReply = 0
    case creation = 1

    var title: String { self == .lastReply ? "按最后回复" : "按发帖时间" }
}

struct ForumCategory: Hashable, Sendable, Identifiable {
    let id: Int32
    let title: String
    let isDefault: Int32
    let sorts: [ForumCategorySort]
}

struct ForumCategorySort: Hashable, Sendable, Identifiable {
    let id: Int32
    let title: String
}

struct ForumGoodCategory: Equatable, Sendable, Identifiable {
    let id: Int32
    let title: String
}

struct ForumNavigation: Equatable, Sendable {
    var categories: [ForumCategory] = []
    var goodCategories: [ForumGoodCategory] = []
    var ruleTitle: String?
}

struct ForumMembership: Equatable, Sendable {
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

struct ForumThreadMetadata: Equatable, Sendable {
    var showsTitle = true
    var timeUnixSeconds: UInt32?
    var agreeCount: Int64?
    var shareCount: Int64?
}
