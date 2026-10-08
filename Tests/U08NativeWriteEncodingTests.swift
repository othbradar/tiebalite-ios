import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct U08NativeWriteEncodingTests {
    @Test func emptyOfflineNetworkTypeKeepsNativeExplicitZero() throws {
        let bytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: [:], common: ["net_type": ""])
        let common = try TiebaNativeWrite_PostRequest(serializedBytes: bytes).data.common
        #expect(common.hasNetType && common.netType == 0)
    }

    @Test func emptyPersonalizedSwitchKeepsNativeExplicitZeroPresence() throws {
        #expect(("" as NSString).intValue == 0)
        for kind in [TextComposeTarget.Kind.threadReply, .thread] {
            let bytes = try NativeWriteRequestEncoder.encode(
                kind: kind, business: [:], common: ["personalized_rec_switch": ""])
            // data -> common -> field 63 (int32), explicitly present zero.
            #expect(bytes == Data([0x0A, 0x05, 0x0A, 0x03, 0xF8, 0x03, 0x00]))
        }
        let absent = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: [:], common: [:])
        #expect(!(try TiebaNativeWrite_PostRequest(serializedBytes: absent)).data.common.hasPersonalizedRecSwitch)
    }

    @Test
    func nativeRequestsMatchIndependentDescriptorEncoding() throws {
        for sample in try samples() {
            let kind = try #require(TextComposeTarget.Kind(rawValue: sample.kind))
            let actual = try NativeWriteRequestEncoder.encode(kind: kind, business: sample.business, common: sample.common)
            #expect(NativeWriteRequestEncoder.command(for: kind) == sample.command)
            #expect(actual == Data(base64Encoded: sample.wireBase64), "\(sample.name)")
        }
    }

    @Test
    func replyKeepsBusinessTokenAndExplicitZeroWithoutRoundingTimestamp() throws {
        let sample = try #require(samples().first)
        let bytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: sample.business, common: sample.common)
        let data = try TiebaNativeWrite_PostRequest(serializedBytes: bytes).data
        #expect(data.tbs == "fixture-tbs" && !data.common.hasTbs)
        #expect(!data.hasSig && data.common.sign == "fixture-sign")
        #expect(data.common.timestamp == 9_007_199_254_740_993)
        #expect(data.common.scrW == 393 && data.common.scrH == 852 && data.common.scrDip == 3)
        #expect(data.hasWithTail && data.withTail == 0)
        #expect(data.hasShowCustomFigure && data.showCustomFigure == 0)
        #expect(data.sendFrom == "pb_reply")
    }

    @Test
    func unknownCommonSignatureIsNotPromotedIntoBusinessData() throws {
        let sample = try #require(samples().first)
        var common = sample.common
        common["sig"] = "fixture-common-sig"
        let bytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: sample.business, common: common)
        let data = try TiebaNativeWrite_PostRequest(serializedBytes: bytes).data
        #expect(!data.hasSig && bytes == Data(base64Encoded: sample.wireBase64))
    }

    @Test
    func explicitEmptyReplyFieldDiffersFromAbsentField() throws {
        let fixtures = try samples()
        let absent = try #require(fixtures.first { $0.name == "post-basic" })
        let present = try #require(fixtures.first { $0.name == "post-empty-presence" })
        let absentBytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: absent.business, common: absent.common)
        let presentBytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: present.business, common: present.common)
        let absentData = try TiebaNativeWrite_PostRequest(serializedBytes: absentBytes).data
        let presentData = try TiebaNativeWrite_PostRequest(serializedBytes: presentBytes).data
        #expect(!absentData.hasVFid && !absentData.hasVFname)
        #expect(presentData.hasVFid && presentData.vFid.isEmpty)
        #expect(presentData.hasVFname && presentData.vFname.isEmpty)
        #expect(absentBytes != presentBytes)
    }

    @Test(arguments: ["not-a-number", "393.5", "2147483648"])
    func invalidIntegerCannotSilentlyProduceARequest(_ invalid: String) throws {
        let sample = try #require(samples().first)
        var common = sample.common
        common["scr_w"] = invalid
        #expect(throws: (any Error).self) {
            try NativeWriteRequestEncoder.encode(kind: .threadReply, business: sample.business, common: common)
        }
    }

    @Test(arguments: [TextComposeTarget.Kind.threadReply, .floorReply, .subpostReply])
    func allReplyTargetsUsePostCommand(_ kind: TextComposeTarget.Kind) {
        #expect(NativeWriteRequestEncoder.command(for: kind) == 309731)
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-request-encoding.json"))
        return try JSONDecoder().decode(Fixtures.self, from: bytes).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let name: String
        let kind: String
        let command: Int
        let business: [String: String]
        let common: [String: String]
        let wireBase64: String
    }
}
