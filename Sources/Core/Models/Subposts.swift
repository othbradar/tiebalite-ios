import Foundation

struct SubpostsRoute: Codable, Hashable, Sendable {
    let threadID: Int64
    let postID: Int64
}

struct Subpost: Identifiable, Equatable, Sendable, Codable {
    let author: TiebaUserVisuals
    let document: ThreadContentDocument
    let createdAt: UInt32?
    let agreeCount: Int64?

    var id: Int64 { document.source.postID }
    var metadata: String {
        createdAt.map { TiebaDateText.date(Date(timeIntervalSince1970: TimeInterval($0))) } ?? ""
    }
}

struct SubpostsPage: Equatable, Sendable, Codable {
    let route: SubpostsRoute
    let parent: ThreadReaderPost?
    let threadAuthorID: Int64
    let forumID: Int64
    let forumName: String
    let items: [Subpost]
    let pageNumber: Int
    let totalPages: Int
    let totalCount: Int

    var hasMore: Bool { pageNumber < totalPages }
}

struct SubpostReplyIntent: Equatable, Sendable {
    let route: SubpostsRoute
    let forumID: Int64
    let forumName: String
    let subPostID: Int64
    let author: TiebaUserVisuals
    var replyCount: Int?
}

protocol SubpostsRepository: Sendable {
    func loadPage(route: SubpostsRoute, page: Int) async throws -> SubpostsPage
}
