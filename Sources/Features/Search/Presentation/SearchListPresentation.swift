import Foundation

enum SearchResultSection: String, Equatable, Hashable, Sendable {
    case recommended
    case related
    case relatedUsers
}

enum SearchRowID: Equatable, Hashable, Sendable {
    case forum(Int64)
    case pagination(String)
    case section(SearchResultSection)
    case thread(Int64)
    case user(Int64)
}

struct ForumSearchRowModel: Equatable, Sendable {
    let result: ForumSearchResult
    let title: String
    let summary: String?

    init(result: ForumSearchResult) {
        self.result = result
        title = Self.normalized(result.displayName, fallback: result.name)
        summary = result.summary.flatMap(Self.nonempty)

    }

    private static func normalized(
        _ value: String,
        fallback: String
    ) -> String {
        nonempty(value) ?? nonempty(fallback) ?? "未知吧"
    }

    private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ThreadSearchRowModel: Equatable, Sendable {
    let result: ThreadSearchResult
    let title: String
    let summary: String?
    let forumName: String
    let authorName: String
    let replyText: String

    init(result: ThreadSearchResult) {
        self.result = result
        title = Self.normalized(result.title, fallback: "无标题")
        let summary = result.summary.map {
            Self.normalized($0, fallback: "")
        }
        self.summary = summary == title || summary?.isEmpty == true
            ? nil
            : summary
        forumName = Self.normalized(result.forumName, fallback: "未知吧")
        authorName = Self.normalized(result.authorName, fallback: "未知作者")
        replyText = String(max(0, result.replyCount))
    }

    private static func normalized(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

enum SearchRowContent: Equatable, Sendable {
    case forum(ForumSearchRowModel)
    case pagination(PaginationFooterState)
    case section(SearchResultSection)
    case thread(ThreadSearchRowModel)
    case user(UserSearchResult)
}

struct SearchRowModel: Identifiable, Equatable, Sendable {
    let id: SearchRowID
    let content: SearchRowContent
}

struct SearchListPresentation: Equatable, Sendable {
    let query: SearchQuery
    private(set) var rows: [SearchRowModel]
    private(set) var pagination: PaginationFooterState
    let prefetchRowIDs: Set<SearchRowID>

    init(
        snapshot: SearchSnapshot,
        pagination: PaginationFooterState
    ) {
        query = snapshot.query
        self.pagination = pagination
        switch query.type {
        case .users:
            rows = []
            for (section, results) in [
                (SearchResultSection.recommended, snapshot.users.filter(\.isExactMatch)),
                (.relatedUsers, snapshot.users.filter { !$0.isExactMatch })
            ] where !results.isEmpty {
                rows.append(SearchRowModel(id: .section(section), content: .section(section)))
                rows += results.map { SearchRowModel(id: .user($0.id), content: .user($0)) }
            }
        case .forums:
            rows = []
            for (section, results) in [
                (SearchResultSection.recommended, snapshot.forums.filter(\.isExactMatch)),
                (.related, snapshot.forums.filter { !$0.isExactMatch })
            ] where !results.isEmpty {
                rows.append(SearchRowModel(id: .section(section), content: .section(section)))
                rows += results.map { result in
                    SearchRowModel(id: .forum(result.forumID), content: .forum(ForumSearchRowModel(result: result)))
                }
            }
        case .threads:
            rows = snapshot.threads.map { result in
                SearchRowModel(id: .thread(result.threadID), content: .thread(ThreadSearchRowModel(result: result)))
            }
            rows.append(SearchRowModel(id: .pagination(snapshot.keyword.rawValue), content: .pagination(pagination)))
        }
        prefetchRowIDs = Set(
            snapshot.threads.suffix(4).map { .thread($0.threadID) }
        )
    }
}

private extension ThreadSearchResult {
    var positiveDate: Date? {
        guard let timeUnixSeconds, timeUnixSeconds > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(timeUnixSeconds))
    }
}

extension ThreadSearchRowModel {
    var timeText: String? { result.positiveDate.map { TiebaDateText.date($0, includesTime: true) } }
    var shareText: String {
        guard let count = result.shareCount, count > 0 else { return "分享" }
        return String(count)
    }
}
