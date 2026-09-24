import Foundation

struct TextComposeTarget: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable { case thread, threadReply, floorReply, subpostReply }
    let kind: Kind
    let forumID: Int64
    let forumName: String
    var threadID: Int64 = 0
    var postID: Int64 = 0
    var subpostID: Int64 = 0
    var recipient: TiebaUserVisuals?
    var quote: String = ""

    var id: String { "\(kind.rawValue).\(forumID).\(threadID).\(postID).\(subpostID)" }
    var title: String {
        switch kind {
        case .thread: "发表新帖"
        case .threadReply: "回复主题"
        case .floorReply: "回复楼层"
        case .subpostReply: "回复楼中楼"
        }
    }
    var isValid: Bool {
        guard forumID > 0, !forumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch kind {
        case .thread: return threadID == 0 && postID == 0 && subpostID == 0
        case .threadReply: return threadID > 0 && postID == 0 && subpostID == 0
        case .floorReply: return threadID > 0 && postID > 0 && subpostID == 0 && (recipient?.rawUserID ?? 0) > 0
        case .subpostReply:
            return threadID > 0 && postID > 0 && subpostID > 0 && (recipient?.rawUserID ?? 0) > 0
                && recipient?.portrait?.isEmpty == false
        }
    }
}

struct TextDraft: Equatable, Sendable {
    var title = ""
    var content = ""
    var isSendable: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 31 }
}

struct TextWriteRequest: Equatable, Sendable {
    let target: TextComposeTarget
    let draft: TextDraft
}

struct TextWriteReceipt: Equatable, Sendable {
    let threadID: Int64
    let postID: Int64
}

enum TextWriteFailure: Error, Equatable, Sendable {
    case authentication, invalidTarget, invalidDraft, verificationRequired, resultUnknown
    case network, http(Int), server(Int), malformedResponse

    var message: String {
        switch self {
        case .authentication: "登录状态已失效或发生变化，请重新登录后打开编辑器。草稿已保留。"
        case .invalidTarget: "回复目标资料不完整，请返回重新加载页面。"
        case .invalidDraft: "请输入正文；标题最多 31 字。"
        case .verificationRequired: "服务端要求验证码或安全验证，当前暂不支持。草稿已保留，请使用官方客户端完成验证。"
        case .resultUnknown: "尚未确认发送结果，请先返回帖子检查，避免重复发送。草稿已保留。"
        case .network: "网络连接失败，草稿已保留。"
        case .http(let code): "服务暂不可用（HTTP \(code)），草稿已保留。"
        case .server(let code): "发送未成功（服务端代码 \(code)）。可能需要在官方客户端处理账号限制，草稿已保留。"
        case .malformedResponse: "发送前获取账号资料失败，尚未提交帖子或回复。草稿已保留。"
        }
    }
}

protocol TextWriteRepository: Sendable {
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt
}
