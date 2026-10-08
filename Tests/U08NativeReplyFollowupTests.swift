import Foundation
import Testing
@testable import TiebaLite

struct U08NativeReplyFollowupTests {
    @Test
    func replyFollowupUsesReceiptAndNativePageSelectionFields() throws {
        let cases = try samples().filter { $0.kind != "load" }
        #expect(cases.count == 11)
        for sample in cases {
            let actual: [String: String]?
            if sample.kind == "floor" {
                actual = NativeReplyFollowupParameters.floor(
                    threadID: sample.input.threadID, replyPostID: sample.input.postID)
                #expect(sample.expected.dispatchModes == [3])
                #expect(sample.expected.cleared == ["setParsedDataDict:", "setParsedListItem:"])
            } else {
                actual = NativeReplyFollowupParameters.ordinaryThread(
                    preparedPageFields: sample.input.base, replyPostID: sample.input.postID,
                    includesFoldedComments: sample.input.includesFoldedComments ?? false)
                #expect(sample.expected.preparedBaseUses == 1)
            }
            #expect(actual == sample.expected.fields?.mapValues(\.text), "\(sample.name)")
        }
    }

    @Test
    func activeFollowupDoesNotIssueAnotherRequestOrConsumeAnotherRequestCount() throws {
        let cases = try samples().filter { $0.kind == "load" }
        #expect(cases.count == 5)
        for sample in cases {
            let inputFields = try #require(sample.input.base)
            let result = NativeReplyFollowupParameters.threadLoad(
                preparedFields: inputFields, serverState: try #require(sample.input.serverState),
                requestCount: try #require(sample.input.requestCount))
            #expect((result != nil) == sample.expected.afterReply, "\(sample.name)")
            if let result {
                #expect(result.parameters == sample.expected.fields?.mapValues(\.text), "\(sample.name)")
                #expect(result.requestCount == sample.expected.requestCount)
                #expect(sample.expected.dispatchModes == [3])
            } else {
                #expect(sample.expected.dispatchModes.isEmpty)
                #expect(sample.expected.requestCount == sample.input.requestCount)
                #expect(sample.expected.fields?.mapValues(\.text) == inputFields)
            }
        }
    }

    @Test
    func preparationDoesNotMutateReadingPageFieldsOrExposeIDsInDescriptions() throws {
        let original = ["kz": "101", "pn": "7", "r": "30", "last_pid": "11"]
        let prepared = try #require(NativeReplyFollowupParameters.ordinaryThread(
            preparedPageFields: original, replyPostID: "430001", includesFoldedComments: false))
        #expect(original["pn"] == "7" && original["last_pid"] == "11")
        #expect(prepared["pn"] == nil && prepared["last_pid"] == "430001")
        let load = try #require(NativeReplyFollowupParameters.threadLoad(
            preparedFields: prepared, serverState: 3, requestCount: 10))
        #expect(String(describing: load) == "NativeReplyFollowupLoad(redacted)")
        #expect(String(reflecting: load) == "NativeReplyFollowupLoad(redacted)")
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-reply-followup.json"))
        return try JSONDecoder().decode(Fixtures.self, from: data).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let kind: String
        let name: String
        let input: Input
        let expected: Expected
    }
    private struct Input: Decodable {
        let threadID: String?
        let postID: String?
        let base: [String: String]?
        let includesFoldedComments: Bool?
        let serverState: Int?
        let requestCount: Int64?
    }
    private struct Expected: Decodable {
        let fields: [String: Scalar]?
        let dispatchModes: [Int]
        let requestCount: Int64
        let afterReply: Bool
        let cleared: [String]
        let preparedBaseUses: Int
    }
    private struct Scalar: Decodable {
        let text: String
        init(from decoder: any Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let number = try? value.decode(Int64.self) {
                text = String(number)
            } else {
                text = try value.decode(String.self)
            }
        }
    }
}
