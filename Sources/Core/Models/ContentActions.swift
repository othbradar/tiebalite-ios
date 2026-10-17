import Foundation

struct ContentActionTarget: Hashable, Codable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable { case thread, post, subpost }
    let kind: Kind
    let threadID: Int64
    var postID: Int64 = 0
    var parentPostID: Int64 = 0
    var id: String { "\(kind.rawValue):\(threadID):\(postID)" }
    var deletionTitle: String {
        switch kind {
        case .thread: "删除主题"
        case .post: "删除此楼"
        case .subpost: "删除子回复"
        }
    }
    var deletionMessage: String {
        switch kind {
        case .thread: "将删除这个主题及其回复，无法撤销。"
        case .post: "将删除此楼及其楼中楼回复，无法撤销。"
        case .subpost: "将删除这条子回复，无法撤销。"
        }
    }
    var isValid: Bool { threadID > 0 && (kind == .thread || postID > 0) && (kind != .subpost || parentPostID > 0) }
    static func profile(threadID: Int64, postID: Int64?, section: ProfileSection) -> Self {
        .init(kind: section == .replies ? .post : .thread, threadID: threadID,
              postID: section == .replies ? postID ?? 0 : 0)
    }
}

struct ContentActionInspection: Equatable, Sendable {
    let target: ContentActionTarget
    let accountID: Int64
    let authorID: Int64
    let forumID: Int64
    let forumName: String
    let firstPostID: Int64
    let likeCount: Int64?
    let liked: Bool?
    /// Positive native ownership predicate, evaluated on a fresh authenticated
    /// response. Unknown, deleted, promoted or mismatching targets never grant it.
    let permitsOwnDeletion: Bool
    var canDelete: Bool { target.isValid && accountID > 0 && authorID == accountID && forumID > 0 && permitsOwnDeletion }
}

enum ContentActionFailure: Error, Equatable, Sendable {
    case loginRequired, unavailable, rejected, outcomeUnknown, storageUnavailable
}

@MainActor
protocol ContentActionRepository {
    func inspect(_ target: ContentActionTarget) async throws -> ContentActionInspection
    func like(_ inspection: ContentActionInspection, selected: Bool) async throws
    func delete(_ inspection: ContentActionInspection) async throws
}

struct ConfirmedContentRemoval: Codable, Equatable, Sendable {
    let target: ContentActionTarget
    let date: Date
}
