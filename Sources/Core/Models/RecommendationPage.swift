struct RecommendationAuthor: Equatable, Sendable {
    let rawUserID: Int64
    let name: String
    let nameShow: String
    let portrait: String
}

struct RecommendationItem: Equatable, Sendable {
    let rawFeedID: Int64
    let rawThreadID: Int64
    let title: String
    let rawThreadType: Int32
    let rawAuthorID: Int64
    let author: RecommendationAuthor?
    let rawForumID: Int64
    let forumName: String
    let replyCount: Int32
    let viewCount: Int32
    let isNoTitleRaw: Int32
    let isDeletedRaw: Int32
    let hasVideo: Bool
    let hasLive: Bool
    let thumbnailResource: ImageResourceDescriptor?
}

enum RecommendationTerminalState: Equatable, Sendable {
    case unknown
}

struct RecommendationPage: Equatable, Sendable {
    let items: [RecommendationItem]
    let requestedPage: UInt32
    let nextPageCandidate: UInt32?
    let terminal: RecommendationTerminalState
}
