import Foundation

enum ForumThreadRowKind: Equatable, Sendable {
    case top
    case plainText
    case singleMedia
    case multiMedia
    case video
}

struct ForumThreadThumbnailDescription: Identifiable, Equatable, Sendable {
    let resourceID: String
    let alternativeText: String

    var id: String {
        resourceID
    }
}

struct ForumThreadRowModel: Identifiable, Equatable, Sendable {
    let itemID: Int64
    let threadID: Int64
    let forumID: Int64?
    let forumName: String
    let title: String
    let summary: String?
    let authorName: String
    let replyCount: Int32
    let viewCount: Int32
    let isPinned: Bool
    let thumbnailDescriptions: [ForumThreadThumbnailDescription]
    let additionalThumbnailCount: Int
    let rowKind: ForumThreadRowKind

    init(thread: ForumThreadSummary, forumID: Int64?) {
        itemID = thread.itemID
        threadID = thread.threadID
        self.forumID = forumID
        forumName = thread.forumName
        title = Self.normalized(thread.title, fallback: "无标题")
        let normalizedSummary = thread.summary.map {
            Self.normalized($0, fallback: "")
        }
        summary = normalizedSummary == title || normalizedSummary?.isEmpty == true
            ? nil
            : normalizedSummary
        authorName = Self.normalized(thread.authorName, fallback: "未知作者")
        replyCount = max(0, thread.replyCount)
        viewCount = max(0, thread.viewCount)
        isPinned = thread.isPinned
        let visibleThumbnailCount = min(3, thread.mediaCount)
        thumbnailDescriptions = (0..<visibleThumbnailCount).map { index in
            ForumThreadThumbnailDescription(
                resourceID: "forum.t\(thread.threadID).thumbnail.\(index + 1)",
                alternativeText: "帖子图片 \(index + 1)"
            )
        }
        additionalThumbnailCount = max(0, thread.mediaCount - 3)
        if thread.isPinned {
            rowKind = .top
        } else if thread.mediaCount == 1 {
            rowKind = .singleMedia
        } else if thread.mediaCount > 1 {
            rowKind = .multiMedia
        } else if thread.hasVideo {
            rowKind = .video
        } else {
            rowKind = .plainText
        }
    }

    var id: Int64 {
        threadID
    }

    var sourceSummary: ForumThreadSummary {
        ForumThreadSummary(
            itemID: itemID,
            threadID: threadID,
            title: title,
            summary: summary,
            forumName: forumName,
            authorName: authorName,
            replyCount: replyCount,
            viewCount: viewCount,
            isPinned: isPinned,
            mediaCount: thumbnailDescriptions.count + additionalThumbnailCount,
            hasVideo: rowKind == .video
        )
    }

    private static func normalized(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

enum ForumHomePaginationPresentation: Equatable, Sendable {
    case end
    case failure
    case idle
    case loading
}

enum ForumHomeRetainedStatus: Equatable, Sendable {
    case refreshFailure
    case refreshing
}

enum ForumHomeSection: String, Equatable, Hashable, Sendable {
    case pinned
    case regular
}

enum ForumHomeRowID: Equatable, Hashable, Sendable {
    case empty(String)
    case header(String)
    case pagination(String)
    case retainedStatus(String)
    case section(String, ForumHomeSection)
    case thread(Int64)
}

enum ForumHomeRowContent: Equatable, Sendable {
    case empty
    case header(ForumSummary)
    case pagination(ForumHomePaginationPresentation)
    case retainedStatus(ForumHomeRetainedStatus)
    case section(ForumHomeSection)
    case thread(ForumThreadRowModel)
}

struct ForumHomeRowModel: Identifiable, Equatable, Sendable {
    let id: ForumHomeRowID
    let content: ForumHomeRowContent
}

struct ForumHomeListPresentation: Equatable, Sendable {
    private(set) var rows: [ForumHomeRowModel]
    private(set) var pagination: ForumHomePaginationPresentation
    private(set) var threadRows: [ForumThreadRowModel]

    private let forumKey: String
    private let forumID: Int64?
    private var threadIDs: Set<Int64>

    init(
        snapshot: ForumHomeSnapshot,
        pagination: ForumHomePaginationPresentation
    ) {
        forumKey = Self.forumKey(snapshot.forum)
        forumID = snapshot.forum.forumID
        self.pagination = pagination
        var seenThreadIDs: Set<Int64> = []
        threadRows = snapshot.threads.compactMap { thread in
            guard seenThreadIDs.insert(thread.threadID).inserted else {
                return nil
            }
            return ForumThreadRowModel(
                thread: thread,
                forumID: snapshot.forum.forumID
            )
        }
        threadIDs = seenThreadIDs
        rows = []
        rows.append(
            ForumHomeRowModel(
                id: .header(forumKey),
                content: .header(snapshot.forum)
            )
        )

        let pinned = threadRows.filter(\.isPinned)
        let regular = threadRows.filter { !$0.isPinned }
        if threadRows.isEmpty {
            rows.append(
                ForumHomeRowModel(
                    id: .empty(forumKey),
                    content: .empty
                )
            )
        } else {
            Self.appendSection(
                .pinned,
                threads: pinned,
                forumKey: forumKey,
                to: &rows
            )
            Self.appendSection(
                .regular,
                threads: regular,
                forumKey: forumKey,
                to: &rows
            )
            rows.append(
                ForumHomeRowModel(
                    id: .pagination(forumKey),
                    content: .pagination(pagination)
                )
            )
        }
    }

    var prefetchRowIDs: Set<ForumHomeRowID> {
        Set(threadRows.suffix(4).map { .thread($0.threadID) })
    }

    mutating func append(
        threads: [ForumThreadSummary],
        pagination: ForumHomePaginationPresentation
    ) {
        let newRows = threads.compactMap { thread -> ForumThreadRowModel? in
            guard threadIDs.insert(thread.threadID).inserted else {
                return nil
            }
            return ForumThreadRowModel(
                thread: thread,
                forumID: forumID
            )
        }
        guard !newRows.isEmpty else {
            setPagination(pagination)
            return
        }

        if threadRows.isEmpty {
            rows.removeAll { row in
                if case .empty = row.id {
                    return true
                }
                return false
            }
        }
        threadRows.append(contentsOf: newRows)
        let regularSectionID = ForumHomeRowID.section(forumKey, .regular)
        if !rows.contains(where: { $0.id == regularSectionID }) {
            rows.append(
                ForumHomeRowModel(
                    id: regularSectionID,
                    content: .section(.regular)
                )
            )
        }
        let insertionIndex = rows.firstIndex {
            if case .pagination = $0.id {
                return true
            }
            return false
        } ?? rows.endIndex
        rows.insert(
            contentsOf: newRows.map {
                ForumHomeRowModel(
                    id: .thread($0.threadID),
                    content: .thread($0)
                )
            },
            at: insertionIndex
        )
        if !rows.contains(where: {
            if case .pagination = $0.id {
                return true
            }
            return false
        }) {
            rows.append(
                ForumHomeRowModel(
                    id: .pagination(forumKey),
                    content: .pagination(pagination)
                )
            )
        }
        setPagination(pagination)
    }

    mutating func setPagination(
        _ pagination: ForumHomePaginationPresentation
    ) {
        self.pagination = pagination
        guard let index = rows.firstIndex(where: {
            if case .pagination = $0.id {
                return true
            }
            return false
        }) else {
            return
        }
        rows[index] = ForumHomeRowModel(
            id: .pagination(forumKey),
            content: .pagination(pagination)
        )
    }

    mutating func setRetainedStatus(_ status: ForumHomeRetainedStatus?) {
        rows.removeAll { row in
            if case .retainedStatus = row.id {
                return true
            }
            return false
        }
        guard let status else {
            return
        }
        rows.insert(
            ForumHomeRowModel(
                id: .retainedStatus(forumKey),
                content: .retainedStatus(status)
            ),
            at: min(1, rows.endIndex)
        )
    }

    private static func appendSection(
        _ section: ForumHomeSection,
        threads: [ForumThreadRowModel],
        forumKey: String,
        to rows: inout [ForumHomeRowModel]
    ) {
        guard !threads.isEmpty else {
            return
        }
        rows.append(
            ForumHomeRowModel(
                id: .section(forumKey, section),
                content: .section(section)
            )
        )
        rows.append(contentsOf: threads.map { thread in
            ForumHomeRowModel(
                id: .thread(thread.threadID),
                content: .thread(thread)
            )
        })
    }

    private static func forumKey(_ forum: ForumSummary) -> String {
        if let forumID = forum.forumID {
            return "f\(forumID)"
        }
        return "n\(forum.name)"
    }
}
