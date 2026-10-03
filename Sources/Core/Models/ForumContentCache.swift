import Foundation

struct ContentCachePolicy: Sendable {
    var memoryPages = 30
    var memoryBytes = 16 * 1_024 * 1_024
    var diskBytes = 128 * 1_024 * 1_024
    var maximumEntryBytes = 4 * 1_024 * 1_024
    var freshSeconds: TimeInterval = 60
    var maximumAge: TimeInterval = 7 * 24 * 60 * 60
}

/// Runtime authorization identity. Never encoded into cached content.
struct ContentCacheContext: Equatable, Hashable, Sendable {
    let namespace: String?
    let revision: UInt64
    static let anonymous = ContentCacheContext(namespace: "anonymous", revision: 0)
}

struct ForumCachedPage: Codable, Sendable {
    let requestPage: Int
    let requestCursor: Int64
    let fetchedAt: Date
    let page: ForumPageDTO
}

struct ForumCachedReading: Sendable {
    let generation: String
    let queryIdentity: ForumQueryIdentity
    let context: ContentCacheContext
    let cacheEpoch: UInt64
    var pages: [ForumCachedPage]
    var anchor: Int64?
    var isFresh: Bool

    var snapshot: ForumHomeSnapshot? {
        guard let first = pages.first?.page.snapshot else { return nil }
        return pages.dropFirst().reduce(first) { $0.appending($1.page.snapshot) }
    }
}

protocol ForumHomeCacheAccess: ForumHomeRepository {
    @MainActor var cacheContext: ContentCacheContext { get }
    func restoreReading(_ request: ForumHomePageRequest) async -> ForumCachedReading?
    func fetchPage(_ request: ForumHomePageRequest, continuing: ForumCachedReading?) async throws -> ForumCachedReading
    func saveReading(_ reading: ForumCachedReading, request: ForumHomePageRequest) async
}

/// Only value fields from completed pages; no Proto, credentials, images or rendered rows.
struct ForumPageDTO: Codable, Sendable {
    let forum: ForumSummary
    let threads: [Thread]
    let currentPage: Int
    let hasMore: Bool
    let lastThreadID: Int64

    init(_ snapshot: ForumHomeSnapshot) {
        forum = snapshot.forum
        threads = snapshot.threads.map(Thread.init)
        currentPage = snapshot.currentPage
        hasMore = snapshot.hasMore
        lastThreadID = snapshot.lastThreadID
    }

    var snapshot: ForumHomeSnapshot {
        .init(forum: forum, threads: threads.map(\.summary), currentPage: currentPage, hasMore: hasMore, lastThreadID: lastThreadID)
    }

    struct Resource: Codable, Sendable {
        let id: String
        let urls: [String]
    }

    struct Thread: Codable, Sendable {
        let itemID: Int64
        let threadID: Int64
        let title: String
        let text: String?
        let forumName: String
        let authorName: String
        let replyCount: Int32
        let viewCount: Int32
        let isPinned: Bool
        let mediaCount: Int
        let resources: [Resource]
        let hasVideo: Bool
        let author: TiebaUserVisuals?
        let metadata: ForumThreadMetadata

        init(_ thread: ForumThreadSummary) {
            itemID = thread.itemID
            threadID = thread.threadID
            title = thread.title
            text = thread.summary
            forumName = thread.forumName
            authorName = thread.authorName
            replyCount = thread.replyCount
            viewCount = thread.viewCount
            isPinned = thread.isPinned
            mediaCount = thread.mediaCount
            resources = thread.thumbnailResources.map { .init(id: $0.resourceID, urls: $0.candidateURLs) }
            hasVideo = thread.hasVideo
            author = thread.author
            metadata = thread.metadata
        }

        var summary: ForumThreadSummary {
            .init(itemID: itemID, threadID: threadID, title: title, summary: text, forumName: forumName,
                  authorName: authorName, replyCount: replyCount, viewCount: viewCount, isPinned: isPinned,
                  mediaCount: mediaCount, thumbnailResources: resources.map { .init(resourceID: $0.id, candidateURLs: $0.urls) },
                  hasVideo: hasVideo, author: author, metadata: metadata)
        }
    }
}
