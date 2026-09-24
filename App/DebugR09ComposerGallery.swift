#if UITESTING
import SwiftUI

struct DebugR09ComposerGallery: View {
    @Environment(\.textComposer) private var host
    @State private var target: TextComposeTarget?
    @State private var simulatesFailure = false
    @State private var result = "尚未模拟发送"

    var body: some View {
        List {
            Section {
                Text("以下使用隔离 Mock，不会发送到贴吧。完整应用中的发帖和回复入口使用当前登录账号。")
                    .font(.caption).foregroundStyle(SemanticColor.secondaryText)
                Toggle("模拟网络失败", isOn: $simulatesFailure).accessibilityIdentifier("r09.mock.failure")
            }
            Section("编辑器") {
                ForEach([TextComposeTarget.Kind.thread, .threadReply, .floorReply, .subpostReply], id: \.rawValue) { kind in
                    Button(Self.target(kind).title) { target = Self.target(kind) }
                        .accessibilityIdentifier("r09.open.\(kind.rawValue)")
                }
            }
            Section("模拟结果") {
                Text(result).accessibilityIdentifier("r09.mock.result")
            }
        }
        .navigationTitle("文字编辑器")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: target) { _, target in
            guard let target else { return }
            let service = TextComposerService(
                repository: FixtureTextWriteRepository(failure: simulatesFailure ? .network : nil),
                currentContext: { .active(.init(sessionID: .init(rawValue: 9), generation: 1)) })
            host?.present(target, using: service) { receipt in
                result = "模拟发送成功 · 服务器返回帖子 \(receipt.threadID)，回复 \(receipt.postID)"
            }
            self.target = nil
        }
    }

    private static func target(_ kind: TextComposeTarget.Kind) -> TextComposeTarget {
        .init(kind: kind, forumID: 90, forumName: "固定样本", threadID: kind == .thread ? 0 : 101,
              postID: [.floorReply, .subpostReply].contains(kind) ? 202 : 0,
              subpostID: kind == .subpostReply ? 303 : 0,
              recipient: [.floorReply, .subpostReply].contains(kind)
                ? .init(rawUserID: 44, displayName: "样本作者", portrait: "fixture-portrait") : nil,
              quote: kind == .thread ? "" : "这是待回复的原文，仅作布局展示。")
    }
}
#endif
