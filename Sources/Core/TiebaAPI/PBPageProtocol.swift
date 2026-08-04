import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum PBPageProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case invalidStaticConfiguration
    case invalidThreadID
    case missingData
    case missingFirstPost
    case missingThread
    case threadIdentityMismatch(requested: Int64, received: Int64)
}

struct PBPageRequestInput: Equatable, Sendable {
    let threadID: Int64

    init(threadID: Int64) throws {
        guard threadID > 0 else {
            throw PBPageProtocolError.invalidThreadID
        }
        self.threadID = threadID
    }
}

enum PBPageProtocol {
    private struct PostMappingContext {
        let threadID: Int64
        let scope: ThreadContentSource.Scope
        let fallbackAuthor: ThreadReaderAuthor?
        let users: [Tieba_User]
        let poll: Tieba_PollInfo?
    }

    static let fixtureResponseMIMEType = "application/x-protobuf"
    static let liveResponseMIMEType = "application/octet-stream"

    static func makeDescriptor(host: String) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("thread.pbPage") else {
            throw PBPageProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier,
            method: .post,
            host: host,
            path: "/c/f/pb/page",
            queryItems: [
                EndpointField(name: "cmd", value: "302001"),
                EndpointField(name: "format", value: "protobuf")
            ],
            fixedHeaders: PersonalizedProtocol.anonymousV12Headers,
            bodyCodec: .multipartBinary,
            responseFamily: .protobuf,
            allowedResponseMIMETypes: [
                fixtureResponseMIMEType,
                liveResponseMIMEType
            ],
            authentication: .anonymous,
            timeout: 30,
            responseBodyLimit: 8 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func encodeRequest(_ input: PBPageRequestInput) throws -> Data {
        var common = Tieba_CommonRequest()
        common.clientType = 2
        common.clientVersion = PersonalizedProtocol.androidClientVersion
        common.from = "1020031h"
        common.userAgent = PersonalizedProtocol.androidUserAgent
        common.personalizedRecSwitch = 1

        var adParameter = Tieba_PbPage_AdParam()
        adParameter.loadCount = 0
        adParameter.refreshCount = 1
        adParameter.isReqAd = 1

        var data = Tieba_PbPage_PbPageRequestData()
        data.pbRn = 0
        data.mark = 0
        data.back = 0
        data.kz = input.threadID
        data.lz = 0
        data.r = 0
        data.pid = 0
        data.withFloor = 1
        data.floorRn = 4
        data.weipost = 0
        data.sModel = 0
        data.rn = 15
        data.qType = 2
        data.pn = 0
        data.stType = ""
        data.threadType = 0
        data.banner = 0
        data.common = common
        data.isCommReverse = 0
        data.isJumpfloor = 0
        data.jumpfloorNum = 0
        data.objSource = ""
        data.objLocate = ""
        data.objParam1 = "10"
        data.fromSmartFrs = 0
        data.forumID = 0
        data.needRepostRecommendForum = 0
        data.adParam = adParameter
        data.oriUgcType = 0
        data.fromPush = 0
        data.broadcastID = 0
        data.floorSortType = 1
        data.sourceType = 2
        data.immersionVideoCommentSource = 0
        data.isFoldCommentReq = 0
        data.requestTimes = 0
        data.lastPid = 0
        data.similarFrom = 0

        var request = Tieba_PbPage_PbPageRequest()
        request.data = data
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try request.serializedData(options: options)
    }

    static func makeRequestBody(
        _ input: PBPageRequestInput
    ) throws -> EndpointRequestBody {
        .multipartBinary(
            boundary: PersonalizedProtocol.boundary,
            fields: [],
            part: MultipartBinaryPart(
                name: "data",
                filename: "file",
                mimeType: nil,
                data: try encodeRequest(input)
            )
        )
    }

    static func decode(
        _ bytes: Data
    ) throws -> Tieba_PbPage_PbPageResponse {
        guard !bytes.isEmpty else {
            throw PBPageProtocolError.emptyBody
        }
        let response = try Tieba_PbPage_PbPageResponse(
            serializedBytes: bytes
        )
        if response.hasError, response.error.errorCode != 0 {
            throw EndpointWireFailure.server(
                code: Int(response.error.errorCode)
            )
        }
        return response
    }

    static func map(
        _ response: Tieba_PbPage_PbPageResponse,
        requestedThreadID: Int64
    ) throws -> ThreadReaderSnapshot {
        guard response.hasData else {
            throw PBPageProtocolError.missingData
        }
        let data = response.data
        guard data.hasThread else {
            throw PBPageProtocolError.missingThread
        }

        let receivedThreadID = firstPositive(
            data.thread.threadID,
            data.thread.id
        )
        if receivedThreadID > 0, receivedThreadID != requestedThreadID {
            throw PBPageProtocolError.threadIdentityMismatch(
                requested: requestedThreadID,
                received: receivedThreadID
            )
        }

        let firstPost = data.postList.first { $0.floor == 1 }
            ?? (data.hasFirstFloorPost ? data.firstFloorPost : nil)
        guard let firstPost,
              let firstReaderPost = makePost(
                  firstPost,
                  context: PostMappingContext(
                      threadID: requestedThreadID,
                      scope: .firstPost,
                      fallbackAuthor: mapAuthor(data.thread.author),
                      users: data.userList,
                      poll: data.thread.hasPollInfo
                          ? data.thread.pollInfo
                          : nil
                  )
              ) else {
            throw PBPageProtocolError.missingFirstPost
        }

        var seenPostIDs: Set<Int64> = [firstReaderPost.id.postID]
        var posts = [firstReaderPost]
        for post in data.postList where post.floor != 1 {
            guard let mapped = makePost(
                post,
                context: PostMappingContext(
                    threadID: requestedThreadID,
                    scope: .post,
                    fallbackAuthor: nil,
                    users: data.userList,
                    poll: nil
                )
            ), seenPostIDs.insert(mapped.id.postID).inserted else {
                continue
            }
            posts.append(mapped)
        }

        return ThreadReaderSnapshot(
            threadID: requestedThreadID,
            title: nonempty(data.thread.title, fallback: "无标题"),
            forumName: forumName(data),
            author: mapAuthor(data.thread.author),
            replyCount: max(0, data.thread.replyNum),
            posts: posts
        )
    }

    static func pipeline(
        requestedThreadID: Int64
    ) -> EndpointPipeline<
        Tieba_PbPage_PbPageResponse,
        ThreadReaderSnapshot
    > {
        EndpointPipeline(
            decode: decode,
            map: { response in
                try map(response, requestedThreadID: requestedThreadID)
            }
        )
    }

    private static func makePost(
        _ post: Tieba_Post,
        context: PostMappingContext
    ) -> ThreadReaderPost? {
        guard post.id > 0,
              post.id <= UInt64(Int64.max) else {
            return nil
        }
        let postID = Int64(post.id)
        let source = ThreadContentSource(
            threadID: context.threadID,
            postID: postID,
            scope: context.scope
        )
        let availability: ThreadContentAvailability = post.isFold == 0
            ? .available
            : .unavailable(.folded(
                message: post.foldTip.isEmpty ? nil : post.foldTip
            ))
        let document = ThreadContentProtoMapper.map(
            postContent: post.content,
            source: source,
            availability: availability,
            poll: context.poll
        )
        let floor = Int(exactly: post.floor) ?? 0
        return ThreadReaderPost(
            floorNumber: context.scope == .firstPost ? max(1, floor) : floor,
            author: postAuthor(
                post,
                fallback: context.fallbackAuthor,
                users: context.users
            ),
            metadata: nonempty(post.timeEx, fallback: "公开帖子"),
            document: document
        )
    }

    private static func postAuthor(
        _ post: Tieba_Post,
        fallback: ThreadReaderAuthor?,
        users: [Tieba_User]
    ) -> ThreadReaderAuthor {
        if post.hasAuthor {
            return mapAuthor(post.author)
        }
        if let user = users.first(where: { user in
            post.authorID > 0 && user.id == post.authorID
        }) {
            return mapAuthor(user)
        }
        return fallback ?? unknownAuthor(rawUserID: post.authorID)
    }

    private static func mapAuthor(_ user: Tieba_User) -> ThreadReaderAuthor {
        let name = nonempty(user.nameShow, fallback: user.name)
        return ThreadReaderAuthor(
            rawUserID: max(0, user.id),
            displayName: nonempty(name, fallback: "未知作者")
        )
    }

    private static func unknownAuthor(rawUserID: Int64) -> ThreadReaderAuthor {
        ThreadReaderAuthor(
            rawUserID: max(0, rawUserID),
            displayName: "未知作者"
        )
    }

    private static func forumName(
        _ data: Tieba_PbPage_PbPageResponseData
    ) -> String {
        if data.hasForum, !data.forum.name.isEmpty {
            return data.forum.name
        }
        return nonempty(data.thread.forumName, fallback: "未知吧")
    }

    private static func firstPositive(_ values: Int64...) -> Int64 {
        values.first(where: { $0 > 0 }) ?? 0
    }

    private static func nonempty(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
