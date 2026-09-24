import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite
import UIKit

struct R07EmoticonParserTests {
    @Test
    func allAndroidDefaultsAndOfficialExtendedIDsResolveFromContentNodes() {
        let ids = Array(1...50) + Array(61...137)
        let source = ThreadContentSource(threadID: 701, postID: 702, scope: .post)
        for value in ids {
            let key = "image_emoticon\(value)"
            let node = ThreadContentNode(id: ThreadContentNodeID(source: source, ordinal: value), rawType: 2,
                                         payload: .emoji(ThreadEmojiContent(registryKey: key, code: "已证实表情")))
            let runs = TiebaRichText.runs(nodes: [node])
            #expect(runs.compactMap(\.emoticonID) == [key])
            #expect(runs.map(\.alternativeText).joined() == "#(已证实表情)")
        }
    }

    @Test
    func officialNamesCoverClassicNewAndExtendedFamilies() {
        let samples = [("微微一笑", 91), ("生气", 61), ("小乖", 66), ("你懂的", 68), ("吃瓜", 86),
                       ("摊手", 93), ("药丸", 81), ("不跟丑人说话", 101), ("么么哒", 102),
                       ("小姐姐来啦", 115), ("白眼", 124), ("奥特曼", 125), ("望远镜", 128), ("鼠2", 137)]
        for (name, number) in samples {
            for token in ["#(\(name))", "(#\(name))", "#\(name)"] {
                let runs = TiebaRichText.parse(token)
                let expected = token == "(#生气)" ? 31 : number
                #expect(runs.compactMap(\.emoticonID) == ["image_emoticon\(expected)"])
                #expect(runs.map(\.alternativeText).joined() == token)
            }
        }
    }

    @Test(arguments: ["#(捂嘴笑)", "(#捂嘴笑)", "#捂嘴笑"])
    func mouthCoveringLaughRendersInBodyAndReplyText(_ token: String) {
        let input = "正文\(token)\n回复：缓存呢\(token)"
        let runs = TiebaRichText.parse(input)
        #expect(runs.compactMap(\.emoticonID) == ["image_emoticon67", "image_emoticon67"])
        #expect(runs.map(\.alternativeText).joined() == input)
        #expect(runs.map(\.spokenText).joined() == "正文捂嘴笑表情\n回复：缓存呢捂嘴笑表情")
        #expect(TiebaEmoticonRegistry.resolve(registryKey: "image_emoticon67", name: "捂嘴笑")?.resourceID == "image_emoticon67")
        #expect(TiebaRichText.parse("#捂嘴笑话题 #捂嘴笑#").compactMap(\.emoticonID).isEmpty)
    }

    @Test
    func exactKnownTokensRenderWhileUnknownTopicsAndURLFragmentsStayText() {
        let input = "#滑稽 #(哈哈) (#噗) #未知 #滑稽话题 #滑稽# https://example.invalid/#滑稽"
        let runs = TiebaRichText.parse(input)
        #expect(runs.compactMap(\.emoticonID) == ["image_emoticon25", "image_emoticon2", "image_emoticon89"])
        #expect(runs.map(\.alternativeText).joined() == input)
    }

    @Test
    func consecutiveAndMixedUnicodePreserveEveryCharacter() {
        let input = "中文#(滑稽)English#(哈哈)(#噗)\n#(unknown)🙂"
        let runs = TiebaRichText.parse(input)
        #expect(runs.compactMap(\.emoticonID).count == 3)
        #expect(runs.map(\.alternativeText).joined() == input)
        #expect(runs.map(\.spokenText).joined().contains("滑稽表情"))
    }

    @Test
    func missingLocalResourcesDoNotInventReplacements() {
        #expect(TiebaRichText.parse("#(生气) #药丸").compactMap(\.emoticonID) == ["image_emoticon61", "image_emoticon81"])
        #expect(TiebaRichText.parse("#(未收录表情) #未知话题").compactMap(\.emoticonID).isEmpty)
        #expect(TiebaEmoticonRegistry.resolve(registryKey: "image_emoticon999", name: "滑稽") == nil)
        #expect(TiebaRichText.parse("(#生气)").compactMap(\.emoticonID) == ["image_emoticon31"])
        #expect(TiebaEmoticonRegistry.resolve(registryKey: "image_emoticon", name: "呵呵")?.resourceID == "image_emoticon1")
        #expect(TiebaEmoticonRegistry.resolve(registryKey: "unknown-key", name: "滑稽") == nil)
    }

    @Test
    func protoEmoticonAndInlineLinkKeepWireOrderAndIdentity() throws {
        var text = Tieba_PbContent(); text.type = 0; text.text = "之前"
        var emoji = Tieba_PbContent(); emoji.type = 2; emoji.text = "image_emoticon25"; emoji.c = "滑稽"
        var link = Tieba_PbContent(); link.type = 1; link.text = "链接"; link.link = "https://fixture.invalid/link"
        var mention = Tieba_PbContent(); mention.type = 4; mention.text = "@用户"; mention.uid = 7
        let source = ThreadContentSource(threadID: 701, postID: 702, scope: .post)
        let nodes = ThreadContentProtoMapper.map(
            postContent: [text, emoji, link, mention], source: source, availability: .available, poll: nil
        ).nodes
        let runs = TiebaRichText.runs(nodes: nodes)
        #expect(runs.map(\.alternativeText).joined() == "之前#(滑稽)链接@用户")
        #expect(runs.compactMap(\.emoticonID) == ["image_emoticon25"])
        #expect(runs.compactMap(\.linkIntent).first?.sourceNodeID.ordinal == 2)
        let blocks = ThreadContentBlock.make(nodes)
        #expect(blocks.count == 1)
        #expect(blocks.first?.id == nodes.first?.id)
    }
}

@MainActor
struct R07RichTextBuilderTests {
    @Test
    func mouthCoveringLaughUsesAnInlineImageAndCopiesItsOriginalToken() throws {
        let runs = TiebaRichText.parse("缓存呢#(捂嘴笑)")
        let result = TiebaRichTextBuilder.build(runs: runs, font: .systemFont(ofSize: 17))
        let attachment = try #require(result.attribute(.attachment, at: 3, effectiveRange: nil) as? NSTextAttachment)
        #expect(attachment.image != nil)
        #expect(result.string == "缓存呢\u{FFFC}")
        #expect(TiebaRichTextBuilder.copyText(result) == "缓存呢#(捂嘴笑)")
    }

    @Test
    func everyBundledOfficialAssetDecodesLocally() {
        #expect(TiebaEmoticonRegistry.bundledResourceIDs.count == 132)
        for id in TiebaEmoticonRegistry.bundledResourceIDs {
            let image = TiebaRichTextBuilder.image(resourceID: id)
            #expect(image != nil, "Missing bundled official resource: \(id)")
            #expect((image?.size.width ?? 0) > 0)
        }
        #expect(TiebaRichTextBuilder.image(resourceID: "unavailable") == nil)
    }

    @Test
    func attachmentScalesAlignsAndCopiesReadableText() throws {
        let runs = TiebaRichText.parse("前#滑稽 后")
        for size: CGFloat in [15, 17, 22, 40] {
            let font = UIFont.systemFont(ofSize: size)
            let result = TiebaRichTextBuilder.build(runs: runs, font: font)
            let attachment = try #require(result.attribute(.attachment, at: 1, effectiveRange: nil) as? NSTextAttachment)
            #expect(abs(attachment.bounds.width - font.lineHeight * 0.9) < 0.01)
            #expect(abs(attachment.bounds.midY - (font.ascender + font.descender) / 2) < 0.01)
            #expect(TiebaRichTextBuilder.copyText(result) == "前#滑稽 后")
            #expect(TiebaRichTextBuilder.copyText(result.attributedSubstring(from: NSRange(location: 1, length: 1))) == "#滑稽")
        }
    }

    @Test
    func longTextWrapsAndRepeatedUpdatesPreserveSelection() {
        let view = TiebaSelectableTextView()
        let runs = TiebaRichText.parse(String(repeating: "中文English#(滑稽) ", count: 80))
        view.apply(runs: runs, pointSize: 17, lineLimit: 0, interactive: true)
        let attachmentIndex = (view.attributedText.string as NSString).range(of: "\u{FFFC}").location
        let first = view.attributedText.attribute(.attachment, at: attachmentIndex, effectiveRange: nil) as? NSTextAttachment
        view.selectedRange = NSRange(location: 1, length: 2)
        view.apply(runs: runs, pointSize: 17, lineLimit: 0, interactive: true)
        let reused = view.attributedText.attribute(.attachment, at: attachmentIndex, effectiveRange: nil) as? NSTextAttachment
        #expect(reused === first)
        #expect(view.selectedRange == NSRange(location: 1, length: 2))
        let narrow = view.sizeThatFits(CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude))
        let wide = view.sizeThatFits(CGSize(width: 500, height: CGFloat.greatestFiniteMagnitude))
        #expect(narrow.height > wide.height)
        #expect(narrow.height > 100)
        #expect(!view.isScrollEnabled)
        #expect(view.accessibilityLabel?.contains("滑稽表情") == true)
        view.apply(runs: runs, pointSize: 32, lineLimit: 0, interactive: true)
        #expect(view.sizeThatFits(CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude)).height > narrow.height)
    }
}
