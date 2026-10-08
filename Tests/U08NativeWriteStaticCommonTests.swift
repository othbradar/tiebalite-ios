import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteStaticCommonTests {
    @Test
    func bothNativeConstructionPathsMatchProviderSnapshotsAndChanges() throws {
        for sample in try samples() {
            var parameters = NativeWriteStaticCommonParameters()
            for step in sample.steps {
                #expect(parameters.parameters(step.input, mode: step.mode) == step.expected, "\(sample.name)")
            }
        }
    }

    @Test
    func recomputedBranchDoesNotOverwritePreviouslyCachedStaticValues() throws {
        let sample = try #require(samples().first { $0.name == "switch-paths" })
        var parameters = NativeWriteStaticCommonParameters()
        let first = parameters.parameters(sample.steps[0].input, mode: sample.steps[0].mode)
        let fresh = parameters.parameters(sample.steps[1].input, mode: sample.steps[1].mode)
        let cached = parameters.parameters(sample.steps[2].input, mode: sample.steps[2].mode)
        #expect(first["_os_version"] != fresh["_os_version"])
        #expect(first["_os_version"] == cached["_os_version"])
        #expect(first["pure_mode"] != cached["pure_mode"])
    }

    @Test
    func inputDebugDescriptionDoesNotExposeProviderValues() throws {
        let input = try #require(samples().first?.steps.first?.input)
        #expect(String(describing: input) == "NativeWriteStaticCommonContext(redacted)")
        #expect(String(reflecting: input) == "NativeWriteStaticCommonContext(redacted)")
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-static-common.json"))
        return try JSONDecoder().decode(Fixtures.self, from: bytes).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable { let name: String; let steps: [Step] }
    private struct Step: Decodable {
        let input: NativeWriteStaticCommonContext
        let mode: NativeWriteStaticCommonParameters.Mode
        let expected: [String: String]
    }
}
