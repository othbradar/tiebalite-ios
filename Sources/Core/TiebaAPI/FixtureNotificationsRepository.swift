#if DEBUG
import Foundation

/// Synthetic JSON shaped from Android MessageListBean. No captured account data.
enum NotificationFixtureJSON {
    static func bytes(kind: NotificationKind, page: Int) -> Data {
        let start = page == 0 ? 1 : 15
        let rows = (start..<(start + 15)).map { index in
            """
            {"is_floor":"\(index == 2 ? "1" : "0")","thread_id":"8001","post_id":"\(index == 2 ? 10001 : 9000 + index)",
             "time":"\(1700000000 + index)","title":"一段可以返回的主题",
             "content":"\(kind.title) \(index)：中文回复 #(滑稽) #(捂嘴笑)，长内容在消息页正确换行。",
             "quote_content":"被引用的原文 #(微微一笑)","quote_pid":"999999",
             "replyer":{"id":"\(100 + index)","name_show":"示例用户 \(index)","portrait":"fixture-avatar"}}
            """
        }.joined(separator: ",")
        return Data("""
        {"error_code":"0","\(kind == .replies ? "reply_list" : "at_list")":[\(rows)],
         "page":{"current_page":"\(page == 0 ? 1 : page)","has_more":"\(page == 0 ? 1 : 0)"},
         "message":{"replyme":"2","atme":"1"}}
        """.utf8)
    }
}
struct FixtureNotificationsRepository: NotificationsRepository {
    func load(kind: NotificationKind, page: Int, context: AuthContext) async throws -> NotificationPage {
        try NotificationsProtocol.decodePage(NotificationFixtureJSON.bytes(kind: kind, page: page), kind: kind, page: page)
    }
    func unread(context: AuthContext) async throws -> NotificationCounts { .init(replies: 2, mentions: 1) }
}
enum FixtureNotificationThreadPages {
    static func load(_ request: ThreadReaderPageRequest) throws -> ThreadReaderSnapshot {
        let page = request.pageNumber == 0 ? 1 : request.pageNumber
        guard (1...3).contains(page) else { throw FixtureReadingRepositoryError.unavailable }
        let floors = page == 1 ? 1...15 : page == 2 ? 16...28 : 29...35
        let author = TiebaUserVisuals(rawUserID: 101, displayName: "示例消息作者")
        let posts: [ThreadReaderPost] = floors.map { floor in
            let postID = floor <= 6 ? Int64(18_000 + floor) : Int64(9_000 + floor - 6)
            let source = ThreadContentSource(threadID: 8_001, postID: postID, scope: floor == 1 ? .firstPost : .post)
            return .init(floorNumber: floor, author: author, metadata: "2026年9月25日 10:00",
                         document: .init(source: source, availability: .available, nodes: [
                            .init(id: .init(source: source, ordinal: 0), rawType: 0,
                                  payload: .text(.init(value: "第 \(floor) 楼的完整帖子内容 #(滑稽)")))
                         ], poll: nil))
        }
        return .init(threadID: 8_001, title: "一段可以返回的主题", forumName: "固定样本吧", author: author,
                     replyCount: 34, posts: posts, currentPage: page, totalPage: 3, hasMore: page < 3,
                     nextPostID: page < 3 ? posts.last?.id.postID : nil)
    }
}
#endif
