import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum PersonalizedProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case invalidPage
    case invalidStaticConfiguration
    case missingData
}

enum PersonalizedLoadKind: UInt32, Equatable, Sendable {
    case refresh = 1
    case nextPage = 2
}

struct PersonalizedRequestInput: Equatable, Sendable {
    let loadKind: PersonalizedLoadKind
    let page: UInt32

    init(
        loadKind: PersonalizedLoadKind,
        page: UInt32
    ) throws {
        guard page > 0 else {
            throw PersonalizedProtocolError.invalidPage
        }
        self.loadKind = loadKind
        self.page = page
    }
}

enum PersonalizedProtocol {
    static let boundary = "--------7da3d81520810*"
    static let fixtureResponseMIMEType = "application/x-protobuf"
    static let liveResponseMIMEType = "application/octet-stream"
    static let androidClientVersion = "12.52.1.0"
    static let androidUserAgent =
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Version/4.0 Chrome/135.0.0.0 " +
        "Mobile Safari/537.36 tieba/\(androidClientVersion)"
    static let anonymousV12Headers = [
        "Charset": "UTF-8",
        "User-Agent": androidUserAgent,
        "client_type": "2",
        "x_bd_data_type": "protobuf"
    ]

    static func makeDescriptor(host: String) throws -> EndpointDescriptor {
        try makeDescriptor(host: host, authentication: .anonymous)
    }

    static func makeActiveDescriptor(
        host: String
    ) throws -> EndpointDescriptor {
        try makeDescriptor(host: host, authentication: .active)
    }

    private static func makeDescriptor(
        host: String,
        authentication: EndpointAuthenticationRequirement
    ) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("recommendations.personalized") else {
            throw PersonalizedProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier,
            method: .post,
            host: host,
            path: "/c/f/excellent/personalized",
            queryItems: [EndpointField(name: "cmd", value: "309264")],
            fixedHeaders: anonymousV12Headers,
            bodyCodec: .multipartBinary,
            responseFamily: .protobuf,
            allowedResponseMIMETypes: [
                fixtureResponseMIMEType,
                liveResponseMIMEType
            ],
            authentication: authentication,
            timeout: 30,
            responseBodyLimit: 8 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func encodeRequest(
        _ input: PersonalizedRequestInput
    ) throws -> Data {
        try encodeRequest(input, authorization: nil)
    }

    static func encodeRequest(
        _ input: PersonalizedRequestInput,
        authorization: SessionAuthorization
    ) throws -> Data {
        try encodeRequest(input, authorization: authorization as SessionAuthorization?)
    }

    private static func encodeRequest(
        _ input: PersonalizedRequestInput,
        authorization: SessionAuthorization?
    ) throws -> Data {
        var data = Tieba_PersonalizedRequestData()
        var common = Tieba_CommonRequest()
        common.clientType = 2
        common.clientVersion = androidClientVersion
        common.from = "1020031h"
        common.userAgent = androidUserAgent
        common.personalizedRecSwitch = 1
        if let authorization {
            let sessionToken = authorization.stoken
            common.bduss = authorization.bduss
            common.stoken = sessionToken
        }
        data.common = common
        data.loadType = input.loadKind.rawValue
        data.pn = input.page
        data.needTags = 0
        data.pageThreadCount = 11
        data.preAdThreadCount = 0
        data.sugCount = 0
        data.tagCode = 0
        data.qType = 1
        data.needForumlist = 0
        data.newNetType = 1
        data.newInstall = 0
        data.requestTimes = 0
        data.invokeSource = ""

        var request = Tieba_PersonalizedRequest()
        request.data = data
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try request.serializedData(options: options)
    }

    static func makeRequestBody(
        _ input: PersonalizedRequestInput
    ) throws -> EndpointRequestBody {
        .multipartBinary(
            boundary: boundary,
            fields: [],
            part: MultipartBinaryPart(
                name: "data",
                filename: "file",
                mimeType: nil,
                data: try encodeRequest(input)
            )
        )
    }

    static func makeAuthenticatedRequestBody(
        _ input: PersonalizedRequestInput,
        authorization: SessionAuthorization
    ) throws -> EndpointRequestBody {
        .multipartBinary(
            boundary: boundary,
            fields: [
                EndpointField(
                    name: "stoken",
                    value: authorization.stoken
                )
            ],
            part: MultipartBinaryPart(
                name: "data",
                filename: "file",
                mimeType: nil,
                data: try encodeRequest(
                    input,
                    authorization: authorization
                )
            )
        )
    }

    static func decode(_ bytes: Data) throws -> Tieba_PersonalizedResponse {
        guard !bytes.isEmpty else {
            throw PersonalizedProtocolError.emptyBody
        }
        let response = try Tieba_PersonalizedResponse(serializedBytes: bytes)
        if response.hasError, response.error.errorCode != 0 {
            throw EndpointWireFailure.server(
                code: Int(response.error.errorCode)
            )
        }
        return response
    }

    static func map(
        _ response: Tieba_PersonalizedResponse,
        requestedPage: UInt32
    ) throws -> RecommendationPage {
        guard response.hasData else {
            throw PersonalizedProtocolError.missingData
        }
        let items = response.data.threadList.map { thread in
            let stableThreadID = thread.threadID > 0
                ? thread.threadID
                : thread.id
            let thumbnailResource = thread.media.enumerated().lazy
                .compactMap { index, media in
                    ThreadListImageResourceMapper.map(
                        bigPicture: media.bigPic,
                        dynamicPicture: media.dynamicPic,
                        sourcePicture: media.srcPic,
                        originalPicture: media.originPic,
                        ownerResourceID:
                            "recommendation.t\(stableThreadID).media.\(index + 1)"
                    )
                }.first
            return RecommendationItem(
                rawFeedID: thread.id,
                rawThreadID: thread.threadID,
                title: thread.title,
                rawThreadType: thread.threadTypes,
                rawAuthorID: thread.authorID,
                author: mapAuthor(thread),
                rawForumID: thread.forumID,
                forumName: thread.forumName,
                replyCount: thread.replyNum,
                viewCount: thread.viewNum,
                isNoTitleRaw: thread.isNoTitle,
                isDeletedRaw: thread.isDeleted,
                hasVideo: thread.hasVideoInfo,
                hasLive: thread.hasAlaInfo,
                thumbnailResource: thumbnailResource
            )
        }
        let (nextPage, overflow) = requestedPage.addingReportingOverflow(1)
        return RecommendationPage(
            items: items,
            requestedPage: requestedPage,
            nextPageCandidate: overflow ? nil : nextPage,
            terminal: .unknown
        )
    }

    static func pipeline(
        requestedPage: UInt32
    ) -> EndpointPipeline<Tieba_PersonalizedResponse, RecommendationPage> {
        EndpointPipeline(
            decode: decode,
            map: { response in
                try map(response, requestedPage: requestedPage)
            }
        )
    }

    private static func mapAuthor(
        _ thread: Tieba_ThreadInfo
    ) -> RecommendationAuthor? {
        guard thread.hasAuthor else {
            return nil
        }
        return RecommendationAuthor(
            rawUserID: thread.author.id,
            name: thread.author.name,
            nameShow: thread.author.nameShow,
            portrait: thread.author.portrait
        )
    }
}
