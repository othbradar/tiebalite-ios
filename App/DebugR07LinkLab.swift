#if DEBUG
import SwiftUI

/// Fixed samples in the same shared host used by thread floors; no live repository or session changes.
struct DebugR07LinkLab: View {
    @State private var activations: [Int: Int] = [:]
    @State private var lastIntent = "尚未激活"
    @State private var pastedText = ""

    private struct Sample: Identifiable, Equatable, Sendable { let id: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("R07 候选 · 固定链接对照").font(.headline)
            HStack {
                ForEach([0, 1, 2, 13], id: \.self) { sample in
                    Text("激活 \(activations[sample, default: 0]) 次")
                        .font(.caption)
                        .accessibilityIdentifier("r07.link.count.\(sample)")
                }
            }
            Text(lastIntent).font(.caption).accessibilityIdentifier("r07.link.last-intent")
            TextField("复制后可粘贴检查", text: $pastedText)
                .font(.caption).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("r07.link.paste")
            GeometryReader { geometry in
                VirtualizedList(items: (0..<14).map { Sample(id: $0) }, backgroundColor: .systemBackground,
                                accessibilityIdentifier: "r07.link.list") { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title(sample.id)).font(.subheadline)
                        TiebaRichTextView(runs: runs(sample.id)) { intent in
                            activations[sample.id, default: 0] += 1
                            lastIntent = intent.sourceNodeID.stableKey + " | " + intent.destination.absoluteString
                        }
                        .accessibilityIdentifier("r07.link.sample.\(sample.id)")
                        TiebaFlatDivider(inset: 0)
                    }
                    .padding(.vertical, 16)
                }
                .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
        }
        .padding(.horizontal, 16)
        .background(SemanticColor.background)
        .navigationTitle("链接交互对照")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("r07.link.lab")
    }

    private func title(_ sample: Int) -> String {
        if sample < 3 { return ["A 普通文字 + 链接", "B 表情 + 中文 + 链接 + @", "C 换行后的同一链接"][sample] }
        return sample == 13 ? "D 复用后的不同楼层链接" : "滚动对照段 \(sample)"
    }

    private func runs(_ sample: Int) -> [TiebaRichTextRun] {
        let id = ThreadContentNodeID(source: ThreadContentSource(threadID: 70_007, postID: Int64(10 + sample), scope: .post), ordinal: 2)
        let destination = sample < 3 ? "https://fixture.invalid/r07" : "https://fixture.invalid/r07/row23"
        let link = ExternalLinkIntent(sourceNodeID: id, label: "测试链接",
                                      destination: ValidatedWebDestination(absoluteString: destination, scheme: .https))
        switch sample {
        case 0: return [.text("普通文字 "), .link(link), .text(" 后文")]
        case 1: return TiebaRichText.parse("#滑稽 中文 ") + [.link(link), .mention(" @样本用户")]
        case 2: return TiebaRichText.parse("#滑稽 中文换行对照\n") + [.link(link), .mention(" @样本用户 后文")]
        case 13: return TiebaRichText.parse("新楼层 #滑稽 ") + [.link(link)]
        default: return [.text("这是用于原生文字选择和列表滚动的固定样本。滚出屏幕后返回，链接仍对应当前楼层。")]
        }
    }
}
#endif
