import Foundation

struct SearchKeyword: Equatable, Hashable, Sendable {
    static let maximumUTF8Length = 256

    let rawValue: String

    init?(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= Self.maximumUTF8Length,
              trimmed.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        rawValue = trimmed
    }
}

struct ForumSearchResult: Identifiable, Equatable, Sendable {
    let forumID: Int64
    let name: String
    let displayName: String
    let summary: String?
    let memberCountText: String?
    let postCountText: String?
    let avatarResource: ImageResourceDescriptor?
    let isExactMatch: Bool

    init(
        forumID: Int64,
        name: String,
        displayName: String,
        summary: String?,
        memberCountText: String?,
        postCountText: String?,
        avatarResource: ImageResourceDescriptor? = nil,
        isExactMatch: Bool = false
    ) {
        self.forumID = forumID
        self.name = name
        self.displayName = displayName
        self.summary = summary
        self.memberCountText = memberCountText
        self.postCountText = postCountText
        self.avatarResource = avatarResource
        self.isExactMatch = isExactMatch
    }

    var id: Int64 {
        forumID
    }
}

struct ThreadSearchResult: Identifiable, Equatable, Sendable {
    let threadID: Int64
    let title: String
    let summary: String?
    let forumID: Int64?
    let forumName: String
    let authorName: String
    let replyCount: Int
    let author: TiebaUserVisuals?
    let forumAvatarResource: ImageResourceDescriptor?
    let timeUnixSeconds: Int64?
    let likeCount: Int64?
    let shareCount: Int64?

    init(
        threadID: Int64,
        title: String,
        summary: String?,
        forumID: Int64?,
        forumName: String,
        authorName: String,
        replyCount: Int,
        author: TiebaUserVisuals? = nil,
        forumAvatarResource: ImageResourceDescriptor? = nil,
        timeUnixSeconds: Int64? = nil,
        likeCount: Int64? = nil,
        shareCount: Int64? = nil
    ) {
        self.threadID = threadID
        self.title = title
        self.summary = summary
        self.forumID = forumID
        self.forumName = forumName
        self.authorName = authorName
        self.replyCount = replyCount
        self.author = author
        self.forumAvatarResource = forumAvatarResource
        self.timeUnixSeconds = timeUnixSeconds
        self.likeCount = likeCount
        self.shareCount = shareCount
    }

    var id: Int64 {
        threadID
    }
}

struct SearchThreadPageRequest: Equatable, Sendable {
    let query: SearchQuery
    var keyword: SearchKeyword { query.keyword }
    let page: Int

    init?(keyword: SearchKeyword, page: Int) {
        guard let query = SearchQuery(keyword: keyword) else { return nil }
        self.init(query: query, page: page)
    }

    init?(query: SearchQuery, page: Int) {
        guard page > 0, query.type == .threads else { return nil }
        self.query = query
        self.page = page
    }
}

struct ThreadSearchPage: Equatable, Sendable {
    let items: [ThreadSearchResult]
    let currentPage: Int
    let hasMore: Bool

    init(
        items: [ThreadSearchResult],
        currentPage: Int,
        hasMore: Bool
    ) {
        var seen: Set<Int64> = []
        self.items = items.filter { item in
            item.threadID > 0 && seen.insert(item.threadID).inserted
        }
        self.currentPage = max(1, currentPage)
        self.hasMore = hasMore
    }
}

struct UserSearchResult: Identifiable, Equatable, Sendable {
    let route: UserProfileRoute
    let introduction: String?
    let isExactMatch: Bool

    var id: Int64 { route.userID.rawValue }
    var avatarResource: ImageResourceDescriptor? {
        TiebaAvatarResource.user(userID: id, portrait: route.portraitResourceID)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.route == rhs.route && lhs.route.fallbackDisplayName == rhs.route.fallbackDisplayName
            && lhs.route.portraitResourceID == rhs.route.portraitResourceID
            && lhs.introduction == rhs.introduction && lhs.isExactMatch == rhs.isExactMatch
    }
}

struct SearchSnapshot: Equatable, Sendable {
    let query: SearchQuery
    var keyword: SearchKeyword { query.keyword }
    let forums: [ForumSearchResult]
    let threads: [ThreadSearchResult]
    let users: [UserSearchResult]
    let currentThreadPage: Int
    let hasMoreThreads: Bool

    init(
        query: SearchQuery,
        forums: [ForumSearchResult],
        threads: [ThreadSearchResult],
        users: [UserSearchResult] = [],
        currentThreadPage: Int,
        hasMoreThreads: Bool
    ) {
        var seenForumIDs: Set<Int64> = []
        var seenThreadIDs: Set<Int64> = []
        var seenUserIDs: Set<Int64> = []
        self.query = query
        self.forums = forums.filter { result in
            query.type == .forums && result.forumID > 0
                && seenForumIDs.insert(result.forumID).inserted
        }
        self.threads = threads.filter { result in
            query.type == .threads && result.threadID > 0
                && seenThreadIDs.insert(result.threadID).inserted
        }
        self.currentThreadPage = max(1, currentThreadPage)
        self.users = users.filter { query.type == .users && seenUserIDs.insert($0.id).inserted }
        self.hasMoreThreads = query.type == .threads && hasMoreThreads
    }

    func appending(_ page: ThreadSearchPage) -> SearchSnapshot {
        var seenThreadIDs = Set(threads.map(\.threadID))
        var merged = threads
        merged.reserveCapacity(threads.count + page.items.count)
        for thread in page.items
        where seenThreadIDs.insert(thread.threadID).inserted {
            merged.append(thread)
        }
        return SearchSnapshot(
            query: query,
            forums: forums,
            threads: merged,
            users: users,
            currentThreadPage: page.currentPage,
            hasMoreThreads: page.hasMore
        )
    }
}

protocol SearchRepository: Sendable {
    func search(_ query: SearchQuery) async throws -> SearchSnapshot
    func loadThreadPage(
        _ request: SearchThreadPageRequest
    ) async throws -> ThreadSearchPage
}
