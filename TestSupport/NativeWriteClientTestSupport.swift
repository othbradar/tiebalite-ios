import Foundation

#if TEST_SUPPORT
@testable import TiebaLite

struct NativeClientFixture: Decodable {
    let staticContext: NativeWriteStaticCommonContext
    let staticMode: NativeWriteStaticCommonParameters.Mode
    let metadata: Metadata
    let metrics: NativeWriteRequestMetrics
    let cases: [NativeClientSample]
    let emptyResponse: EmptyResponse

    struct EmptyResponse: Decodable {
        let state: Int
        let decodeCount: Int
        let hasError: Bool
    }

    struct Metadata: Decodable {
        let packageVersion: String?
        let experimentHits: String?
        let experimentMisses: String?
    }

    static func load() throws -> Self {
        try JSONDecoder().decode(Self.self, from: data("native-ios-client"))
    }

    static func replyContent() throws -> [NativeReplyContentSample] {
        try JSONDecoder().decode(ReplyContents.self, from: data("native-ios-reply-content")).cases
    }

    static func response(_ name: String = "post-success") throws -> Data {
        let fixtures = try JSONDecoder().decode(Responses.self, from: data("native-ios-response-decoding"))
        guard let sample = fixtures.cases.first(where: { $0.name == name }),
              let bytes = Data(base64Encoded: sample.wireBase64) else { throw HTTPClientError.malformedResponse }
        return bytes
    }

    private static func data(_ name: String) throws -> Data {
        guard let root = Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil) else {
            throw HTTPClientError.unavailable
        }
        return try Data(contentsOf: root.appendingPathComponent("API/Write/\(name).json"))
    }

    private struct Responses: Decodable { let cases: [Response] }
    private struct Response: Decodable { let name: String; let wireBase64: String }
    private struct ReplyContents: Decodable { let cases: [NativeReplyContentSample] }
}

struct NativeReplyContentSample: Decodable {
    let name: String
    let input: NativeReplyComposeContent
    let foundationPredicateMatch: Bool
    let expected: String
}

struct NativeClientSample: Decodable {
    let name: String
    let kind: String
    let content: String
    let title: String
    let container: String?
    let pageEntryType: Int?
    let replyCount: String?
    let entranceType: Int?
    let input: NativeWriteDynamicCommonContext
    let wireBase64: String

    func request() throws -> TextWriteRequest {
        guard let type = TextComposeTarget.Kind(rawValue: kind) else { throw TextWriteFailure.invalidTarget }
        let child = type == .floorReply || type == .subpostReply
        return .init(target: .init(
            kind: type, forumID: 9, forumName: "FixtureForum", threadID: type == .thread ? 0 : 101,
            postID: child ? 301 : 0, subpostID: type == .subpostReply ? 302 : 0,
            recipient: child ? .init(rawUserID: 42, displayName: "Fixture recipient", portrait: "fixture-portrait") : nil),
            draft: .init(title: title, content: content))
    }

    func origin() throws -> NativeWriteOrigin {
        if kind == "thread", let entranceType { return .thread(entranceType: entranceType) }
        guard let pageEntryType else { throw TextWriteFailure.invalidTarget }
        return .reply(.init(container: container == "subposts" ? .subposts : .threadPage,
                            pageEntryType: pageEntryType, floorNumber: "0", replyCount: replyCount))
    }
}

@MainActor
final class NativeClientFixtureRuntime: NativeWriteRuntimeProviding {
    var requestMetrics: NativeWriteRequestMetrics
    private(set) var requestedAPIs: [NativeWriteAPI] = []
    var mismatchedAccount = false
    var clientLogID: Int64 = 0
    private let fixture: NativeClientFixture
    private let sample: NativeClientSample

    init(fixture: NativeClientFixture, sample: NativeClientSample) {
        self.fixture = fixture
        self.sample = sample
        requestMetrics = fixture.metrics
    }

    func context(for api: NativeWriteAPI, authorization: SessionAuthorization,
                 account: TextWriteAccount?) throws -> NativeWriteRuntimeContext {
        requestedAPIs.append(api)
        let data = try JSONEncoder().encode(sample.input)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HTTPClientError.malformedResponse
        }
        object["api"] = api.rawValue
        object["sessionValue"] = mismatchedAccount ? "fixture-old" : authorization.bduss
        object["secondaryValue"] = authorization.stoken
        object["tbs"] = account?.tbs
        let dynamic = try JSONDecoder().decode(NativeWriteDynamicCommonContext.self, from: JSONSerialization.data(withJSONObject: object))
        return NativeWriteRuntimeContext(
            common: .init(staticValues: fixture.staticContext, staticMode: fixture.staticMode, dynamicValues: dynamic,
                          metadata: .init(packageVersion: fixture.metadata.packageVersion,
                                          experimentHits: fixture.metadata.experimentHits,
                                          experimentMisses: fixture.metadata.experimentMisses)),
            http: .init(userAgent: "FixtureNativeAgent", acceptLanguage: nil, clientLogID: clientLogID, timeout: 19,
                        responseState: .init(headerValue: "__ymg_scsc=fixture-must-not-override;"),
                        cookies: .init(networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                       smallFlow: false, smallFlowValue: nil)),
            multipartBoundary: "Boundary+0123456789ABCDEF")
    }
}

/// Reuses the controlled HTTP harness while allowing the real URLSession client
/// and per-request native header collector to run. Never creates a URLSession.
struct NativeClientHarnessBridge: HTTPDataLoading {
    let client: HarnessMockHTTPClient

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        guard let url = request.url, let method = request.httpMethod.flatMap(HTTPMethod.init(rawValue:)) else {
            throw HTTPClientError.malformedResponse
        }
        let response = try await client.execute(HTTPRequest(
            method: method, url: url, headers: request.allHTTPHeaderFields ?? [:], body: request.httpBody,
            timeout: request.timeoutInterval, responseBodyLimit: maximumByteCount))
        guard let http = HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: "HTTP/1.1",
                                         headerFields: response.headers) else { throw HTTPClientError.malformedResponse }
        return (response.body, http)
    }
}
#endif
