import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum PBFloorProtocolError: Error, Equatable, Sendable {
    case invalidRequest
    case emptyBody
    case missingData
    case identityMismatch
    case invalidPage
}

enum PBFloorProtocol {
    static func descriptor(host: String) throws -> EndpointDescriptor {
        guard let id = EndpointID("thread.pbFloor") else { throw PBFloorProtocolError.invalidRequest }
        return try EndpointDescriptor(
            id: id, method: .post, host: host, path: "/c/f/pb/floor",
            queryItems: [.init(name: "cmd", value: "302002"), .init(name: "format", value: "protobuf")],
            fixedHeaders: PersonalizedProtocol.anonymousV12Headers, bodyCodec: .multipartBinary,
            responseFamily: .protobuf, allowedResponseMIMETypes: ["application/x-protobuf", "application/octet-stream"],
            authentication: .anonymous, timeout: 30, responseBodyLimit: 8 * 1_024 * 1_024,
            redirectPolicy: .reject, retryPolicy: .never
        )
    }

    static func encodeRequest(route: SubpostsRoute, page: Int) throws -> Data {
        guard route.threadID > 0, route.postID > 0, page > 0, page <= Int(Int32.max) else {
            throw PBFloorProtocolError.invalidRequest
        }
        var request = Tieba_PbFloor_PbFloorRequest()
        request.data.kz = route.threadID
        request.data.pid = route.postID
        request.data.spid = 0
        request.data.pn = Int32(page)
        request.data.forumID = 0  // Anonymous runtime verified; response provides the real forum identity.
        request.data.isCommReverse = 0
        request.data.oriUgcType = 0
        request.data.common.clientType = 2
        request.data.common.clientVersion = PersonalizedProtocol.androidClientVersion
        request.data.common.from = "1020031h"
        request.data.common.userAgent = PersonalizedProtocol.androidUserAgent
        request.data.common.personalizedRecSwitch = 1
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try request.serializedData(options: options)
    }

    static func body(route: SubpostsRoute, page: Int) throws -> EndpointRequestBody {
        .multipartBinary(
            boundary: PersonalizedProtocol.boundary, fields: [],
            part: .init(
                name: "data", filename: "file", mimeType: nil, data: try encodeRequest(route: route, page: page)
            ))
    }

    static func decode(_ bytes: Data) throws -> Tieba_PbFloor_PbFloorResponse {
        guard !bytes.isEmpty else { throw PBFloorProtocolError.emptyBody }
        let response = try Tieba_PbFloor_PbFloorResponse(serializedBytes: bytes)
        if response.error.errorCode != 0 { throw EndpointWireFailure.server(code: Int(response.error.errorCode)) }
        return response
    }

    static func map(_ response: Tieba_PbFloor_PbFloorResponse, route: SubpostsRoute, page: Int) throws -> SubpostsPage {
        try PBFloorMapper.map(response, route: route, page: page)
    }
}

struct LiveSubpostsRepository: SubpostsRepository {
    let client: any HTTPClient
    var host: String = "tiebac.baidu.com"

    func loadPage(route: SubpostsRoute, page: Int) async throws -> SubpostsPage {
        let executor = EndpointExecutor(client: client, requestBuilder: .init(authorizer: AnonymousRequestAuthorizer()))
        let result = try await executor.execute(
            endpoint: PBFloorProtocol.descriptor(host: host), authentication: .anonymous,
            body: PBFloorProtocol.body(route: route, page: page),
            pipeline: EndpointPipeline(
                decode: PBFloorProtocol.decode,
                map: {
                    try PBFloorProtocol.map($0, route: route, page: page)
                })
        )
        try Task.checkCancellation()
        return result
    }
}
