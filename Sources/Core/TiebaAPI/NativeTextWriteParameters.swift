import Foundation

/// Verified plain-text branches of the 22.11.1 business builders. This does not
/// prepare CommonReq, sign, upload, or select a route on behalf of the caller.
enum NativeTextWriteParameters {
    enum ReplyContainer: Sendable { case threadPage, subposts }

    struct ReplyContext: Sendable {
        let container: ReplyContainer
        let pageEntryType: Int
        let floorNumber: String
        let replyCount: String?
    }

    static func reply(_ request: TextWriteRequest, preparedContent: String, account: TextWriteAccount,
                      context: ReplyContext) throws -> [String: String] {
        try validate(request, account: account)
        let target = request.target
        guard target.kind != .thread else { throw TextWriteFailure.invalidTarget }
        var fields = [
            "anonymous": "0", "floor_num": context.floorNumber, "content": preparedContent,
            "fid": String(target.forumID), "tid": String(target.threadID), "kw": target.forumName,
            "vcode_tag": "12", "tbs": account.tbs, "new_vcode": "1", "is_addition": "0",
            "is_location": "1", "st_param": "pb", "post_from": postFrom(pageEntryType: context.pageEntryType),
            "name_show": account.nameShow, "with_tail": "0", "show_custom_figure": "0"
        ]
        let level: String
        switch target.kind {
        case .thread: throw TextWriteFailure.invalidTarget
        case .threadReply: level = "reply"
        case .floorReply: level = "sub"
        case .subpostReply: level = "subsub"
        }
        fields["send_from"] = ["pb", context.container == .subposts ? "sub" : nil, level]
            .compactMap { $0 }.joined(separator: "_")
        if target.kind != .threadReply {
            fields["quote_id"] = String(target.postID)
            // The native builder replaces a sub-reply's repostid with quote_id.
            fields["repostid"] = String(target.postID)
            fields["reply_uid"] = target.recipient.map { String($0.rawUserID) }
        }
        if target.kind == .subpostReply { fields["sub_post_id"] = String(target.subpostID) }
        // This dictionary-only field can participate in signing, but is not in IDL.
        fields["floor"] = context.replyCount
        return fields
    }

    static func thread(_ request: TextWriteRequest, preparedContent: String, account: TextWriteAccount,
                       entranceType: Int) throws -> [String: String] {
        try validate(request, account: account)
        guard request.target.kind == .thread, (0...4).contains(entranceType) else {
            throw TextWriteFailure.invalidTarget
        }
        let hasTitle = !request.draft.title.isEmpty
        var fields = [
            "title": request.draft.title, "anonymous": "0", "content": preparedContent,
            "fid": String(request.target.forumID), "kw": request.target.forumName, "tbs": account.tbs,
            "vcode_tag": "12", "new_vcode": "1", "is_ntitle": hasTitle ? "0" : "1",
            "call_from": String(entranceType), "can_no_forum": "0", "is_hide": "1", "pro_zone": "0",
            "takephoto_num": "0", "name_show": account.nameShow, "is_general_tab": "0",
            "is_forum_business_account": "0", "is_pictxt": "0", "is_article": "0",
            "show_custom_figure": "0", "is_question": "0", "sendThreadCategory": "0"
        ]
        if !hasTitle { fields["st_type"] = "notitle" }
        return fields
    }

    private static func validate(_ request: TextWriteRequest, account: TextWriteAccount) throws {
        guard request.target.isValid else { throw TextWriteFailure.invalidTarget }
        guard request.draft.isSendable, request.draft.photos.isEmpty else { throw TextWriteFailure.invalidDraft }
        guard !account.tbs.isEmpty, !account.userID.isEmpty else { throw TextWriteFailure.authentication }
    }

    private static func postFrom(pageEntryType: Int) -> String {
        // TBCPbReplayModel.transPBReplyEnterTypeToStringParam:, 22.11.1.
        let values = [3: "2", 4: "18", 5: "3", 7: "15", 12: "4", 13: "4", 14: "7", 18: "9",
                      28: "10", 29: "4", 30: "11", 31: "6", 32: "5", 34: "8", 37: "12", 38: "12", 39: "13"]
        return values[pageEntryType] ?? "0"
    }
}
