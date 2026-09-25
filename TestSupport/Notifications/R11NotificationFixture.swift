#if DEBUG
import Foundation
@testable import TiebaLite

/// Synthetic JSON shaped from Android MessageListBean. No captured account data.
enum R11NotificationFixture {
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
#endif
