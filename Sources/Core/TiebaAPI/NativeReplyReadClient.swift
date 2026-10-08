import Foundation

/// One receipt-directed read using explicitly prepared native page/Common
/// inputs. No account preparation, write, retry, pagination or cache mutation.
/// The Live page provider must supply those inputs before wiring this client.
@MainActor
final class NativeReplyReadClient {
    private let auth: any AuthContextProviding
    private let context: AuthContext
    private let http: any HTTPClient
    private var loading = false

    init(auth: any AuthContextProviding, context: AuthContext, http: any HTTPClient) {
        self.auth = auth
        self.context = context
        self.http = http
    }

    func load(business: [String: String], common: [String: String],
              httpContext: NativeWriteHTTPContext, boundary: String) async throws -> ThreadReaderSnapshot {
        guard !loading else { throw NativeReplyReadError.alreadyLoading }
        try Task.checkCancellation()
        let authorization = try auth.authorization(for: context)
        guard common["_client_type"] == "1", common["BDUSS"] == authorization.bduss,
              common["stoken"] == authorization.stoken,
              let threadID = business["kz"].flatMap(Int64.init),
              let postID = business["last_pid"].flatMap(Int64.init) else {
            throw NativeReplyReadError.invalidContext
        }
        let request = try NativeReplyReadProtocol.request(
            business: business, common: common, context: httpContext, boundary: boundary)
        loading = true
        defer { loading = false }
        let response = try await http.execute(request)
        try Task.checkCancellation()
        _ = try auth.authorization(for: context)
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPClientError.server(statusCode: response.statusCode)
        }
        return try NativeReplyReadProtocol.decode(response.body, threadID: threadID, targetPostID: postID)
    }
}
