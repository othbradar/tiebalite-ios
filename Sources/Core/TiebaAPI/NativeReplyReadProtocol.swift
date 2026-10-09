import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum NativeReplyReadError: Error, Equatable, Sendable {
    case alreadyLoading
    case invalidContext
    case unsupportedPageContext
    case unsupportedContentType
    case server(Int32)
    case missingTarget
}

/// iOS CMD309751 uses PbList, not the unrelated GetMyPost descriptor. The
/// prepared page provider remains explicit; this boundary never guesses one.
enum NativeReplyReadProtocol {
    static func errorCode(_ bytes: Data) throws -> Int32 {
        guard !bytes.isEmpty else { throw HTTPClientError.malformedResponse }
        return try TiebaNativeWrite_ReplyReadResponse(serializedBytes: bytes).error.errorno
    }
    static func encode(business: [String: String], common: [String: String]) throws -> Data {
        guard ["push_info", "app_transmit_data"].allSatisfy({ business[$0] == nil }) else {
            throw NativeReplyReadError.unsupportedPageContext
        }
        var common = common
        for key in ["personalized_rec_switch", "net_type"] where common[key]?.isEmpty == true { common[key] = "0" }
        var fields: [String: Any] = business
        if let ad = business["ad_param"] { fields["ad_param"] = try NativeReplyPageParameters.adParameters(ad) }
        fields["common"] = common
        let json = try JSONSerialization.data(withJSONObject: ["data": fields], options: [.sortedKeys])
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true // offset participates in signing, but is absent from this native IDL.
        return try TiebaNativeWrite_ReplyReadRequest(jsonUTF8Bytes: json, options: options).serializedData()
    }

    static func request(business: [String: String], common: [String: String],
                        context: NativeWriteHTTPContext, boundary: String) throws -> HTTPRequest {
        guard business["kz"].flatMap(Int64.init).map({ $0 > 0 }) == true,
              business["last_pid"].flatMap(Int64.init).map({ $0 > 0 }) == true,
              business["mark_type"] == "2" else { throw NativeReplyReadError.invalidContext }
        return try NativeWriteHTTPRequest.protobufRequest(
            endpoint: ("/c/f/pb/getmypost", 309751), bytes: encode(business: business, common: common),
            context: context, boundary: boundary, responseBodyLimit: 4 * 1_024 * 1_024)
    }

    static func decode(_ bytes: Data, threadID: Int64, targetPostID: Int64) throws -> ReplyReadUpdate {
        guard !bytes.isEmpty, threadID > 0, targetPostID > 0 else { throw NativeReplyReadError.invalidContext }
        let envelope = try TiebaNativeWrite_ReplyReadResponse(serializedBytes: bytes)
        guard envelope.error.errorno <= 0 else { throw NativeReplyReadError.server(envelope.error.errorno) }
        let data = envelope.data
        guard envelope.hasData, data.hasThread, data.hasPage else { throw HTTPClientError.malformedResponse }
        // These payload DTOs have an independent iOS descriptor audit. Only the
        // pure domain mapper is reused; no Android request/envelope is executed.
        var projected = Tieba_PbPage_PbPageResponse()
        projected.data.thread = try Tieba_ThreadInfo(serializedBytes: data.thread)
        let thread = projected.data.thread
        guard thread.id == 0 || thread.id == threadID,
              thread.threadID == 0 || thread.threadID == threadID,
              thread.id > 0 || thread.threadID > 0 else { throw NativeReplyReadError.invalidContext }
        projected.data.page = try Tieba_Page(serializedBytes: data.page)
        guard projected.data.page.currentPage >= 0 else { throw HTTPClientError.malformedResponse }
        if data.hasForum { projected.data.forum = try Tieba_SimpleForum(serializedBytes: data.forum) }
        projected.data.userList = try data.userList.map { try Tieba_User(serializedBytes: $0) }
        projected.data.postList = try data.postList.map(decodePost)
        if data.hasFirstFloor { projected.data.firstFloorPost = try decodePost(data.firstFloor) }
        if projected.data.page.currentPage == 0 {
            let posts = try PBPageDomainMapper.replyPosts(projected.data, threadID: threadID)
            guard posts.contains(where: { $0.id.postID == targetPostID }) else { throw NativeReplyReadError.missingTarget }
            return .posts(.init(threadID: threadID, replyCount: thread.replyNum, posts: posts))
        }
        let page = Int(projected.data.page.currentPage)
        let hasFirst = projected.data.hasFirstFloorPost || projected.data.postList.contains { $0.floor == 1 }
        let result = try PBPageDomainMapper.map(projected, request: .init(
            threadID: threadID, pageNumber: page == 1 && hasFirst ? 0 : page, postID: targetPostID))
        guard result.posts.contains(where: { $0.id.postID == targetPostID }) else {
            throw NativeReplyReadError.missingTarget
        }
        return .page(result)
    }

    private static func decodePost(_ bytes: Data) throws -> Tieba_Post {
        let post = try Tieba_Post(serializedBytes: bytes)
        // Native PbContent.type is uint32 while the established display DTO
        // uses int32. Do not reinterpret an out-of-range native discriminator.
        let content = post.content + post.subPostList.subPostList.flatMap(\.content)
        guard content.allSatisfy({ $0.type >= 0 }) else { throw NativeReplyReadError.unsupportedContentType }
        return post
    }
}
