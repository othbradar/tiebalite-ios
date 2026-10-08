import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteHTTPRequestTests {
    private let noCookies = NativeWriteRequestCookies(networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                                      smallFlow: false, smallFlowValue: nil)
    private let boundary = "Boundary+0123456789ABCDEF"

    @Test
    func protobufRoutesMatchTheNativeShortConnectionBlock() throws {
        let samples = try fixtures(URLCase.self, name: "native-ios-request-url")
            .filter { $0.input.address.contains("/c/") }
        #expect(samples.count == 2)
        for sample in samples {
            let kind: TextComposeTarget.Kind = sample.input.address.contains("thread") ? .thread : .threadReply
            let request = try request(kind: kind)
            let nativePath = sample.output.address.hasPrefix("/") ? sample.output.address : "/" + sample.output.address
            #expect(request.url.absoluteString == "https://tiebac.baidu.com" + nativePath)
        }
    }

    @Test
    func nativeMultipartAndHeadersMatchReferenceMethodsWithoutAndroidEnvelope() throws {
        let encodings = try fixtures(EncodingCase.self, name: "native-ios-request-encoding")
        for sample in try fixtures(HTTPCase.self, name: "native-ios-http-envelope") {
            let encoding = try #require(encodings.first { $0.name == sample.encodingCase })
            let kind = try #require(TextComposeTarget.Kind(rawValue: sample.kind))
            let context = NativeWriteHTTPContext(
                userAgent: sample.userAgent, acceptLanguage: "zh-Hans-CN;q=1, en-CN;q=0.9",
                clientLogID: sample.clientLogID, timeout: 19,
                responseState: sample.state.flatMap { NativeWriteResponseState(headerValue: "__ymg_scsc=\($0);") },
                cookies: noCookies)
            let request = try NativeWriteHTTPRequest.makeRequest(
                kind: kind, business: encoding.business, common: encoding.common, context: context, boundary: boundary)
            var body = Data("--\(boundary)\r\n".utf8)
            for (name, value) in sample.partHeaders.sorted(by: { $0.key < $1.key }) {
                body.append(Data("\(name): \(value)\r\n".utf8))
            }
            body.append(Data("\r\n".utf8))
            body.append(try #require(Data(base64Encoded: sample.partBase64)))
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            var headers = sample.nativeHeaders
            headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
            headers["Content-Length"] = String(body.count)
            headers["Accept-Language"] = context.acceptLanguage
            headers["Retry-Count"] = "0"
            #expect(request.headers == headers)
            #expect(request.body == body)
            let endpoint = kind == .thread ? "thread" : "post"
            let command = kind == .thread ? 309730 : 309731
            #expect(request.method == .post)
            #expect(request.url.absoluteString ==
                    "https://tiebac.baidu.com/c/c/\(endpoint)/add?cmd=\(command)&format=protobuf")
            #expect(request.timeout == 19 && request.redirectPolicy == .reject)
        }
    }

    @Test(arguments: [TextComposeTarget.Kind.threadReply, .floorReply, .subpostReply])
    func replyTargetsShareTheNativeHTTPPath(_ kind: TextComposeTarget.Kind) throws {
        let request = try request(kind: kind)
        #expect(request.url.path == "/c/c/post/add")
        #expect(request.url.query == "cmd=309731&format=protobuf")
        #expect(request.headers["client_logid"] == nil && request.headers["Accept-Language"] == nil)
        #expect(request.headers["Accept"] == nil && request.headers["client_user_token"] == nil)
    }

    @Test(arguments: ["", "fixture\r\nInjected: true"])
    func missingOrInvalidRuntimeUserAgentIsRejected(_ userAgent: String) {
        #expect(throws: HTTPRequestValidationError.invalidHeader) { try request(userAgent: userAgent) }
    }

    @Test
    func nativeBoundaryDoesNotWeakenInjectionOrCollisionProtection() {
        #expect(throws: EndpointRequestBuilderError.invalidBoundary) { try request(boundary: "Boundary+bad\r\n") }
        #expect(throws: EndpointRequestBuilderError.invalidBoundaryCollision) {
            try request(content: "Body contains \(boundary)")
        }
    }

    @Test
    func runtimeContextDescriptionsDoNotExposeInputValues() {
        let context = NativeWriteHTTPContext(userAgent: "fixture-device", acceptLanguage: "fixture-language",
                                             clientLogID: 42, timeout: 10,
                                             responseState: NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-state;"),
                                             cookies: noCookies)
        #expect(String(describing: context) == "NativeWriteHTTPContext(redacted)")
        #expect(String(reflecting: context) == "NativeWriteHTTPContext(redacted)")
    }

    private func request(kind: TextComposeTarget.Kind = .threadReply, userAgent: String = "FixtureNativeAgent",
                         boundary: String? = nil, content: String = "Synthetic reply") throws -> HTTPRequest {
        try NativeWriteHTTPRequest.makeRequest(
            kind: kind, business: ["content": content], common: [:],
            context: NativeWriteHTTPContext(userAgent: userAgent, acceptLanguage: nil, clientLogID: 0,
                                            timeout: 19, responseState: nil, cookies: noCookies),
            boundary: boundary ?? self.boundary)
    }

    private func fixtures<Value: Decodable>(_ type: Value.Type, name: String) throws -> [Value] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/\(name).json"))
        return try JSONDecoder().decode(FixtureCases<Value>.self, from: bytes).cases
    }

    private struct FixtureCases<Value: Decodable>: Decodable { let cases: [Value] }
    private struct URLAddress: Decodable { let address: String }
    private struct URLCase: Decodable {
        let input: URLAddress
        let output: URLAddress
    }
    private struct EncodingCase: Decodable {
        let name: String
        let business: [String: String]
        let common: [String: String]
    }
    private struct HTTPCase: Decodable {
        let kind: String
        let encodingCase: String
        let clientLogID: Int64
        let state: String?
        let userAgent: String
        let nativeHeaders: [String: String]
        let partHeaders: [String: String]
        let partBase64: String
    }
}
