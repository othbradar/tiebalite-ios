struct RecommendationThumbnail: Equatable, Sendable {
    let resourceID: String
    let alternativeText: String
}

struct RecommendationSummary: Identifiable, Equatable, Sendable {
    let threadID: Int64
    let title: String
    let forumName: String
    let authorName: String
    let replyCount: Int32
    let thumbnail: RecommendationThumbnail?

    var id: Int64 {
        threadID
    }
}

protocol RecommendationRepository: Sendable {
    func loadRecommendations() async throws -> [RecommendationSummary]
    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage
}

enum RecommendationPageLoadKind: Equatable, Sendable {
    case refresh
    case nextPage
}

struct RecommendationPageRequest: Equatable, Sendable {
    let loadKind: RecommendationPageLoadKind
    let page: UInt32

    static let initial = RecommendationPageRequest(
        loadKind: .refresh,
        page: 1
    )
}

struct RecommendationRepositoryPage: Equatable, Sendable {
    let items: [RecommendationSummary]
    let requestedPage: UInt32
    let nextPageCandidate: UInt32?
}

enum RecommendationRepositoryError: Error, Equatable, Sendable {
    case invalidRequest
    case paginationUnavailable
}

extension RecommendationPageRequest {
    var isValid: Bool {
        switch loadKind {
        case .refresh:
            page == 1
        case .nextPage:
            page > 1
        }
    }
}

extension RecommendationRepository {
    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage {
        guard request == .initial else {
            throw RecommendationRepositoryError.paginationUnavailable
        }
        return RecommendationRepositoryPage(
            items: try await loadRecommendations(),
            requestedPage: request.page,
            nextPageCandidate: nil
        )
    }
}

struct ThreadReaderAuthor: Equatable, Sendable {
    let rawUserID: Int64
    let displayName: String
}

struct ThreadReaderSubpost: Identifiable, Equatable, Sendable {
    let parentPostID: Int64
    let author: ThreadReaderAuthor
    let replyToDisplayName: String?
    let metadata: String
    let createdAtUnixSeconds: UInt32?
    let document: ThreadContentDocument

    init(
        parentPostID: Int64,
        author: ThreadReaderAuthor,
        replyToDisplayName: String? = nil,
        metadata: String,
        createdAtUnixSeconds: UInt32? = nil,
        document: ThreadContentDocument
    ) {
        self.parentPostID = parentPostID
        self.author = author
        self.replyToDisplayName = replyToDisplayName
        self.metadata = metadata
        self.createdAtUnixSeconds = createdAtUnixSeconds
        self.document = document
    }

    var id: ThreadContentSource {
        document.source
    }
}

struct ThreadReaderPost: Identifiable, Equatable, Sendable {
    let floorNumber: Int
    let author: ThreadReaderAuthor
    let metadata: String
    let createdAtUnixSeconds: UInt32?
    let document: ThreadContentDocument
    let subposts: [ThreadReaderSubpost]
    let subpostTotal: Int

    init(
        floorNumber: Int,
        author: ThreadReaderAuthor,
        metadata: String,
        createdAtUnixSeconds: UInt32? = nil,
        document: ThreadContentDocument,
        subposts: [ThreadReaderSubpost] = [],
        subpostTotal: Int = 0
    ) {
        self.floorNumber = floorNumber
        self.author = author
        self.metadata = metadata
        self.createdAtUnixSeconds = createdAtUnixSeconds
        self.document = document
        self.subposts = subposts
        self.subpostTotal = max(subpostTotal, subposts.count)
    }

    var id: ThreadContentSource {
        document.source
    }
}

struct ThreadReaderSnapshot: Equatable, Sendable {
    let threadID: Int64
    let title: String
    let forumName: String
    let author: ThreadReaderAuthor
    let replyCount: Int32
    let posts: [ThreadReaderPost]
    let currentPage: Int
    let totalPage: Int?
    let hasMore: Bool
    let nextPostID: Int64?

    init(
        threadID: Int64,
        title: String,
        forumName: String,
        author: ThreadReaderAuthor,
        replyCount: Int32,
        posts: [ThreadReaderPost],
        currentPage: Int = 1,
        totalPage: Int? = nil,
        hasMore: Bool = false,
        nextPostID: Int64? = nil
    ) {
        self.threadID = threadID
        self.title = title
        self.forumName = forumName
        self.author = author
        self.replyCount = replyCount
        self.posts = posts
        self.currentPage = currentPage
        self.totalPage = totalPage
        self.hasMore = hasMore
        self.nextPostID = nextPostID
    }
}

struct ThreadReaderPageRequest: Equatable, Sendable {
    let threadID: Int64
    let pageNumber: Int
    let postID: Int64
    let loadedPostIDs: Set<Int64>

    init(
        threadID: Int64,
        pageNumber: Int,
        postID: Int64,
        loadedPostIDs: Set<Int64> = []
    ) {
        self.threadID = threadID
        self.pageNumber = pageNumber
        self.postID = postID
        self.loadedPostIDs = loadedPostIDs
    }

    static func initial(threadID: Int64) -> ThreadReaderPageRequest {
        ThreadReaderPageRequest(
            threadID: threadID,
            pageNumber: 0,
            postID: 0,
            loadedPostIDs: []
        )
    }
}

enum ThreadReaderRepositoryError: Error, Equatable, Sendable {
    case paginationUnavailable
}

protocol ThreadReaderRepository: Sendable {
    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot
    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot
}

extension ThreadReaderRepository {
    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        try await loadPage(.initial(threadID: threadID))
    }

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        guard request.pageNumber == 0, request.postID == 0 else {
            throw ThreadReaderRepositoryError.paginationUnavailable
        }
        return try await loadThread(threadID: request.threadID)
    }
}
