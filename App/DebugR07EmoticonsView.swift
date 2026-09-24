#if DEBUG
import SwiftUI

@MainActor
struct DebugR07EmoticonsView: View {
    @State private var largeText = false
    @State private var dark = false
    @State private var linkOpened = false
    let imageLoader: any ImageLoading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Toggle("大字号", isOn: $largeText).accessibilityIdentifier("r07.large")
                    Toggle("深色", isOn: $dark).accessibilityIdentifier("r07.dark")
                }
                .font(.subheadline)
                NavigationLink("链接交互对照 A / B / C") {
                    DebugR07LinkLab()
                }
                .accessibilityIdentifier("r07.link.open")
                sample("纯文本", document: document(text: "这是普通中文与 English 文本。", ordinal: 1))
                sample("裸名称 / 连续 / 中英混排", document: document(
                    text: "#滑稽 #(捂嘴笑) #(微微一笑)#(哈哈)\n中文#(吃瓜)English #(鼠2)", ordinal: 2))
                sample("独立 Proto 表情 + 链接 + @", document: mixed)
                Text(linkOpened ? "链接意图已收到" : "点击行内链接检查原意图")
                    .font(.caption).foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityIdentifier("r07.link-result")
                sample("未知名称 / 普通话题", document: document(
                    text: "#未知表情 #话题 #滑稽话题 #滑稽# #(未收录)", ordinal: 4))
                sample("多行长文", document: document(
                    text: String(repeating: "表情跟着文字#(滑稽)换行，English 与中文保持顺序。", count: 4), ordinal: 5))
                Text("固定样本 · 非 Live 数据").font(.caption).foregroundStyle(SemanticColor.secondaryText)
                NavigationLink("全部 \(TiebaEmoticonRegistry.catalog.count) 个官方表情") {
                    DebugR07EmoticonCatalogView()
                }
                .accessibilityIdentifier("r07.catalog.open")
            }
            .padding(16)
        }
        .background(SemanticColor.background)
        .navigationTitle("官方表情对照")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(dark ? .dark : .light)
        .accessibilityIdentifier("r07.emoticons")
    }

    private func sample(_ title: String, document: ThreadContentDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(SemanticColor.secondaryText)
            ThreadContentRenderer(document: document, imageLoader: imageLoader,
                                  readingTextSize: largeText ? .large : .standard,
                                  onOpenExternalLink: { _ in linkOpened = true })
            TiebaFlatDivider(inset: 0)
        }
    }

    private func document(text: String, ordinal: Int64) -> ThreadContentDocument {
        let source = ThreadContentSource(threadID: 70_007, postID: ordinal, scope: .post)
        return ThreadContentDocument(source: source, availability: .available, nodes: [
            ThreadContentNode(id: ThreadContentNodeID(source: source, ordinal: 0), rawType: 0,
                              payload: .text(ThreadTextContent(value: text)))
        ], poll: nil)
    }

    private var mixed: ThreadContentDocument {
        let source = ThreadContentSource(threadID: 70_007, postID: 3, scope: .post)
        let id = ThreadContentNodeID(source: source, ordinal: 2)
        let values: [ThreadContentPayload] = [
            .text(ThreadTextContent(value: "之前 ")),
            .emoji(ThreadEmojiContent(registryKey: "image_emoticon25", code: "滑稽")),
            .link(ThreadLinkContent(label: " 测试链接 ", intent: ExternalLinkIntent(
                sourceNodeID: id, label: " 测试链接 ",
                destination: ValidatedWebDestination(absoluteString: "https://fixture.invalid/r07", scheme: .https)
            ), rejection: nil)),
            .mention(ThreadMentionContent(userID: 7, label: "@样本用户")),
            .text(ThreadTextContent(value: " 之后"))
        ]
        return ThreadContentDocument(source: source, availability: .available, nodes: values.enumerated().map {
            ThreadContentNode(id: ThreadContentNodeID(source: source, ordinal: $0.offset), rawType: 0, payload: $0.element)
        }, poll: nil)
    }
}

@MainActor
private struct DebugR07EmoticonCatalogView: View {
    var body: some View {
        List(TiebaEmoticonRegistry.catalog, id: \.resourceID) { emoticon in
            TiebaRichTextView(runs: [
                .emoticon(emoticon, alternative: "#(\(emoticon.name))"),
                .text("  \(emoticon.name) · \(emoticon.resourceID)")
            ], fontSize: 17)
            .accessibilityIdentifier("r07.catalog.\(emoticon.resourceID)")
        }
        .listStyle(.plain)
        .navigationTitle("官方表情 · \(TiebaEmoticonRegistry.catalog.count)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
