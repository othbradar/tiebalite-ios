struct RecommendationAuthor: Equatable, Sendable {
    let rawUserID: Int64
    let name: String
    let nameShow: String
    let portrait: String
    let visuals: TiebaUserVisuals?

    init(
        rawUserID: Int64,
        name: String,
        nameShow: String,
        portrait: String,
        visuals: TiebaUserVisuals? = nil
    ) {
        self.rawUserID = rawUserID
        self.name = name
        self.nameShow = nameShow
        self.portrait = portrait
        self.visuals = visuals
    }
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
    let forumAvatarResource: ImageResourceDescriptor?
    let feed: RecommendationFeedDetails

    init(
        rawFeedID: Int64,
        rawThreadID: Int64,
        title: String,
        rawThreadType: Int32,
        rawAuthorID: Int64,
        author: RecommendationAuthor?,
        rawForumID: Int64,
        forumName: String,
        replyCount: Int32,
        viewCount: Int32,
        isNoTitleRaw: Int32,
        isDeletedRaw: Int32,
        hasVideo: Bool,
        hasLive: Bool,
        thumbnailResource: ImageResourceDescriptor?,
        forumAvatarResource: ImageResourceDescriptor? = nil,
        feed: RecommendationFeedDetails = RecommendationFeedDetails()
    ) {
        self.rawFeedID = rawFeedID
        self.rawThreadID = rawThreadID
        self.title = title
        self.rawThreadType = rawThreadType
        self.rawAuthorID = rawAuthorID
        self.author = author
        self.rawForumID = rawForumID
        self.forumName = forumName
        self.replyCount = replyCount
        self.viewCount = viewCount
        self.isNoTitleRaw = isNoTitleRaw
        self.isDeletedRaw = isDeletedRaw
        self.hasVideo = hasVideo
        self.hasLive = hasLive
        self.thumbnailResource = thumbnailResource
        self.forumAvatarResource = forumAvatarResource
        self.feed = feed
    }
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
