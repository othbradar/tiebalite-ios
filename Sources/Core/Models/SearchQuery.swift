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

struct SearchQuery: Hashable, Sendable {
    let scope: SearchScope
    let type: SearchResultType
    let keyword: SearchKeyword
    let sort: SearchSort

    init?(scope: SearchScope = .global, type: SearchResultType = .threads,
          keyword: SearchKeyword, sort: SearchSort = .newest) {
        guard scope == .global || type == .threads else { return nil }
        self.scope = scope
        self.type = type
        self.keyword = keyword
        self.sort = type == .threads ? sort : .newest
    }
}
