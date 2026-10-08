import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteCommonTransformTests {
    @Test
    func preparedCommonAndEncodedReplyMatchBothNativePaths() throws {
        for sample in try samples() {
            var parameters = NativeWriteCommonParameters()
            var metrics = sample.metrics
            let actual = parameters.prepare(sample.context, business: sample.business, metrics: &metrics)
            #expect(actual == sample.expected.signedCommon, "\(sample.name)")
            #expect(metrics == sample.expected.metricsAfter)
            let bytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: sample.business, common: actual)
            #expect(bytes == Data(base64Encoded: sample.wireBase64), "\(sample.name)")
        }
    }

    @Test
    func optimizedBranchDoesNotAppendStandardMetadata() throws {
        let sample = try #require(samples().first { $0.name == "optimized-metadata" })
        var parameters = NativeWriteCommonParameters()
        var metrics = sample.metrics
        let actual = parameters.prepare(sample.context, business: sample.business, metrics: &metrics)
        #expect(actual["package_version"] == nil)
        #expect(actual["abtest_config_intervention"] == nil)
        #expect(actual["content"] == nil && actual["tid"] == nil)
        #expect(actual["sign"] == sample.expected.signedCommon["sign"])
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-common-transform.json"))
        return try JSONDecoder().decode(Fixtures.self, from: bytes).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let name: String
        let staticContext: NativeWriteStaticCommonContext
        let staticMode: NativeWriteStaticCommonParameters.Mode
        let input: NativeWriteDynamicCommonContext
        let business: [String: String]
        let metrics: NativeWriteRequestMetrics
        let metadata: Metadata
        let expected: Expected
        let wireBase64: String

        var context: NativeWriteCommonContext {
            let annotations = NativeWriteCommonMetadata(packageVersion: metadata.packageVersion,
                                                        experimentHits: metadata.experimentHits,
                                                        experimentMisses: metadata.experimentMisses)
            return NativeWriteCommonContext(staticValues: staticContext, staticMode: staticMode,
                                            dynamicValues: input, metadata: annotations)
        }
    }
    private struct Metadata: Decodable {
        let packageVersion: String?
        let experimentHits: String?
        let experimentMisses: String?
    }
    private struct Expected: Decodable {
        let signedCommon: [String: String]
        let metricsAfter: NativeWriteRequestMetrics
    }
}
