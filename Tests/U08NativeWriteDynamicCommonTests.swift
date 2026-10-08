import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteDynamicCommonTests {
    @Test
    func matchesNativeBranchFieldsAndConsumedMetrics() throws {
        for sample in try samples() {
            var metrics = sample.metrics
            let fields = NativeWriteDynamicCommonParameters.prepare(
                staticFields: sample.staticFields, business: sample.business, context: sample.input, metrics: &metrics
            )
            #expect(fields == sample.expected.fields, "\(sample.name)")
            #expect(metrics == sample.expected.metricsAfter, "\(sample.name)")
            #expect(NativeWriteDynamicCommonParameters.branch(for: sample.input) == sample.expected.path)
        }
    }

    @Test
    func requestMetricsAreConsumedOnlyOnceAndNotClearedWithoutPreviousAPI() throws {
        let all = try samples()
        let sample = try #require(all.first { $0.name == "standard-full" })
        var metrics = sample.metrics
        _ = NativeWriteDynamicCommonParameters.prepare(
            staticFields: sample.staticFields, business: sample.business, context: sample.input, metrics: &metrics
        )
        let second = NativeWriteDynamicCommonParameters.prepare(
            staticFields: sample.staticFields, business: sample.business, context: sample.input, metrics: &metrics
        )
        #expect(second.keys.allSatisfy { !$0.hasPrefix("m_") })
        #expect(metrics == sample.expected.metricsAfter)

        let noAPI = try #require(all.first { $0.name == "standard-no-previous-api" })
        var untouched = noAPI.metrics
        let fields = NativeWriteDynamicCommonParameters.prepare(
            staticFields: noAPI.staticFields, business: noAPI.business, context: noAPI.input, metrics: &untouched
        )
        #expect(untouched == noAPI.metrics)
        #expect(fields.keys.allSatisfy { !$0.hasPrefix("m_") })
    }

    @Test
    func optimizedEmptyValuesPreserveStaticSampleButStandardOverwritesIt() throws {
        let all = try samples()
        for name in ["standard-empty", "optimized-empty"] {
            let sample = try #require(all.first { $0.name == name })
            var metrics = sample.metrics
            let fields = NativeWriteDynamicCommonParameters.prepare(
                staticFields: sample.staticFields, business: sample.business, context: sample.input, metrics: &metrics
            )
            #expect(fields["sample_id"] == (name == "standard-empty" ? "" : "static"))
            #expect(fields["_client_type"] == "1")
        }
    }

    @Test
    func providerAndMetricDescriptionsAreRedacted() throws {
        let sample = try #require(samples().first)
        #expect(String(describing: sample.input) == "NativeWriteDynamicCommonContext(redacted)")
        #expect(String(reflecting: sample.input) == "NativeWriteDynamicCommonContext(redacted)")
        #expect(String(describing: sample.metrics) == "NativeWriteRequestMetrics(redacted)")
        #expect(String(reflecting: sample.metrics) == "NativeWriteRequestMetrics(redacted)")
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-dynamic-common.json"))
        return try JSONDecoder().decode(Fixtures.self, from: bytes).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let name: String
        let input: NativeWriteDynamicCommonContext
        let staticFields: [String: String]
        let business: [String: String]
        let metrics: NativeWriteRequestMetrics
        let expected: Expected
    }
    private struct Expected: Decodable {
        let fields: [String: String]
        let metricsAfter: NativeWriteRequestMetrics
        let path: NativeWriteDynamicCommonParameters.Branch
    }
}
