import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteResponseDecoderTests {
    @Test
    func nativeDescriptorBytesDecodeWithoutPromotingMetadataToFailure() throws {
        for sample in try samples() {
            let bytes = try #require(Data(base64Encoded: sample.wireBase64))
            let response = try NativeWriteResponseDecoder.decode(bytes)
            #expect(response.errorCode == sample.errorCode, "\(sample.name)")
            #expect(response.hasPayload == sample.hasPayload, "\(sample.name)")
            #expect(response.serverRejected == (sample.errorCode > 0), "\(sample.name)")
            #expect(response.threadID == sample.threadID && response.postID == sample.postID)
            #expect(response.accountAction?.rawValue == sample.accountAction)
            #expect(response.category?.rawValue == sample.category)
        }
    }

    @Test
    func allReplyTargetsCanCorrelateSuccessfulNativeReceiptsWithExtraVerificationMetadata() throws {
        let fixture = try #require(samples().first { $0.name == "post-metadata-success" })
        let response = try NativeWriteResponseDecoder.decode(#require(Data(base64Encoded: fixture.wireBase64)))
        for target in [R09WriteFixture.target(.threadReply), R09WriteFixture.target(.floorReply), R09WriteFixture.target(.subpostReply)] {
            #expect(response.correlatedReceipt(for: target) == TextWriteReceipt(threadID: 101, postID: 401))
        }
    }

    @Test
    func serverRejectionAndUncorrelatedIDsNeverCreateReceipts() throws {
        for name in ["post-error-with-ids", "post-missing-data", "post-missing-id", "post-wrong-thread"] {
            let sample = try #require(samples().first { $0.name == name })
            let response = try NativeWriteResponseDecoder.decode(#require(Data(base64Encoded: sample.wireBase64)))
            #expect(response.correlatedReceipt(for: R09WriteFixture.target(.threadReply)) == nil, "\(name)")
        }
    }

    @Test
    func nativeNewThreadReturnsItsOwnServerIDs() throws {
        let sample = try #require(samples().first { $0.name == "thread-success" })
        let response = try NativeWriteResponseDecoder.decode(#require(Data(base64Encoded: sample.wireBase64)))
        #expect(response.correlatedReceipt(for: R09WriteFixture.target(.thread)) == TextWriteReceipt(threadID: 501, postID: 601))
    }

    @Test
    func unknownFieldsDoNotChangeAValidReceipt() throws {
        let sample = try #require(samples().first { $0.name == "post-success" })
        var wire = try #require(Data(base64Encoded: sample.wireBase64))
        wire.append(contentsOf: [0xf8, 0x07, 0x01]) // Unknown field 127, varint 1.
        let response = try NativeWriteResponseDecoder.decode(wire)
        #expect(response.correlatedReceipt(for: R09WriteFixture.target(.threadReply)) ==
                TextWriteReceipt(threadID: 101, postID: 401))
    }

    @Test
    func malformedWireThrowsAndEmptyWireHasNoConfirmedReceipt() throws {
        #expect(throws: (any Error).self) { try NativeWriteResponseDecoder.decode(Data([0x12, 0xff])) }
        let empty = try NativeWriteResponseDecoder.decode(Data())
        #expect(!empty.hasPayload && empty.correlatedReceipt(for: R09WriteFixture.target(.threadReply)) == nil)
        #expect(String(reflecting: empty) == "NativeWriteDecodedResponse(redacted)")
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-response-decoding.json"))
        return try JSONDecoder().decode(Fixtures.self, from: bytes).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let name: String
        let wireBase64: String
        let errorCode: Int32
        let hasPayload: Bool
        let threadID: String
        let postID: String
        let accountAction: String?
        let category: String?
    }
}
