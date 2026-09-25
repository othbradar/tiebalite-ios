import Foundation

enum NotificationKind: String, CaseIterable, Hashable, Sendable {
    case replies, mentions
    var title: String { self == .replies ? "回复我的" : "提到我的" }
    var path: String { self == .replies ? "/c/u/feed/replyme" : "/c/u/feed/atme" }
}

struct NotificationTarget: Codable, Hashable, Sendable {
    let threadID: Int64
    let postID: Int64
    let isSubpost: Bool
}

struct TiebaNotification: Identifiable, Equatable, Sendable {
    let id: String
    let author: TiebaUserVisuals
    let createdAt: Date?
    let content: String
    let quote: String
    let target: NotificationTarget
}

struct NotificationPage: Equatable, Sendable {
    let items: [TiebaNotification]
    let nextPage: Int?
}

struct NotificationCounts: Equatable, Sendable {
    let replies: Int
    let mentions: Int
    var total: Int { replies.addingReportingOverflow(mentions).overflow ? Int.max : replies + mentions }
    static let zero = NotificationCounts(replies: 0, mentions: 0)
}

protocol NotificationsRepository: Sendable {
    func load(kind: NotificationKind, page: Int, context: AuthContext) async throws -> NotificationPage
    func unread(context: AuthContext) async throws -> NotificationCounts
}

struct UnavailableNotificationsRepository: NotificationsRepository {
    func load(kind: NotificationKind, page: Int, context: AuthContext) async throws -> NotificationPage {
        throw EndpointExecutionError.transport(.unavailable)
    }
    func unread(context: AuthContext) async throws -> NotificationCounts { throw EndpointExecutionError.transport(.unavailable) }
}
