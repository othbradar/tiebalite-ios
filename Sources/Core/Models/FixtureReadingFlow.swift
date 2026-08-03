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
}

struct ThreadReaderAuthor: Equatable, Sendable {
    let rawUserID: Int64
    let displayName: String
}

struct ThreadReaderPost: Identifiable, Equatable, Sendable {
    let floorNumber: Int
    let author: ThreadReaderAuthor
    let metadata: String
    let document: ThreadContentDocument

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
}

protocol ThreadReaderRepository: Sendable {
    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot
}
