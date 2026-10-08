import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteParametersTests {
    @Test
    func plainTextTargetsMatchNativeBusinessMethodResults() throws {
        for sample in try samples() {
            let kind = try #require(TextComposeTarget.Kind(rawValue: sample.kind))
            let request = input(kind: kind, title: sample.title, content: sample.content)
            let actual: [String: String]
            if kind == .thread {
                actual = try NativeTextWriteParameters.thread(
                    request, preparedContent: sample.content, account: account,
                    entranceType: #require(sample.entranceType))
            } else {
                let context = NativeTextWriteParameters.ReplyContext(
                    container: sample.container == "subposts" ? .subposts : .threadPage,
                    pageEntryType: try #require(sample.pageEntryType), floorNumber: "0", replyCount: sample.replyCount)
                actual = try NativeTextWriteParameters.reply(
                    request, preparedContent: sample.content, account: account, context: context)
                #expect(sample.interceptedLoadCount == 1)
            }
            #expect(actual == sample.business, "\(sample.name)")
        }
    }

    @Test
    func replyDoesNotInventMissingCountOrAnonymousFlagFromAndroid() throws {
        let request = input(kind: .threadReply)
        let fields = try NativeTextWriteParameters.reply(
            request, preparedContent: request.draft.content,
            account: account, context: .init(container: .threadPage, pageEntryType: 0,
                                             floorNumber: "0", replyCount: nil))
        #expect(fields["floor"] == nil && fields["quote_id"] == nil && fields["repostid"] == nil)
        #expect(fields["anonymous"] == "0" && fields["post_from"] == "0")
        #expect(fields["v_fid"] == nil && fields["v_fname"] == nil)
    }

    @Test
    func subpostKeepsParentAndRecipientAsSeparateIdentities() throws {
        let request = input(kind: .subpostReply)
        let fields = try NativeTextWriteParameters.reply(
            request, preparedContent: "Already prepared reply content",
            account: account, context: .init(container: .subposts, pageEntryType: 0,
                                             floorNumber: "0", replyCount: "7"))
        #expect(fields["quote_id"] == "301" && fields["repostid"] == "301")
        #expect(fields["sub_post_id"] == "302" && fields["reply_uid"] == "42")
        #expect(fields["content"] == "Already prepared reply content")
        #expect(fields["send_from"] == "pb_sub_subsub")
    }

    @Test
    func incompleteAccountAndWrongTargetDoNotProduceNativeBusinessFields() {
        #expect(throws: TextWriteFailure.authentication) {
            try NativeTextWriteParameters.thread(
                input(kind: .thread), preparedContent: "Synthetic thread",
                account: .init(userID: "42", tbs: ""), entranceType: 1)
        }
        #expect(throws: TextWriteFailure.invalidTarget) {
            try NativeTextWriteParameters.thread(
                input(kind: .threadReply), preparedContent: "Synthetic reply", account: account, entranceType: 1)
        }
    }

    private var account: TextWriteAccount {
        .init(userID: "42", tbs: "fixture-tbs", nameShow: "FixtureName")
    }

    private func input(kind: TextComposeTarget.Kind, title: String = "", content: String = "Synthetic reply") -> TextWriteRequest {
        let isChild = kind == .floorReply || kind == .subpostReply
        return .init(
            target: .init(
                kind: kind, forumID: 9, forumName: "FixtureForum",
                threadID: kind == .thread ? 0 : 101, postID: isChild ? 301 : 0,
                subpostID: kind == .subpostReply ? 302 : 0,
                recipient: isChild ? .init(rawUserID: 42, displayName: "Fixture recipient", portrait: "fixture-portrait") : nil),
            draft: .init(title: title, content: content))
    }

    private func samples() throws -> [Sample] {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-business-parameters.json"))
        return try JSONDecoder().decode(Fixtures.self, from: data).cases
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable {
        let name: String
        let kind: String
        let title: String
        let content: String
        let container: String?
        let pageEntryType: Int?
        let replyCount: String?
        let entranceType: Int?
        let business: [String: String]
        let interceptedLoadCount: Int
    }
}
