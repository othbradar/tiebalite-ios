import CryptoKit
import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct U08WriteRequestCompatibilityTests {
    @MainActor
    @Test(arguments: [TextComposeTarget.Kind.thread, .threadReply, .floorReply, .subpostReply])
    func restoredDraftReachesURLSessionWithoutChangingBeta3Request(_ kind: TextComposeTarget.Kind) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let context = auth.context()
        let target = R09WriteFixture.target(kind)
        let draft = TextDraft(title: "Fixture title", content: "Synthetic reply + & #滑稽")
        let saved = TextComposerDrafts(storage: ComposerDraftStorage(directory: directory), namespace: { "fixture" })
        saved.save(draft, target: target, context: context)
        await saved.flush()
        let restored = TextComposerDrafts(storage: ComposerDraftStorage(directory: directory), namespace: { "fixture" })
        let loader = Beta3WriteBoundaryLoader(kind: kind)
        let store = TextComposerStore(target: target, repository: LiveTextWriteRepository(
            client: URLSessionHTTPClient(loader: loader), authContextProvider: auth),
            context: context, currentContext: { auth.context() })
        store.draft = await restored.restore(target: target, context: context)
        #expect(store.draft == draft)
        await store.send()
        #expect(store.failure == nil && store.receipt != nil)
        await store.send()
        let requests = await loader.requests
        let writePath = kind == .thread ? "/c/c/thread/add" : "/c/c/post/add"
        #expect(requests.compactMap { $0.url?.path } == ["/c/s/login", "/c/u/user/profile", writePath])
        let request = try #require(requests.last)
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/beta3-request-snapshots.json"))
        let expected = try #require(JSONDecoder().decode([String: RequestSnapshot].self, from: data)[kind.rawValue])
        #expect(request.url?.absoluteString == expected.url && request.httpMethod == expected.method)
        let headers = Dictionary(uniqueKeysWithValues: (request.allHTTPHeaderFields ?? [:]).map { ($0.key.lowercased(), $0.value) })
        let expectedHeaders = Dictionary(uniqueKeysWithValues: expected.headers.map { ($0.key.lowercased(), $0.value) })
        #expect(headers == expectedHeaders)
        let bodyDigest = SHA256.hash(data: request.httpBody ?? Data()).map { String(format: "%02x", $0) }.joined()
        #expect(bodyDigest == expected.bodySHA256)
        #expect(request.timeoutInterval == expected.timeout)
        #expect(!request.httpShouldHandleCookies && request.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @MainActor
    @Test(arguments: [TextComposeTarget.Kind.thread, .threadReply, .floorReply, .subpostReply])
    func requestMatchesPublishedBeta3(_ kind: TextComposeTarget.Kind) async throws {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let context = auth.context()
        let authorization = try auth.authorization(for: context)
        let account = TextWriteAccount(userID: "42", tbs: "fixture-tbs", nameShow: R09WriteFixture.displayName)
        let input = TextWriteRequest(target: R09WriteFixture.target(kind),
                                     draft: .init(title: "Fixture title", content: "Synthetic reply + & #滑稽"))
        let builder = EndpointRequestBuilder(authorizer: ActiveSessionRequestAuthorizer(authContextProvider: auth))
        let request = try await builder.makeRequest(
            endpoint: TextWriteProtocol.descriptor(for: kind, userID: "42"), authentication: context,
            body: TextWriteProtocol.body(input, authorization: authorization, account: account))
        // Frozen from the published beta3 source with synthetic credentials; never sent to a network.
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/beta3-request-snapshots.json"))
        let snapshots = try JSONDecoder().decode([String: RequestSnapshot].self, from: data)
        let expected = try #require(snapshots[kind.rawValue])
        #expect(RequestSnapshot(request) == expected)
    }

    private struct RequestSnapshot: Codable, Equatable {
        let method: String
        let url: String
        let headers: [String: String]
        let bodySHA256: String
        let timeout: TimeInterval
        let responseBodyLimit: Int
        let rejectsRedirects: Bool

        init(_ request: HTTPRequest) {
            method = request.method.rawValue
            url = request.url.absoluteString
            headers = request.headers
            bodySHA256 = SHA256.hash(data: request.body ?? Data()).map { String(format: "%02x", $0) }.joined()
            timeout = request.timeout
            responseBodyLimit = request.responseBodyLimit
            rejectsRedirects = request.redirectPolicy == .reject
        }
    }
}

/// Captures the production URLRequest boundary. No URLSession or real network is started.
private actor Beta3WriteBoundaryLoader: HTTPDataLoading {
    let kind: TextComposeTarget.Kind
    private(set) var requests: [URLRequest] = []

    init(kind: TextComposeTarget.Kind) { self.kind = kind }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        requests.append(request)
        let url = try #require(request.url)
        let response: HTTPResponse
        switch url.path {
        case "/c/s/login": response = R09WriteFixture.accountResponse
        case "/c/u/user/profile": response = try R09WriteFixture.profileResponse()
        case "/c/c/thread/add" where kind == .thread:
            response = .init(statusCode: 200, headers: ["content-type": "application/json"],
                             body: Data(#"{"error_code":"0","tid":"501","pid":"502"}"#.utf8))
        case "/c/c/post/add" where kind != .thread:
            var wire = Tieba_AddPost_AddPostResponse()
            wire.data.tid = "101"
            wire.data.pid = "401"
            response = .init(statusCode: 200, headers: ["content-type": "application/octet-stream"],
                             body: try wire.serializedData())
        default: throw HTTPClientError.transport
        }
        #expect(response.body.count <= maximumByteCount)
        let urlResponse = try #require(HTTPURLResponse(
            url: url, statusCode: response.statusCode, httpVersion: "HTTP/1.1", headerFields: response.headers))
        return (response.body, urlResponse)
    }
}
