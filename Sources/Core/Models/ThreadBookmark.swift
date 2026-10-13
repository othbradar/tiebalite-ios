struct ThreadBookmarkTarget: Codable, Hashable, Sendable {
    let threadID: Int64
    let postID: Int64?
}

struct ThreadBookmark: Codable, Equatable, Identifiable, Sendable {
    let target: ThreadBookmarkTarget
    let title: String
    let forumName: String
    let floor: Int?
    var id: Int64 { target.threadID }
    var isValid: Bool { id > 0 && (target.postID.map { $0 > 0 } ?? true) && (floor.map { $0 > 0 } ?? true) }
}

enum BookmarkFailure: Error, Equatable { case accountUnavailable, storage, invalidData }

protocol BookmarkRepositoryProtocol: Sendable {
    func entries(account: String) async throws -> [ThreadBookmark]
    func save(_ entry: ThreadBookmark, account: String) async throws
    func remove(threadID: Int64, account: String) async throws
}
