import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteRequestCookiesTests {
    @Test
    func conditionalCookieSelectionMatchesTheNativeMethods() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-cookies.json"))
        for sample in try JSONDecoder().decode(Fixtures.self, from: bytes).cases {
            let input = sample.input
            let selection = NativeWriteRequestCookies(
                networkStatus: input.networkStatus, wifiKeepAlive: input.wifiKeepAlive,
                cellularKeepAlive: input.cellularKeepAlive, smallFlow: input.smallFlow,
                smallFlowValue: input.smallFlowValue)
            #expect(selection.entries.map(\.name) == sample.cookies.map(\.name), "\(sample.name)")
            #expect(selection.entries.map(\.value) == sample.cookies.map(\.value), "\(sample.name)")
        }
    }

    @Test
    func requestUsesOnlySelectedCookiesAndKeepsProtobufBodyUnchanged() throws {
        let cookies = NativeWriteRequestCookies(networkStatus: 1, wifiKeepAlive: true, cellularKeepAlive: false,
                                                smallFlow: true, smallFlowValue: "fx")
        let context = NativeWriteHTTPContext(userAgent: "FixtureNativeAgent", acceptLanguage: nil, clientLogID: 0,
                                             timeout: 20, responseState: nil, cookies: cookies)
        let request = try NativeWriteHTTPRequest.makeRequest(
            kind: .threadReply, business: ["content": "Synthetic reply"], common: [:],
            context: context, boundary: "Boundary+0123456789ABCDEF")
        let pairs = try #require(request.headers["Cookie"]).components(separatedBy: "; ")
        #expect(Set(pairs) == ["ka=open", "pub_env=fx"])
        #expect(request.headers["x_bd_data_type"] == "protobuf")
        let body = try #require(request.body)
        #expect(body.range(of: Data("ka=open".utf8)) == nil)
        #expect(body.range(of: Data("pub_env".utf8)) == nil)
    }

    @Test
    func emptySelectionDoesNotCreateCookieHeaderAndEmptyValueIsPreserved() throws {
        let disabled = NativeWriteRequestCookies(networkStatus: 0, wifiKeepAlive: true, cellularKeepAlive: true,
                                                 smallFlow: false, smallFlowValue: "fx")
        #expect(try disabled.headerFields().isEmpty)
        let empty = NativeWriteRequestCookies(networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                              smallFlow: true, smallFlowValue: "")
        #expect(try empty.headerFields()["Cookie"] == "pub_env=")
    }

    @Test
    func descriptionsRedactProviderValuesAndInvalidHeaderCannotBeSent() {
        let cookies = NativeWriteRequestCookies(networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                                smallFlow: true, smallFlowValue: "fx\r\nInjected: value")
        #expect(throws: HTTPRequestValidationError.invalidHeader) { try cookies.headerFields() }
        #expect(String(describing: cookies) == "NativeWriteRequestCookies(redacted)")
        #expect(cookies.entries.allSatisfy { String(reflecting: $0) == "NativeWriteCookieEntry(redacted)" })
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable { let name: String; let input: Input; let cookies: [RecordedPair] }
    private struct RecordedPair: Decodable { let name: String; let value: String }
    private struct Input: Decodable {
        let networkStatus: Int
        let wifiKeepAlive: Bool
        let cellularKeepAlive: Bool
        let smallFlow: Bool
        let smallFlowValue: String?
    }
}
