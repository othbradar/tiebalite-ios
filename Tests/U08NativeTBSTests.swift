import Foundation
import Testing
@testable import TiebaLite

struct U08NativeTBSTests {
    @Test
    func ordinarySignedFormsMatchBothNativeBranches() throws {
        for sample in try fixtures().signingCases {
            let context = NativeWriteCommonContext(
                staticValues: sample.staticContext, staticMode: sample.staticMode, dynamicValues: sample.input,
                metadata: .init(packageVersion: "unused", experimentHits: "unused", experimentMisses: "unused"))
            var builder = NativeWriteCommonParameters()
            var metrics = sample.metrics
            let credential = try #require(SessionCredential(bduss: "fixture-tbs-session", stoken: "fixture-token"))
            let auth = SessionAuthorization(credential: credential)
            let result = try builder.prepareTBS(context, authorization: auth, metrics: &metrics)
            #expect(result == sample.expected.signedForm, "\(sample.name)")
            #expect(metrics == sample.expected.metricsAfter)
            #expect(result["package_version"] == nil && result["abtest_config_intervention"] == nil)
            #expect(result["BDUSS"] == "fixture-tbs-session")
        }
    }

    @Test
    func jsonAcceptanceMatchesNativeParserAndTBSCompletion() throws {
        for sample in try fixtures().responseCases {
            let response = HTTPResponse(statusCode: 200, body: Data(sample.json.utf8))
            #expect(sample.expected.lockValues == [0])
            if let saved = sample.expected.saved.first {
                #expect(try NativeTBSResponseDecoder.decode(response) == saved.value, "\(sample.name)")
                #expect(saved.userID == "42" && sample.expected.notifications == 1)
                #expect(sample.expected.state == 3 && !sample.expected.hasError)
            } else {
                #expect(throws: NativeTBSError.self, "\(sample.name)") { try NativeTBSResponseDecoder.decode(response) }
                #expect(sample.expected.notifications == 0)
            }
        }
    }

    @Test
    func jsonErrorPrecedenceIsIndependentOfTBSAndHTTPStatus() {
        let both = Data(#"{"error_code":6,"error":{"errno":8},"tbs":"fixture-value"}"#.utf8)
        #expect(throws: NativeTBSError.serverRejected(6)) {
            try NativeTBSResponseDecoder.decode(.init(statusCode: 200, body: both))
        }
        #expect(throws: HTTPClientError.server(statusCode: 503)) {
            try NativeTBSResponseDecoder.decode(.init(statusCode: 503, body: Data(#"{"error_code":0,"tbs":"fixture"}"#.utf8)))
        }
    }

    @Test
    func nonUTF8ResponseCannotBypassNativeUTF8Decoding() throws {
        let bytes = try #require(#"{"error_code":0,"tbs":"fixture"}"#.data(using: .utf16))
        #expect(throws: NativeTBSError.malformedResponse) {
            try NativeTBSResponseDecoder.decode(.init(statusCode: 200, body: bytes))
        }
    }

    @Test
    func formEncodingPreservesNativeQueryCharactersAndEncodesSpaceAsPercent20() throws {
        let input = ["field": "space /? :#[]@!$&'()*+,;=%中文", "empty": ""]
        let output = try NativeTBSRequest.encode(input)
        #expect(String(data: output, encoding: .utf8) ==
            "empty=&field=space%20/?%20%3A%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D%25%E4%B8%AD%E6%96%87")
        let long = String(repeating: "a", count: 49) + "😊e\u{301}"
        #expect(try NativeTBSRequest.encode(["key": long]) ==
            Data(("key=" + String(repeating: "a", count: 49) + "%F0%9F%98%8Ae%CC%81").utf8))
    }

    @Test
    func formHTTPUsesNativeHeadersAndFinalNetworkTimeout() throws {
        for network in [nil, "", "0", "1", "2"] as [String?] {
            let request = try NativeTBSRequest.make(
                parameters: ["BDUSS": "fixture-session", "sign": "fixture-sign"].merging(
                    network.map { ["net_type": $0] } ?? [:]) { _, value in value },
                context: .init(userAgent: "FixtureIOSAgent", acceptLanguage: "zh-Hans", clientLogID: 42,
                               cookies: .init(networkStatus: 1, wifiKeepAlive: true, cellularKeepAlive: false,
                                              smallFlow: false, smallFlowValue: nil)))
            #expect(request.url.absoluteString == "https://tiebac.baidu.com/c/s/tbs")
            #expect(request.method == .post && request.timeout == (network == "1" ? 10 : 25))
            #expect(request.redirectPolicy == .reject && request.responseBodyLimit == 1_024 * 1_024)
            #expect(request.headers == ["User-Agent": "FixtureIOSAgent", "Accept-Language": "zh-Hans",
                                        "Content-Type": "application/x-www-form-urlencoded", "client_logid": "42",
                                        "Cookie": "ka=open"])
        }
    }

    private func fixtures() throws -> Fixtures {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-tbs.json")))
    }

    private struct Fixtures: Decodable { let signingCases: [SigningCase]; let responseCases: [ResponseCase] }
    private struct SigningCase: Decodable {
        let name: String
        let input: NativeWriteDynamicCommonContext
        let staticContext: NativeWriteStaticCommonContext
        let staticMode: NativeWriteStaticCommonParameters.Mode
        let metrics: NativeWriteRequestMetrics
        let expected: Signed
    }
    private struct Signed: Decodable {
        let signedForm: [String: String]
        let metricsAfter: NativeWriteRequestMetrics
    }
    private struct ResponseCase: Decodable { let name: String; let json: String; let expected: Outcome }
    private struct Outcome: Decodable {
        let state: Int
        let hasError: Bool
        let saved: [Saved]
        let lockValues: [Int]
        let notifications: Int
    }
    private struct Saved: Decodable { let userID: String; let value: String }
}
