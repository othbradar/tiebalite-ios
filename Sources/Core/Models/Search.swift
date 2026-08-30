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

    var id: Int64 {
        threadID
    }
}

struct SearchThreadPageRequest: Equatable, Sendable {
    let keyword: SearchKeyword
    let page: Int

    init?(keyword: SearchKeyword, page: Int) {
        guard page > 0 else {
            return nil
        }
        self.keyword = keyword
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

struct SearchSnapshot: Equatable, Sendable {
    let keyword: SearchKeyword
    let forums: [ForumSearchResult]
    let threads: [ThreadSearchResult]
    let currentThreadPage: Int
    let hasMoreThreads: Bool

    init(
        keyword: SearchKeyword,
        forums: [ForumSearchResult],
        threads: [ThreadSearchResult],
        currentThreadPage: Int,
        hasMoreThreads: Bool
    ) {
        var seenForumIDs: Set<Int64> = []
        var seenThreadIDs: Set<Int64> = []
        self.keyword = keyword
        self.forums = forums.filter { result in
            result.forumID > 0
                && seenForumIDs.insert(result.forumID).inserted
        }
        self.threads = threads.filter { result in
            result.threadID > 0
                && seenThreadIDs.insert(result.threadID).inserted
        }
        self.currentThreadPage = max(1, currentThreadPage)
        self.hasMoreThreads = hasMoreThreads
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
            keyword: keyword,
            forums: forums,
            threads: merged,
            currentThreadPage: page.currentPage,
            hasMoreThreads: page.hasMore
        )
    }
}

protocol SearchRepository: Sendable {
    func search(keyword: SearchKeyword) async throws -> SearchSnapshot
    func loadThreadPage(
        _ request: SearchThreadPageRequest
    ) async throws -> ThreadSearchPage
}
