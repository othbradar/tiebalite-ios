import CoreFoundation
import Foundation
import GeneratedProtobuf
import SwiftProtobuf

/// iOS 22.11.1 CommonZanModel / DelThreadModel / DelPostModel. Read DTOs
/// are independently checked against the iOS binary, not Android parameters.
enum NativeContentActionProtocol {
    enum Operation: Sendable {
        case inspect(ContentActionTarget), like(ContentActionInspection, Bool), delete(ContentActionInspection)
        var isWrite: Bool { if case .inspect = self { false } else { true } }
        var path: String {
            switch self {
            case let .inspect(target): target.kind == .subpost ? "/c/f/pb/floor" : "/c/f/pb/page"
            case .like: "/c/c/agree/opAgree"
            case let .delete(info): info.target.kind == .thread ? "/c/c/bawu/delthread" : "/c/c/bawu/delpost"
            }
        }
        func fields(tbs: String) throws -> [String: String] {
            switch self {
            case let .inspect(target):
                guard target.isValid else { throw ContentActionFailure.unavailable }
                if target.kind == .subpost {
                    return ["kz": String(target.threadID), "pid": String(target.parentPostID), "spid": String(target.postID), "pn": "1"]
                }
                if target.postID > 0 {
                    // iOS storePostID locating branch includes the anchor itself.
                    return ["kz": String(target.threadID), "pid": String(target.postID), "back": "0", "arround": "20"]
                }
                return ["kz": String(target.threadID), "pid": String(target.postID), "pn": "1"]
            case let .like(info, selected):
                guard info.target.isValid, info.liked != nil, info.forumID > 0, info.target.kind != .subpost else {
                    throw ContentActionFailure.unavailable
                }
                // iOS Social.processAttitude uses 3 for threads; PB TopBar uses 1
                // for ordinary replies. Its separate FP-without-floor branch uses 2.
                return ["thread_id": String(info.target.threadID),
                        "post_id": String(info.target.kind == .thread ? info.firstPostID : info.target.postID),
                        "forum_id": String(info.forumID), "obj_type": info.target.kind == .thread ? "3" : "1",
                        "agree_type": "2", "op_type": selected ? "0" : "1"]
            case let .delete(info):
                guard info.canDelete, !tbs.isEmpty else { throw ContentActionFailure.unavailable }
                if info.target.kind == .thread {
                    return ["z": String(info.target.threadID), "fid": String(info.forumID), "word": info.forumName, "tbs": tbs]
                }
                return ["z": String(info.target.threadID), "pid": String(info.target.postID)]
            }
        }
    }

    static func request(_ operation: Operation, runtime: NativeWriteRuntimeContext, tbs: String) throws -> HTTPRequest {
        let business = try operation.fields(tbs: tbs)
        var parameters = NativeWriteStaticCommonParameters()
        let fields = parameters.parameters(runtime.common.staticValues, mode: runtime.common.staticMode)
        var metrics = NativeWriteRequestMetrics(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0)
        let common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: fields, business: business, context: runtime.common.dynamicValues, metrics: &metrics)
        guard common["BDUSS"]?.isEmpty == false else { throw ContentActionFailure.loginRequired }
        if case let .inspect(target) = operation {
            let signed = NativeWriteSigning.common(common, business: business, metadata: runtime.common.metadata)
            return try NativeWriteHTTPRequest.protobufRequest(
                endpoint: (operation.path, target.kind == .subpost ? 302002 : 302001),
                bytes: encodeRead(business, common: signed, subpost: target.kind == .subpost),
                context: runtime.http, boundary: runtime.multipartBoundary, responseBodyLimit: 4 * 1_024 * 1_024)
        }
        let signed = NativeWriteSigning.tbsForm(common, business: business)
        var headers = try runtime.http.cookies.headerFields()
        headers["User-Agent"] = runtime.http.userAgent; headers["Accept-Language"] = runtime.http.acceptLanguage
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        if runtime.http.clientLogID != 0 && runtime.http.clientLogID != -1 { headers["client_logid"] = String(runtime.http.clientLogID) }
        guard let url = URL(string: "https://tiebac.baidu.com" + operation.path) else { throw ContentActionFailure.unavailable }
        return try HTTPRequest(method: .post, url: url, headers: headers, body: NativeTBSRequest.encode(signed),
                               timeout: signed["net_type"] == "1" ? 10 : 25, responseBodyLimit: 1_024 * 1_024)
    }

    static func encodeRead(_ fields: [String: String], common: [String: String], subpost: Bool) throws -> Data {
        var common = common
        for key in ["personalized_rec_switch", "net_type"] where common[key]?.isEmpty == true { common[key] = "0" }
        var data: [String: Any] = fields; data["common"] = common
        let bytes = try JSONSerialization.data(withJSONObject: ["data": data])
        var options = JSONDecodingOptions(); options.ignoreUnknownFields = true
        var encoding = BinaryEncodingOptions(); encoding.useDeterministicOrdering = true
        if subpost { return try TiebaNativeActions_FloorRequest(jsonUTF8Bytes: bytes, options: options).serializedData(options: encoding) }
        return try TiebaNativeActions_PageRequest(jsonUTF8Bytes: bytes, options: options).serializedData(options: encoding)
    }

    static func inspect(_ response: HTTPResponse, target: ContentActionTarget, account: Int64) throws -> ContentActionInspection {
        guard (200..<300).contains(response.statusCode), !response.body.isEmpty, account > 0 else {
            throw ContentActionFailure.unavailable
        }
        if target.kind == .subpost { return try inspectSubpost(response.body, target: target, account: account) }
        let value = try TiebaNativeActions_PageResponse(serializedBytes: response.body)
        guard value.hasError, value.error.errorno == 0, value.hasData,
              value.data.user.id == account else { throw ContentActionFailure.unavailable }
        let data = value.data, thread = data.thread
        guard thread.id == target.threadID || thread.tid == target.threadID,
              thread.isDeleted == 0, data.forum.id > 0 else { throw ContentActionFailure.unavailable }
        let posts = data.postList + (data.hasFirstFloorPost ? [data.firstFloorPost] : [])
        let post = target.kind == .thread ? posts.first(where: { $0.floor == 1 }) : posts.first(where: { $0.id == UInt64(target.postID) })
        guard let post else { throw ContentActionFailure.unavailable }
        let author = post.author.id > 0 ? post.author.id : post.authorID
        let agreement = target.kind == .thread && thread.hasAgree ? thread.agree : post.agree
        let hasAgreement = target.kind == .thread ? (thread.hasAgree || post.hasAgree) : post.hasAgree
        return .init(target: target, accountID: account, authorID: author, forumID: data.forum.id,
                     forumName: data.forum.name, firstPostID: Int64(exactly: post.id) ?? 0,
                     likeCount: hasAgreement ? max(0, agreement.hasDiffAgreeNum ? agreement.diffAgreeNum : agreement.agreeNum) : nil,
                     liked: hasAgreement ? isLiked(agreement) : nil,
                     permitsOwnDeletion: author == account && thread.tiebaplusCantDelete == 0)
    }

    private static func inspectSubpost(_ bytes: Data, target: ContentActionTarget, account: Int64) throws -> ContentActionInspection {
        let value = try TiebaNativeActions_FloorResponse(serializedBytes: bytes)
        let data = value.data
        guard value.hasError, value.error.errorno == 0, value.hasData,
              data.thread.id == target.threadID || data.thread.tid == target.threadID,
              data.post.id == UInt64(target.parentPostID), data.forum.id > 0,
              let post = data.subpostList.first(where: { $0.id == UInt64(target.postID) }) else {
            throw ContentActionFailure.unavailable
        }
        let author = post.author.id > 0 ? post.author.id : post.authorID
        return .init(target: target, accountID: account, authorID: author, forumID: data.forum.id,
                     forumName: data.forum.name, firstPostID: 0, likeCount: nil, liked: nil,
                     permitsOwnDeletion: author == account && data.thread.isDeleted == 0 && data.thread.tiebaplusCantDelete == 0)
    }

    private static func isLiked(_ agree: TiebaNativeActions_Agree) -> Bool? {
        // The native model treats an omitted zero has_agree as unselected.
        // Require an actual agreement payload, never an absent/empty response.
        guard agree.hasHasAgree_p || agree.hasAgreeNum || agree.hasDiffAgreeNum else { return nil }
        if agree.hasAgree_p == 0 { return false }
        guard agree.hasAgree_p == 1, agree.hasAgreeType, [2, 5].contains(agree.agreeType) else { return nil }
        return agree.agreeType == 2
    }

    static func acknowledge(_ response: HTTPResponse) throws {
        guard (200..<300).contains(response.statusCode), !response.body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let code = integer(object["error_code"]) else { throw ContentActionFailure.outcomeUnknown }
        guard code == 0 else { throw ContentActionFailure.rejected }
    }
    private static func integer(_ value: Any?) -> Int? {
        if let text = value as? String { return Int(text) }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
           number.doubleValue == Double(number.intValue) { return number.intValue }
        return nil
    }
}
