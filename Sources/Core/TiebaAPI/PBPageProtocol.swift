import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum PBPageProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case invalidStaticConfiguration
    case invalidPageNumber
    case invalidPostID
    case invalidThreadID
    case missingData
    case missingFirstPost
    case missingPage
    case missingThread
    case threadIdentityMismatch(requested: Int64, received: Int64)
}

struct PBPageRequestInput: Equatable, Sendable {
    let threadID: Int64
    let pageNumber: Int
    let postID: Int64

    init(
        threadID: Int64,
        pageNumber: Int = 0,
        postID: Int64 = 0
    ) throws {
        guard threadID > 0 else {
            throw PBPageProtocolError.invalidThreadID
        }
        guard pageNumber >= 0, pageNumber <= Int(Int32.max) else {
            throw PBPageProtocolError.invalidPageNumber
        }
        guard postID >= 0 else {
            throw PBPageProtocolError.invalidPostID
        }
        self.threadID = threadID
        self.pageNumber = pageNumber
        self.postID = postID
    }
}

enum PBPageProtocol {
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
        data.pid = input.postID
        data.withFloor = 1
        data.floorRn = 4
        data.weipost = 0
        data.sModel = 0
        data.rn = 15
        data.qType = 2
        data.pn = Int32(input.pageNumber)
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
        try map(
            response,
            request: .initial(threadID: requestedThreadID)
        )
    }

    static func map(
        _ response: Tieba_PbPage_PbPageResponse,
        request: ThreadReaderPageRequest
    ) throws -> ThreadReaderSnapshot {
        try PBPageDomainMapper.map(response, request: request)
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

    static func pipeline(
        request: ThreadReaderPageRequest
    ) -> EndpointPipeline<
        Tieba_PbPage_PbPageResponse,
        ThreadReaderSnapshot
    > {
        EndpointPipeline(
            decode: decode,
            map: { response in
                try map(response, request: request)
            }
        )
    }

}
