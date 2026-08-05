import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum FRSPageProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case forumIdentityMismatch
    case invalidItems
    case invalidStaticConfiguration
    case missingData
    case missingForum
}

enum FRSPageProtocol {
    struct WireInspection: Equatable, Sendable {
        let decoded: Bool
        let hasServerError: Bool
    }

    static let boundary = PersonalizedProtocol.boundary
    static let fixtureResponseMIMEType = "application/x-protobuf"
    static let liveResponseMIMEType = "application/octet-stream"
    static let allowedResponseMIMETypes = [
        fixtureResponseMIMEType,
        liveResponseMIMEType
    ]

    static func makeDescriptor(
        host: String,
        route: ForumRoute
    ) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("forum.frsPage") else {
            throw FRSPageProtocolError.invalidStaticConfiguration
        }
        var headers = PersonalizedProtocol.anonymousV12Headers
        headers["forum_name"] = formEncode(route.forumName.rawValue)
        return try EndpointDescriptor(
            id: identifier,
            method: .post,
            host: host,
            path: "/c/f/frs/page",
            queryItems: [EndpointField(name: "cmd", value: "301001")],
            fixedHeaders: headers,
            bodyCodec: .multipartBinary,
            responseFamily: .protobuf,
            allowedResponseMIMETypes: allowedResponseMIMETypes,
            authentication: .anonymous,
            timeout: 30,
            responseBodyLimit: 8 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func encodeRequest(route: ForumRoute) throws -> Data {
        var adParam = Tieba_FrsPage_AdParam()
        adParam.loadCount = 0
        adParam.refreshCount = 4
        adParam.yogaLibVersion = "1.0"

        var common = Tieba_CommonRequest()
        common.clientType = 2
        common.clientVersion = PersonalizedProtocol.androidClientVersion
        common.from = "1020031h"
        common.userAgent = PersonalizedProtocol.androidUserAgent

        var data = Tieba_FrsPage_FrsPageRequestData()
        data.adParam = adParam
        data.callFrom = 0
        data.categoryID = 0
        data.cid = 0
        data.common = common
        data.ctime = 0
        data.dataSize = 0
        data.hotThreadID = 0
        data.isDefaultNavtab = 0
        data.isGood = 0
        data.isSelection = 0
        data.kw = formEncode(route.forumName.rawValue)
        data.lastClickTid = 0
        data.loadType = 1
        data.netError = 0
        data.pn = 1
        data.qType = 2
        data.rn = 90
        data.rnNeed = 30
        data.sortType = 0
        data.stParam = 0
        data.stType = "recom_flist"
        data.upSchema = ""
        data.withGroup = 1
        data.yuelaouLocate = ""

        var request = Tieba_FrsPage_FrsPageRequest()
        request.data = data
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try request.serializedData(options: options)
    }

    static func makeRequestBody(
        route: ForumRoute
    ) throws -> EndpointRequestBody {
        .multipartBinary(
            boundary: boundary,
            fields: [],
            part: MultipartBinaryPart(
                name: "data",
                filename: "file",
                mimeType: nil,
                data: try encodeRequest(route: route)
            )
        )
    }

    static func decode(
        _ bytes: Data
    ) throws -> Tieba_FrsPage_FrsPageResponse {
        guard !bytes.isEmpty else {
            throw FRSPageProtocolError.emptyBody
        }
        let response = try Tieba_FrsPage_FrsPageResponse(
            serializedBytes: bytes
        )
        if response.hasError, response.error.errorCode != 0 {
            throw EndpointWireFailure.server(
                code: Int(response.error.errorCode)
            )
        }
        return response
    }

    static func inspectForDiagnostics(_ bytes: Data) -> WireInspection {
        guard !bytes.isEmpty,
              let response = try? Tieba_FrsPage_FrsPageResponse(
                  serializedBytes: bytes
              ) else {
            return WireInspection(decoded: false, hasServerError: false)
        }
        return WireInspection(
            decoded: true,
            hasServerError: response.hasError && response.error.errorCode != 0
        )
    }

    static func map(
        _ response: Tieba_FrsPage_FrsPageResponse,
        requestedRoute: ForumRoute
    ) throws -> ForumHomeSnapshot {
        guard response.hasData else {
            throw FRSPageProtocolError.missingData
        }
        let data = response.data
        guard data.hasForum else {
            throw FRSPageProtocolError.missingForum
        }
        let forum = data.forum
        if let requestedID = requestedRoute.forumID,
           forum.id > 0,
           forum.id != requestedID.rawValue {
            throw FRSPageProtocolError.forumIdentityMismatch
        }

        let forumName = nonempty(
            forum.name,
            fallback: requestedRoute.forumName.rawValue
        )
        let users = Dictionary(
            data.userList.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var seenItemIDs: Set<Int64> = []
        let threads = data.threadList.compactMap { thread -> ForumThreadSummary? in
            guard thread.id > 0,
                  thread.threadID > 0,
                  seenItemIDs.insert(thread.id).inserted else {
                return nil
            }
            return ForumThreadSummary(
                itemID: thread.id,
                threadID: thread.threadID,
                title: threadTitle(thread),
                forumName: nonempty(thread.forumName, fallback: forumName),
                authorName: authorName(thread, users: users),
                replyCount: max(0, thread.replyNum),
                viewCount: max(0, thread.viewNum),
                isPinned: thread.isTop == 1
            )
        }
        guard data.threadList.isEmpty || !threads.isEmpty else {
            throw FRSPageProtocolError.invalidItems
        }

        return ForumHomeSnapshot(
            forum: ForumSummary(
                forumID: forum.id > 0
                    ? forum.id
                    : requestedRoute.forumID?.rawValue,
                name: forumName,
                slogan: nonempty(forum.slogan),
                avatarResourceID: nonempty(forum.avatar),
                memberCount: Int(max(0, forum.memberNum)),
                threadCount: Int(max(0, forum.threadNum)),
                postCount: Int(max(0, forum.postNum))
            ),
            threads: threads
        )
    }

    static func pipeline(
        requestedRoute: ForumRoute
    ) -> EndpointPipeline<
        Tieba_FrsPage_FrsPageResponse,
        ForumHomeSnapshot
    > {
        EndpointPipeline(
            decode: decode,
            map: { response in
                try map(response, requestedRoute: requestedRoute)
            }
        )
    }

    private static func authorName(
        _ thread: Tieba_ThreadInfo,
        users: [Int64: Tieba_User]
    ) -> String {
        if let user = users[thread.authorID] {
            return nonempty(
                user.nameShow,
                fallback: nonempty(user.name, fallback: "未知作者")
            )
        }
        if thread.hasAuthor {
            return nonempty(
                thread.author.nameShow,
                fallback: nonempty(thread.author.name, fallback: "未知作者")
            )
        }
        return "未知作者"
    }

    private static func threadTitle(_ thread: Tieba_ThreadInfo) -> String {
        let title = thread.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !title.isEmpty {
            return title
        }
        let richAbstract = thread.richAbstract
            .filter { $0.type == 0 || $0.type == 40 }
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return richAbstract.isEmpty ? "无标题" : richAbstract
    }

    private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonempty(
        _ value: String,
        fallback: String
    ) -> String {
        nonempty(value) ?? fallback
    }

    private static func formEncode(_ value: String) -> String {
        let hexadecimal = Array("0123456789ABCDEF".utf8)
        var output = [UInt8]()
        for byte in value.utf8 {
            switch byte {
            case 32:
                output.append(43)
            case 42, 45, 46, 48...57, 65...90, 95, 97...122:
                output.append(byte)
            default:
                output.append(37)
                output.append(hexadecimal[Int(byte >> 4)])
                output.append(hexadecimal[Int(byte & 0x0F)])
            }
        }
        return String(bytes: output, encoding: .utf8) ?? ""
    }
}
