import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum ForumGuideProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case invalidStaticConfiguration
    case invalidItems
    case missingData
}

enum ForumGuideProtocol {
    static let boundary = "--------7da3d81520810*"
    static let fixtureResponseMIMEType = "application/x-protobuf"
    static let candidateLiveResponseMIMEType = "application/octet-stream"
    static let androidClientVersion = "11.10.8.6"

    static func makeDescriptor(host: String) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("followedForums.forumGuide") else {
            throw ForumGuideProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier,
            method: .post,
            host: host,
            path: "/c/f/forum/forumGuide",
            queryItems: [
                EndpointField(name: "cmd", value: "309683"),
                EndpointField(name: "format", value: "protobuf")
            ],
            fixedHeaders: [
                "Charset": "UTF-8",
                "User-Agent": "bdtb for Android \(androidClientVersion)",
                "client_type": "2",
                "x_bd_data_type": "protobuf"
            ],
            bodyCodec: .multipartBinary,
            responseFamily: .protobuf,
            allowedResponseMIMETypes: [
                fixtureResponseMIMEType,
                candidateLiveResponseMIMEType
            ],
            authentication: .active,
            timeout: 30,
            responseBodyLimit: 4 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func encodeRequest() throws -> Data {
        var data = Tieba_ForumGuide_ForumGuideRequestData()
        data.sortType = 2
        data.callFrom = 0

        var request = Tieba_ForumGuide_ForumGuideRequest()
        request.data = data
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try request.serializedData(options: options)
    }

    static func makeAuthenticatedRequestBody(
        authorization: SessionAuthorization
    ) throws -> EndpointRequestBody {
        let fields = [
            EndpointField(name: "BDUSS", value: authorization.bduss),
            EndpointField(name: "stoken", value: authorization.stoken)
        ]

        return .multipartBinary(
            boundary: boundary,
            fields: fields,
            part: MultipartBinaryPart(
                name: "data",
                filename: "file",
                mimeType: nil,
                data: try encodeRequest()
            )
        )
    }

    static func decode(
        _ bytes: Data
    ) throws -> Tieba_ForumGuide_ForumGuideResponse {
        guard !bytes.isEmpty else {
            throw ForumGuideProtocolError.emptyBody
        }
        let response = try Tieba_ForumGuide_ForumGuideResponse(
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
        _ response: Tieba_ForumGuide_ForumGuideResponse
    ) throws -> [FollowedForum] {
        guard response.hasData else {
            throw ForumGuideProtocolError.missingData
        }
        let wireItems = response.data.likeForum
        var seenIDs: Set<Int64> = []
        let items = wireItems.compactMap { item -> FollowedForum? in
            guard item.forumID > 0,
                  item.forumID <= UInt64(Int64.max) else {
                return nil
            }
            let forumID = Int64(item.forumID)
            let name = item.forumName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !name.isEmpty, seenIDs.insert(forumID).inserted else {
                return nil
            }
            return FollowedForum(
                forumID: forumID,
                name: name,
                avatarResourceID: nonempty(item.avatar),
                hotCount: Int(item.hotNum),
                memberCount: Int(item.memberCount),
                threadCount: Int(item.threadNum),
                levelID: item.levelID > 0 ? Int(item.levelID) : nil,
                levelName: nonempty(item.levelName),
                isSignedToday: item.isSign == 1
            )
        }
        guard wireItems.isEmpty || !items.isEmpty else {
            throw ForumGuideProtocolError.invalidItems
        }
        return items
    }

    static var pipeline: EndpointPipeline<
        Tieba_ForumGuide_ForumGuideResponse,
        [FollowedForum]
    > {
        EndpointPipeline(decode: decode, map: map)
    }

    private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
