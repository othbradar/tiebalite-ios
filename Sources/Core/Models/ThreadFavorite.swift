struct ThreadFavorite: Equatable, Identifiable, Sendable {
    let target: ThreadBookmarkTarget
    let title: String
    let forumName: String
    let status: Int
    let isDeleted: Bool
    let feed: ForumThreadSummary?
    var id: Int64 { target.threadID }

    init(target: ThreadBookmarkTarget, title: String, forumName: String, status: Int, isDeleted: Bool,
         feed: ForumThreadSummary? = nil) {
        self.target = target; self.title = title; self.forumName = forumName
        self.status = status; self.isDeleted = isDeleted; self.feed = feed
    }

    var feedSummary: ForumThreadSummary {
        feed ?? ForumThreadSummary(itemID: id, threadID: id, title: title, forumName: forumName,
                                   authorName: "未知作者", replyCount: 0, viewCount: 0, isPinned: false)
    }
}

struct FavoritePage: Equatable, Sendable {
    let entries: [ThreadFavorite]
    let nextOffset: Int?
}

enum FavoriteFailure: Error, Equatable, Sendable {
    case accountUnavailable, invalidData, rejected(Int64), outcomeUnknown
}

protocol FavoriteRepositoryProtocol: Sendable {
    func page(offset: Int, account: String) async throws -> FavoritePage
    func save(_ entry: ThreadFavorite, account: String) async throws
    func remove(_ threadID: Int64, account: String) async throws
}
