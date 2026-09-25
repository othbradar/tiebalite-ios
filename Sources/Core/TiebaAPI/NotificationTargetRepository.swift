import Foundation
import GeneratedProtobuf
import SwiftProtobuf

protocol NotificationTargetRepository: Sendable {
    func parentPostID(for target: NotificationTarget) async throws -> Int64
}

struct LiveNotificationTargetRepository: NotificationTargetRepository {
    let client: any HTTPClient

    func parentPostID(for target: NotificationTarget) async throws -> Int64 {
        guard target.threadID > 0, target.postID > 0 else { throw EndpointExecutionError.mapping }
        guard target.isSubpost else { return target.postID }
        let executor = EndpointExecutor(client: client, requestBuilder: .init(authorizer: AnonymousRequestAuthorizer()))
        return try await executor.execute(
            endpoint: PBFloorProtocol.descriptor(host: "tiebac.baidu.com"), authentication: .anonymous,
            body: Self.subpostBody(target), pipeline: .init(decode: PBFloorProtocol.decode, map: { response in
                try Self.mapSubpost(response, target: target).route.postID
            }))
    }

    static func subpostBody(_ target: NotificationTarget) throws -> EndpointRequestBody {
        // Reuse the verified common request, changing only the Android loadFromSubPost selector.
        let bytes = try PBFloorProtocol.encodeRequest(route: .init(threadID: target.threadID, postID: target.postID), page: 1)
        var request = try Tieba_PbFloor_PbFloorRequest(serializedBytes: bytes)
        request.data.pid = 0
        request.data.spid = target.postID
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return .multipartBinary(boundary: PersonalizedProtocol.boundary, fields: [], part: .init(
            name: "data", filename: "file", mimeType: nil, data: try request.serializedData(options: options)))
    }

    static func mapSubpost(_ response: Tieba_PbFloor_PbFloorResponse, target: NotificationTarget) throws -> SubpostsPage {
        guard response.hasData, response.data.hasPost, let parentID = Int64(exactly: response.data.post.id), parentID > 0 else {
            throw EndpointExecutionError.mapping
        }
        let page = try PBFloorProtocol.map(response, route: .init(threadID: target.threadID, postID: parentID),
                                           page: Int(response.data.page.currentPage))
        guard page.items.contains(where: { $0.id == target.postID }) else { throw EndpointExecutionError.mapping }
        return page
    }

}

#if DEBUG
struct FixtureNotificationTargetRepository: NotificationTargetRepository {
    func parentPostID(for target: NotificationTarget) async throws -> Int64 {
        try Task.checkCancellation()
        return target.isSubpost ? 9_002 : target.postID
    }
}
#endif
