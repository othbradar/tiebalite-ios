import Foundation

enum SearchResultSection: String, Equatable, Hashable, Sendable {
    case forums
    case threads
}

enum SearchRowID: Equatable, Hashable, Sendable {
    case empty(SearchResultSection)
    case forum(Int64)
    case pagination(String)
    case section(SearchResultSection)
    case thread(Int64)
}

struct ForumSearchRowModel: Equatable, Sendable {
    let result: ForumSearchResult
    let title: String
    let summary: String?
    let statistics: String?

    init(result: ForumSearchResult) {
        self.result = result
        title = Self.normalized(result.displayName, fallback: result.name)
        summary = result.summary.flatMap(Self.nonempty)
        let statistics = [
            result.memberCountText.map { "关注 \($0)" },
            result.postCountText.map { "帖子 \($0)" }
        ].compactMap { $0 }
        self.statistics = statistics.isEmpty
            ? nil
            : statistics.joined(separator: " · ")
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
    case empty(SearchResultSection)
    case forum(ForumSearchRowModel)
    case pagination(PaginationFooterState)
    case section(SearchResultSection)
    case thread(ThreadSearchRowModel)
}

struct SearchRowModel: Identifiable, Equatable, Sendable {
    let id: SearchRowID
    let content: SearchRowContent
}

struct SearchListPresentation: Equatable, Sendable {
    private(set) var rows: [SearchRowModel]
    private(set) var pagination: PaginationFooterState
    let prefetchRowIDs: Set<SearchRowID>

    init(
        snapshot: SearchSnapshot,
        pagination: PaginationFooterState
    ) {
        self.pagination = pagination
        rows = []
        rows.append(
            SearchRowModel(
                id: .section(.forums),
                content: .section(.forums)
            )
        )
        if snapshot.forums.isEmpty {
            rows.append(
                SearchRowModel(
                    id: .empty(.forums),
                    content: .empty(.forums)
                )
            )
        } else {
            rows.append(contentsOf: snapshot.forums.map { result in
                SearchRowModel(
                    id: .forum(result.forumID),
                    content: .forum(ForumSearchRowModel(result: result))
                )
            })
        }

        rows.append(
            SearchRowModel(
                id: .section(.threads),
                content: .section(.threads)
            )
        )
        if snapshot.threads.isEmpty {
            rows.append(
                SearchRowModel(
                    id: .empty(.threads),
                    content: .empty(.threads)
                )
            )
        } else {
            rows.append(contentsOf: snapshot.threads.map { result in
                SearchRowModel(
                    id: .thread(result.threadID),
                    content: .thread(ThreadSearchRowModel(result: result))
                )
            })
            rows.append(
                SearchRowModel(
                    id: .pagination(snapshot.keyword.rawValue),
                    content: .pagination(pagination)
                )
            )
        }
        prefetchRowIDs = Set(
            snapshot.threads.suffix(4).map { .thread($0.threadID) }
        )
    }
}
