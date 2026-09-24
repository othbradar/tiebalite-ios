import CryptoKit
import Foundation
import GeneratedProtobuf
import SwiftProtobuf

struct TextWriteAccount: Sendable, CustomStringConvertible {
    let userID: String
    let tbs: String
    var description: String { "TextWriteAccount(redacted)" }
}

enum TextWriteOutcome: Sendable {
    case success(TextWriteReceipt)
    case failure(TextWriteFailure)
}

enum TextWriteProtocol {
    static let jsonResponseMIMETypes = ["application/json", "text/json", "text/plain", "application/x-javascript"]

    static func descriptor(for kind: TextComposeTarget.Kind, userID: String) throws -> EndpointDescriptor {
        let isThread = kind == .thread
        guard let id = EndpointID(isThread ? "write.thread" : "write.post") else { throw TextWriteFailure.invalidTarget }
        var headers = ["User-Agent": isThread ? "bdtb for Android 7.2.0.0" : postUserAgent,
                       "client_user_token": userID]
        if !isThread {
            headers["Charset"] = "UTF-8"
            headers["x_bd_data_type"] = "protobuf"
        }
        return try EndpointDescriptor(
            id: id, method: .post, host: isThread ? "c.tieba.baidu.com" : "tiebac.baidu.com",
            path: isThread ? "/c/c/thread/add" : "/c/c/post/add",
            queryItems: isThread ? [] : [.init(name: "cmd", value: "309731"), .init(name: "format", value: "protobuf")],
            fixedHeaders: headers,
            bodyCodec: isThread ? .formURLEncoded : .multipartBinary,
            responseFamily: isThread ? .json : .protobuf,
            allowedResponseMIMETypes: isThread ? jsonResponseMIMETypes
                : ["application/octet-stream", "application/x-protobuf"],
            authentication: .active, timeout: 30, responseBodyLimit: 1_024 * 1_024,
            redirectPolicy: .reject, retryPolicy: .never)
    }

    static let postUserAgent = PersonalizedProtocol.androidUserAgent.replacingOccurrences(of: "12.52.1.0", with: "12.35.1.0")

    static func body(_ request: TextWriteRequest, authorization: SessionAuthorization,
                     account: TextWriteAccount) throws -> EndpointRequestBody {
        guard request.target.isValid else { throw TextWriteFailure.invalidTarget }
        guard request.draft.isSendable else { throw TextWriteFailure.invalidDraft }
        if request.target.kind == .thread {
            return .formURLEncoded(threadFields(request, authorization: authorization, account: account))
        }
        return .multipartBinary(boundary: PersonalizedProtocol.boundary,
                                fields: postFields(authorization),
                                part: .init(name: "data", filename: "file", mimeType: nil,
                                            data: try postRequest(
                                                request, authorization: authorization, account: account).serializedData()))
    }

    // CommonParamInterceptor appends these before SortAndSignInterceptor sees the multipart.
    // Only non-file fields are signed; the Protobuf data part is excluded.
    private static func postFields(_ authorization: SessionAuthorization) -> [EndpointField] {
        signedFields([
            "BDUSS": authorization.bduss, "stoken": authorization.stoken,
            "_client_type": "2", "_client_version": "12.35.1.0", "net_type": "1",
            "cmode": "1", "cuid_gid": "", "extra": "", "framework_ver": "3340042",
            "from": "tieba", "is_teenager": "0", "naws_game_ver": "1038000",
            "personalized_rec_switch": "1", "sdk_ver": "2.34.0", "start_scheme": "", "start_type": "1", "z_id": ""
        ])
    }

    static func postRequest(_ request: TextWriteRequest, authorization: SessionAuthorization,
                            account: TextWriteAccount) -> Tieba_AddPost_AddPostRequest {
        let target = request.target
        var common = Tieba_CommonRequest()
        common.clientType = 2
        common.clientVersion = "12.35.1.0"
        common.from = "1020031h"
        common.userAgent = postUserAgent
        common.bduss = authorization.bduss
        let sessionToken = authorization.stoken
        common.stoken = sessionToken
        common.tbs = account.tbs
        var data = Tieba_AddPost_AddPostRequestData()
        data.common = common
        data.anonymous = "1"
        data.canNoForum = "0"
        data.content = request.draft.content
        if target.kind == .subpostReply, let recipient = target.recipient, let portrait = recipient.portrait {
            data.content = "回复 #(reply, \(portrait), \(recipient.displayName)) :\(request.draft.content)"
        }
        data.entranceType = "0"
        data.fid = String(target.forumID)
        data.floorNum = "0"
        data.kw = target.forumName
        data.isAd = "0"
        data.isAddition = "0"
        data.isBarrage = "0"
        data.isFeedback = "0"
        data.isGiftpost = "0"
        data.isPictxt = "0"
        data.isShowBless = 0
        data.isTwzhiboThread = "0"
        data.newVcode = "1"
        data.showCustomFigure = 0
        data.takephotoNum = "0"
        data.tid = String(target.threadID)
        data.vcodeTag = "12"
        if target.kind == .threadReply {
            data.barrageTime = "0"
            data.postFrom = "13"
            data.vFid = ""
            data.vFname = ""
        } else {
            data.quoteID = String(target.postID)
            data.repostid = String(target.postID)
            data.replyUid = String(target.recipient?.rawUserID ?? 0)
            if target.kind == .floorReply { data.postFrom = "0" }
            if target.kind == .subpostReply { data.subPostID = String(target.subpostID) }
        }
        var message = Tieba_AddPost_AddPostRequest()
        message.data = data
        return message
    }

    static func threadFields(_ request: TextWriteRequest, authorization: SessionAuthorization,
                             account: TextWriteAccount) -> [EndpointField] {
        signedFields([
            "BDUSS": authorization.bduss, "stoken": authorization.stoken, "tbs": account.tbs,
            "_client_type": "2", "_client_version": "7.2.0.0", "from": "1021636m", "subapp_type": "mini",
            "content": request.draft.content, "title": request.draft.title,
            "fid": String(request.target.forumID), "kw": request.target.forumName,
            "is_hide": "1", "is_ntitle": request.draft.title.isEmpty ? "1" : "0",
            "is_feedback": "0", "reply_uid": "null", "takephoto_num": "0", "z_id": "",
            "entrance_type": "1", "vcode_tag": "12", "new_vcode": "1", "anonymous": "1",
            "call_from": "2", "can_no_forum": "0", "cuid_gid": ""
        ])
    }

    static func signedFields(_ values: [String: String]) -> [EndpointField] {
        let raw = values.keys.sorted().map { "\($0)=\(values[$0] ?? "")" }.joined() + "tiebaclient!!!"
        let signature = Insecure.MD5.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        return values.keys.sorted().map { EndpointField(name: $0, value: values[$0] ?? "") }
            + [.init(name: "sign", value: signature)]
    }

    static func decodePost(_ data: Data, target: TextComposeTarget) throws -> TextWriteOutcome {
        let response = try Tieba_AddPost_AddPostResponse(serializedBytes: data)
        let body = response.data
        if !body.anti.vcodeMd5.isEmpty || !body.anti.vcodePicURL.isEmpty || !body.anti.vcodeType.isEmpty
            || (body.info.needVcode != "0" && !body.info.needVcode.isEmpty)
            || !body.info.vcodeMd5.isEmpty || !body.info.vcodePicURL.isEmpty
            || (!body.info.accessState.type.isEmpty && body.info.accessState.type != "0") {
            return .failure(.verificationRequired)
        }
        if response.error.errorCode != 0 { return .failure(.server(Int(response.error.errorCode))) }
        guard let pid = Int64(body.pid), pid > 0 else { return .failure(.resultUnknown) }
        if !body.tid.isEmpty, Int64(body.tid) != target.threadID { return .failure(.resultUnknown) }
        return .success(.init(threadID: target.threadID, postID: pid))
    }

    static func decodeThread(_ data: Data) throws -> TextWriteOutcome {
        let response = try JSONDecoder().decode(TextThreadResponse.self, from: data)
        if response.info?.requiresVerification == true { return .failure(.verificationRequired) }
        guard let code = response.errorCode else { return .failure(.resultUnknown) }
        if code != "0" { return .failure(.server(Int(code) ?? -1)) }
        guard let tid = response.threadID.flatMap(Int64.init), tid > 0,
              let pid = response.postID.flatMap(Int64.init), pid > 0 else { return .failure(.resultUnknown) }
        return .success(.init(threadID: tid, postID: pid))
    }
}

private struct TextThreadResponse: Decodable {
    let errorCode: String?
    let threadID: String?
    let postID: String?
    let info: TextVerificationInfo?
    enum CodingKeys: String, CodingKey { case errorCode = "error_code", threadID = "tid", postID = "pid", info }
    init(from decoder: any Swift.Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = try values.flexibleString(forKey: .errorCode)
        threadID = try values.flexibleString(forKey: .threadID)
        postID = try values.flexibleString(forKey: .postID)
        info = try values.decodeIfPresent(TextVerificationInfo.self, forKey: .info)
    }
}

private struct TextVerificationInfo: Decodable {
    let need: String?
    let url: String?
    enum CodingKeys: String, CodingKey { case need = "need_vcode", url = "vcode_pic_url" }
    init(from decoder: any Swift.Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        need = try values.flexibleString(forKey: .need)
        url = try values.decodeIfPresent(String.self, forKey: .url)
    }
    var requiresVerification: Bool { (need != "0" && need?.isEmpty == false) || url?.isEmpty == false }
}

extension KeyedDecodingContainer {
    func flexibleString(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(String.self, forKey: key) { return value }
        return String(try decode(Int64.self, forKey: key))
    }
}
