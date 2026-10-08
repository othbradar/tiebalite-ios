import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct U08NativeWriteSigningTests {
    @Test
    func signedCommonAndWireMatchNativeMergeAndMD5Execution() throws {
        for sample in try samples() {
            let actual = signed(sample)
            var expected = sample.expectedCommon
            expected["sig"] = nil // This native dictionary-only result is absent from Common's IDL.
            #expect(actual == expected, "\(sample.name)")
            let kind = try #require(TextComposeTarget.Kind(rawValue: sample.kind))
            let bytes = try NativeWriteRequestEncoder.encode(kind: kind, business: sample.business, common: actual)
            #expect(bytes == Data(base64Encoded: sample.wireBase64), "\(sample.name)")
        }
    }

    @Test
    func businessOverridesParticipateInSignatureWithoutReplacingCommonValues() throws {
        let sample = try #require(samples().first)
        let result = signed(sample)
        #expect(result["tbs"] == "fixture-common-tbs")
        #expect(result["content"] == nil && result["floor"] == nil)
        var changed = sample.business
        changed["floor"] = "8"
        #expect(NativeWriteSigning.common(sample.common, business: changed, metadata: sample.metadata.value)["sign"] != result["sign"])
        changed = sample.business
        changed["tbs"] = sample.common["tbs"]
        #expect(NativeWriteSigning.common(sample.common, business: changed, metadata: sample.metadata.value)["sign"] != result["sign"])
    }

    @Test
    func metadataIsAddedAfterSigningAndOpaqueCommonSignatureCannotChangeWire() throws {
        let fixtures = try samples()
        let first = try #require(fixtures.first { $0.name == "reply" })
        let changed = try #require(fixtures.first { $0.name == "after-sign-metadata" })
        let opaque = try #require(fixtures.first { $0.name == "unused-common-sig" })
        #expect(signed(first)["sign"] == signed(changed)["sign"])
        #expect(signed(first)["package_version"] != signed(changed)["package_version"])
        #expect(first.wireBase64 == opaque.wireBase64)
        let bytes = try #require(Data(base64Encoded: opaque.wireBase64))
        #expect(try !TiebaNativeWrite_PostRequest(serializedBytes: bytes).data.hasSig)
    }

    @Test
    func signedCommonTravelsThroughOneNativeHTTPEnvelope() throws {
        let sample = try #require(samples().first)
        let boundary = "Boundary+0123456789ABCDEF"
        let request = try NativeWriteHTTPRequest.makeRequest(
            kind: .threadReply, business: sample.business, common: signed(sample),
            context: NativeWriteHTTPContext(userAgent: "FixtureNativeAgent", acceptLanguage: nil,
                                            clientLogID: 42, timeout: 19, responseState: nil,
                                            cookies: NativeWriteRequestCookies(
                                                networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                                smallFlow: false, smallFlowValue: nil)), boundary: boundary)
        let body = try #require(request.body)
        let separator = try #require(body.range(of: Data("\r\n\r\n".utf8)))
        let end = Data("\r\n--\(boundary)--\r\n".utf8)
        let protobuf = body[separator.upperBound..<(body.count - end.count)]
        #expect(protobuf == Data(base64Encoded: sample.wireBase64))
        #expect(request.headers["Content-Length"] == String(body.count))
        #expect(request.url.query == "cmd=309731&format=protobuf")
        #expect(request.headers["Retry-Count"] == "0")
    }

    private func signed(_ sample: Sample) -> [String: String] {
        NativeWriteSigning.common(sample.common, business: sample.business, metadata: sample.metadata.value)
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-signing.json"))
        return try JSONDecoder().decode(Fixtures.self, from: data).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let name: String
        let kind: String
        let common: [String: String]
        let business: [String: String]
        let metadata: Metadata
        let expectedCommon: [String: String]
        let wireBase64: String
    }
    private struct Metadata: Decodable {
        let packageVersion: String?
        let experimentHits: String?
        let experimentMisses: String?
        var value: NativeWriteCommonMetadata {
            NativeWriteCommonMetadata(packageVersion: packageVersion, experimentHits: experimentHits,
                                      experimentMisses: experimentMisses)
        }
    }
}
