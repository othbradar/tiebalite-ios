import Foundation
import Testing
@testable import TiebaLite

struct U08NativeReplyContentTests {
    @Test
    func composerTextMatchesNativePreparationWithoutLegacyTruncation() throws {
        let samples = try NativeClientFixture.replyContent()
        #expect(samples.count == 16)
        for sample in samples {
            let predicate = NSPredicate(format: "SELF MATCHES %@", #"回复 [\s\S]* :"#)
            let match = sample.input.recipientPrompt.map { predicate.evaluate(with: $0) } ?? false
            #expect(match == sample.foundationPredicateMatch, "Foundation primitive parity: \(sample.name)")
            #expect(Array(sample.input.preparedText().utf16) == Array(sample.expected.utf16), "\(sample.name)")
        }
    }

    @Test
    func editorContextDoesNotExposeContentOrRecipientInDescriptions() throws {
        let input = try #require(NativeClientFixture.replyContent().first).input
        #expect(String(describing: input) == "NativeReplyComposeContent(redacted)")
        #expect(String(reflecting: input) == "NativeReplyComposeContent(redacted)")
        #expect(String(reflecting: NativeWriteContent.prepared("Synthetic private draft")) == "NativeWriteContent(redacted)")
        #expect(String(reflecting: NativeWriteContent.replyCompose(input)) == "NativeWriteContent(redacted)")
    }
}
