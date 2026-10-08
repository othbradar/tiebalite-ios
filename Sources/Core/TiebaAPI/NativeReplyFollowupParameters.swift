import Foundation

/// Parameter transformations at the native post-reply read boundary. These
/// consume prepared iOS PB context, not the Android page builder. Validation of
/// the target/receipt, branch choice, HTTP/IDL and list updates belong to callers.
/// Nothing here sends, retries, clears drafts, or changes the reading anchor.
enum NativeReplyFollowupParameters {
    struct Load: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
        let parameters: [String: String]
        let requestCount: Int64

        var description: String { "NativeReplyFollowupLoad(redacted)" }
        var debugDescription: String { description }
    }

    /// The native controller validates nonempty IDs before calling this builder.
    static func floor(threadID: String?, replyPostID: String?) -> [String: String] {
        var fields = ["mark_type": "2"]
        fields["kz"] = threadID
        fields["last_pid"] = replyPostID
        return fields
    }

    /// This is the non-legacy page branch. The separate folded-page builder is
    /// not inferred from includesFoldedComments, which is a different flag.
    static func ordinaryThread(preparedPageFields: [String: String]?, replyPostID: String?,
                               includesFoldedComments: Bool) -> [String: String]? {
        guard var fields = preparedPageFields, !fields.isEmpty else { return nil }
        for key in ["r", "back", "lz", "pn"] { fields.removeValue(forKey: key) }
        fields["mark_type"] = "2"
        fields["last_pid"] = String(replyPostID.map { ($0 as NSString).integerValue } ?? 0)
        if includesFoldedComments { fields["is_fold_comment_req"] = "1" }
        return fields
    }

    /// Caller commits the returned counter only when dispatching this one read.
    /// Busy native states leave both the parameters and shared count untouched.
    static func threadLoad(preparedFields: [String: String], serverState: Int,
                           requestCount: Int64) -> Load? {
        guard serverState != 1 && serverState != 2 else { return nil }
        let nextCount = requestCount &+ 1
        var fields = preparedFields
        fields["request_times"] = String(nextCount)
        fields["offset"] = "2"
        return Load(parameters: fields, requestCount: nextCount)
    }
}
