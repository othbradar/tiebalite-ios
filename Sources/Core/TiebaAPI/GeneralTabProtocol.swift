import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum GeneralTabProtocol {
    // R05 anonymous runtime: generalTabList uses application/protobuf.
    static let allowedMIMETypes = FRSPageProtocol.allowedResponseMIMETypes + ["application/protobuf"]

    static func descriptor(host: String) throws -> EndpointDescriptor {
        guard let id = EndpointID("forum.generalTabList") else {
            throw FRSPageProtocolError.invalidStaticConfiguration
        }
        var headers = PersonalizedProtocol.anonymousV12Headers
        headers.removeValue(forKey: "client_type")
        headers["User-Agent"] = PersonalizedProtocol.androidUserAgent
            .replacingOccurrences(of: PersonalizedProtocol.androidClientVersion, with: "12.35.1.0")
        return try EndpointDescriptor(
            id: id, method: .post, host: host, path: "/c/f/frs/generalTabList",
            queryItems: [.init(name: "cmd", value: "309622"), .init(name: "format", value: "protobuf")],
            fixedHeaders: headers, bodyCodec: .multipartBinary, responseFamily: .protobuf,
            allowedResponseMIMETypes: allowedMIMETypes,
            authentication: .anonymous, timeout: 30, responseBodyLimit: 8 * 1_024 * 1_024,
            redirectPolicy: .reject, retryPolicy: .never
        )
    }

    static func encode(_ request: ForumHomePageRequest) throws -> Data {
        guard case let .category(category, sort) = request.query,
              category.id > 0, !category.title.isEmpty,
              let forumID = request.knownForum?.forumID ?? request.route.forumID?.rawValue,
              forumID > 0, (1...Int(Int32.max)).contains(request.pageNumber), request.lastThreadID >= 0 else {
            throw FRSPageProtocolError.invalidQuery
        }
        var data = Tieba_GeneralTabList_GeneralTabListRequestData()
        data.common.clientType = 2
        data.common.clientVersion = PersonalizedProtocol.androidClientVersion
        data.common.from = "1020031h"
        data.common.userAgent = PersonalizedProtocol.androidUserAgent
        data.tabID = category.id
        data.tabType = 15
        data.tabName = category.title
        data.isGeneralTab = 1
        data.isDefaultNavtab = category.isDefault
        data.forumID = forumID
        data.pn = Int32(request.pageNumber)
        data.rn = 30
        data.sortType = sort
        data.lastThreadID = request.pageNumber == 1 ? 0 : request.lastThreadID
        data.isNewfrs = 1
        var wire = Tieba_GeneralTabList_GeneralTabListRequest()
        wire.data = data
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try wire.serializedData(options: options)
    }

    static func body(_ request: ForumHomePageRequest) throws -> EndpointRequestBody {
        .multipartBinary(boundary: FRSPageProtocol.boundary, fields: [], part: .init(
            name: "data", filename: "file", mimeType: nil, data: try encode(request)
        ))
    }

    static func decode(_ bytes: Data) throws -> Tieba_GeneralTabList_GeneralTabListResponse {
        guard !bytes.isEmpty else { throw FRSPageProtocolError.emptyBody }
        let response = try Tieba_GeneralTabList_GeneralTabListResponse(serializedBytes: bytes)
        if response.hasError, response.error.errorCode != 0 {
            throw EndpointWireFailure.server(code: Int(response.error.errorCode))
        }
        guard response.hasData else { throw FRSPageProtocolError.missingData }
        return response
    }

    static func map(
        _ response: Tieba_GeneralTabList_GeneralTabListResponse, request: ForumHomePageRequest
    ) throws -> ForumHomeSnapshot {
        guard response.hasData else { throw FRSPageProtocolError.missingData }
        guard let forum = request.knownForum else { throw FRSPageProtocolError.missingForum }
        let data = response.data
        let threads = try FRSPageProtocol.mapThreads(data.generalList, userList: data.userList, forumName: forum.name)
        return ForumHomeSnapshot(
            forum: forum, threads: threads, currentPage: request.pageNumber,
            hasMore: data.hasMore_p == 1 && !threads.isEmpty,
            lastThreadID: data.generalList.last?.id ?? request.lastThreadID
        )
    }

    static func pipeline(request: ForumHomePageRequest) -> EndpointPipeline<
        Tieba_GeneralTabList_GeneralTabListResponse, ForumHomeSnapshot
    > {
        EndpointPipeline(decode: decode, map: { try map($0, request: request) })
    }
}
