struct ReplyFollowupRequest: Sendable {
    let receipt: TextWriteReceipt
    let entry: ThreadReadingEntry
    let page: Int
}

/// Reads an already accepted reply. Implementations must never resend it.
protocol ReplyFollowupLoading: Sendable {
    func loadReply(_ request: ReplyFollowupRequest) async throws -> ReplyReadUpdate?
}

/// getmypost can return a successful post delta with an explicitly empty Page.
/// A delta has no page address and must never replace pagination metadata.
struct ReplyPostUpdate: Codable, Equatable, Sendable {
    let threadID: Int64
    let replyCount: Int32
    let posts: [ThreadReaderPost]

    func merging(_ newer: Self) -> Self {
        guard newer.threadID == threadID else { return self }
        let replacements = Dictionary(newer.posts.map { ($0.id.postID, $0) }, uniquingKeysWith: { _, new in new })
        var seen = Set<Int64>()
        let combined = (posts.map { replacements[$0.id.postID] ?? $0 } + newer.posts)
            .filter { seen.insert($0.id.postID).inserted }
        return .init(threadID: threadID, replyCount: newer.replyCount, posts: combined)
    }

    func removing(_ ids: Set<Int64>) -> Self? {
        let remaining = posts.filter { !ids.contains($0.id.postID) }
        return remaining.isEmpty ? nil : .init(threadID: threadID, replyCount: replyCount, posts: remaining)
    }
}

enum ReplyReadUpdate: Sendable {
    case page(ThreadReaderSnapshot)
    case posts(ReplyPostUpdate)

    var page: ThreadReaderSnapshot? { if case let .page(value) = self { value } else { nil } }
    var threadID: Int64 {
        switch self {
        case let .page(value): value.threadID
        case let .posts(value): value.threadID
        }
    }
    var posts: [ThreadReaderPost] {
        switch self {
        case let .page(value): value.posts
        case let .posts(value): value.posts
        }
    }
}
