import Foundation

/// The ordinary non-advertising page owned by this app. No foreign SDK,
/// advertisement, push or arbitrary Scheme dictionary is manufactured here.
enum NativeReplyPageParameters {
    // registerAllSwitchDatas registers pb_reply_switch with defaultValue = 1.
    static func enabled(override: Int?) -> Bool { (override ?? 1) != 0 }

    static func fields(_ request: ReplyFollowupRequest, target: TextComposeTarget,
                       requestCount: Int64) throws -> [String: String] {
        guard request.receipt.threadID == target.threadID, request.receipt.postID > 0,
              request.page > 0, target.kind != .thread else {
            throw NativeReplyReadError.invalidContext
        }
        let targetID = target.kind == .threadReply ? request.receipt.postID : target.postID
        guard targetID > 0 else { throw NativeReplyReadError.invalidContext }
        if target.kind != .threadReply {
            return NativeReplyFollowupParameters.floor(threadID: String(target.threadID), replyPostID: String(targetID))
        }
        // No advertising/Vitality cache exists in this app. The native absent-cache
        // branch returns zero; pbReplayGetLastPage sets style 4, adding one load.
        let ad: [String: Any] = ["load_count": "1", "refresh_count": "0", "is_req_ad": 0]
        let encoded = try JSONSerialization.data(withJSONObject: ad, options: [.sortedKeys])
        guard let text = String(data: encoded, encoding: .utf8) else { throw NativeReplyReadError.invalidContext }
        var fields = ["kz": String(target.threadID), "pn": String(request.page),
                      "fr": request.entry == .forum ? "frs" : (request.entry == .search ? "search_page" : ""),
                      "ad_param": text, "session_request_times": "0"]
        // The dedicated model requests the prepared context with sessionRequestTimes:0.
        guard let prepared = NativeReplyFollowupParameters.ordinaryThread(
            preparedPageFields: fields, replyPostID: String(targetID), includesFoldedComments: false),
            let load = NativeReplyFollowupParameters.threadLoad(
                preparedFields: prepared, serverState: 0, requestCount: requestCount &+ 1) else {
            throw NativeReplyReadError.invalidContext
        }
        fields = load.parameters
        return fields
    }

    static func adParameters(_ text: String) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              Set(value.keys) == ["load_count", "refresh_count", "is_req_ad"],
              let loads = value["load_count"] as? String, Int32(loads).map({ $0 >= 0 }) == true,
              let refreshes = value["refresh_count"] as? String, Int32(refreshes).map({ $0 >= 0 }) == true,
              let advertising = value["is_req_ad"] as? NSNumber, advertising.doubleValue == 0 else {
            throw NativeReplyReadError.unsupportedPageContext
        }
        return value
    }

    static func signingFields(_ fields: [String: String]) throws -> [String: String] {
        var result = fields
        if let ad = fields["ad_param"] {
            // Native appendFormat:@"%@=%@" receives an NSDictionary here.
            result["ad_param"] = (try adParameters(ad) as NSDictionary).description
        }
        return result
    }
}
