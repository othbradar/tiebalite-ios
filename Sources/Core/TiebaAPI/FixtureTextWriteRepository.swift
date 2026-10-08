#if DEBUG
struct FixtureTextWriteRepository: TextWriteRepository {
    var failure: TextWriteFailure?
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        try Task.checkCancellation()
        if let failure { throw failure }
        return .init(threadID: request.target.kind == .thread ? 900_001 : request.target.threadID, postID: 900_002)
    }
}
#endif

#if UITESTING
import Foundation
import GeneratedProtobuf
import SwiftProtobuf

/// A local server model: only a successful mock write makes the next read include the new reply.
actor FixtureReplyRefreshRepository: TextWriteRepository, ThreadReaderRepository {
    private var published = false
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        try Task.checkCancellation()
        published = true
        var wire = Tieba_AddPost_AddPostResponse()
        wire.data.tid = String(request.target.threadID)
        wire.data.pid = "900002"
        // Synthetic beta3-supported success shape; not a captured Live response.
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/octet-stream"],
                                    body: try wire.serializedData())
        let target = request.target
        let pipeline = EndpointPipeline(decode: { try TextWriteProtocol.decodePost($0, target: target) }, map: { $0 })
        let outcome = try pipeline.map(response, for: TextWriteProtocol.descriptor(for: target.kind, userID: "42"))
        switch outcome {
        case .success(let receipt): return receipt
        case .failure(let failure): throw failure
        }
    }

    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        let base = try await FixtureThreadReaderRepository().loadPage(request)
        var posts = Array(base.posts.prefix(1))
        if published {
            let source = ThreadContentSource(threadID: base.threadID, postID: 900_002, scope: .post)
            let node = ThreadContentNode(id: .init(source: source, ordinal: 0), rawType: 0,
                                         payload: .text(.init(value: "U08 mock published reply")))
            posts.append(.init(floorNumber: 2, author: base.author, metadata: "Fixture",
                               document: .init(source: source, availability: .available, nodes: [node], poll: nil)))
        }
        return .init(threadID: base.threadID, title: base.title, forumName: base.forumName, forumID: base.forumID,
                     author: base.author, replyCount: published ? 1 : 0, posts: posts,
                     currentPage: 1, totalPage: 1, hasMore: false)
    }
}
#endif
