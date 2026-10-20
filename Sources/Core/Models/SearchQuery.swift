/// Search result identity is independent of the screen hosting it.
enum SearchScope: Codable, Hashable, Sendable {
    case global
    case forum(ForumRoute)
}

enum SearchResultType: String, Codable, CaseIterable, Hashable, Sendable {
    case threads
    case forums
    case users
}

/// Values from Android SearchThreadSortType, carried unchanged by the Hybrid endpoint.
enum SearchSort: Int, CaseIterable, Hashable, Sendable {
    case newest = 5
    case oldest = 0
    case relevance = 2
}

/// Independent content filter from the official forum-search module and user reference.
enum ForumSearchMode: String, CaseIterable, Hashable, Sendable {
    case topics, comments
    var threadTypeValue: String { self == .topics ? "1" : "3" }
    var title: String { self == .topics ? "只看主题" : "只看评论" }
}

struct SearchQuery: Hashable, Sendable {
    let scope: SearchScope
    let type: SearchResultType
    let keyword: SearchKeyword
    let sort: SearchSort
    let forumMode: ForumSearchMode

    init?(scope: SearchScope = .global, type: SearchResultType = .threads,
          keyword: SearchKeyword, sort: SearchSort = .newest, forumMode: ForumSearchMode = .topics) {
        guard scope == .global || type == .threads else { return nil }
        self.scope = scope
        self.type = type
        self.keyword = keyword
        self.sort = type == .threads && (scope == .global || sort != .oldest) ? sort : .newest
        self.forumMode = scope == .global ? .topics : forumMode
    }
}
