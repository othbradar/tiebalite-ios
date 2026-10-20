/// The official iOS forum-search page uses the same JSON endpoint with a distinct query.
/// Evidence: P03, hybrid-usergrow-search hmu:13 (2026-10-20). No global fallback.
enum InForumSearchProtocol {
    static func makeDescriptor(host: String, request: SearchThreadPageRequest) throws -> EndpointDescriptor {
        guard case let .forum(forum) = request.query.scope,
              let identifier = EndpointID("search.web.in-forum") else {
            throw SearchWebProtocolError.unsupportedScope
        }
        return try EndpointDescriptor(
            id: identifier, method: .get, host: host, path: "/mo/q/search/thread",
            queryItems: [
                EndpointField(name: "word", value: request.keyword.rawValue),
                EndpointField(name: "fname", value: forum.forumName.rawValue),
                EndpointField(name: "pn", value: String(request.page)),
                EndpointField(name: "rn", value: "20"),
                EndpointField(name: "st", value: String(request.query.sort.rawValue)),
                EndpointField(name: "tt", value: request.query.forumMode.threadTypeValue),
                EndpointField(name: "ct", value: "1"),
                EndpointField(name: "cv", value: "22.11.1")
            ],
            fixedHeaders: SearchWebProtocol.commonHeaders, bodyCodec: .none,
            responseFamily: .json, allowedResponseMIMETypes: [SearchWebProtocol.responseMIMEType],
            authentication: .anonymous, timeout: 30, responseBodyLimit: 4 * 1_024 * 1_024,
            redirectPolicy: .reject, retryPolicy: .never
        )
    }

    static func validate(_ candidates: [SearchThreadCandidate], scope: SearchScope) throws {
        guard case let .forum(forum) = scope else { return }
        // This is an integrity check, never a local filter of global results.
        guard candidates.allSatisfy({ item in
            if let expectedID = forum.forumID?.rawValue, let actualID = item.forumID, actualID > 0 {
                return expectedID == actualID
            }
            return item.forumName == forum.forumName.rawValue
        }) else { throw SearchWebProtocolError.scopeMismatch }
    }
}
