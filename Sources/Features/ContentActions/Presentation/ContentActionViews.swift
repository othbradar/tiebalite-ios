import SwiftUI

extension EnvironmentValues { @Entry var contentActions: ContentActionStore? }

/// Preserves each existing icon, count font, spacing and hit area.
struct ContentLikeButton<Label: View>: View {
    let target: ContentActionTarget
    let count: Int64?
    @ViewBuilder let label: (Int64?) -> Label
    @Environment(\.contentActions) private var store
    var body: some View {
        Button { Task { await store?.toggleLike(target) } } label: {
            label(store?.likes[target]?.count ?? count)
                .foregroundStyle(store?.likes[target]?.selected == true ? SemanticColor.accent : SemanticColor.secondaryText)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!target.isValid || store == nil || store?.busy.contains(target) == true)
        .accessibilityLabel(store?.likes[target]?.selected == true ? "取消点赞" : "点赞")
        .accessibilityValue(String(store?.likes[target]?.count ?? count ?? 0))
        .accessibilityIdentifier("content.like.\(target.id)")
    }
}

struct ContentDeleteAction: View {
    let target: ContentActionTarget
    @Environment(\.contentActions) private var store
    var body: some View {
        if let store, store.permissions[target]?.canDelete == true, !store.uncertain.contains(target) {
            Button(target.deletionTitle, role: .destructive) { store.askToDelete(target) }
                .disabled(store.busy.contains(target))
                .accessibilityIdentifier("content.delete.\(target.id)")
        }
    }
}

struct ContentDeletionPreparation: ViewModifier {
    let target: ContentActionTarget
    let authorID: Int64
    @Environment(\.contentActions) private var store
    func body(content: Content) -> some View {
        content.task(id: "\(target.id):\(authorID):\(String(describing: store?.session))") {
            await store?.prepareDeletion(target, authorID: authorID)
        }
    }
}

struct ContentActionFeedbackHost: ViewModifier {
    @Bindable var store: ContentActionStore
    let openLogin: () -> Void
    func body(content: Content) -> some View {
        content
            .alert(store.pendingDeletion?.target.deletionTitle ?? "删除", isPresented: Binding(
                get: { store.pendingDeletion != nil }, set: { if !$0 { store.pendingDeletion = nil } }
            ), presenting: store.pendingDeletion) { confirmation in
                Button("取消", role: .cancel) { store.pendingDeletion = nil }
                Button("删除", role: .destructive) { Task { await store.confirmDeletion(confirmation) } }
                    .accessibilityIdentifier("content.delete.confirm")
            } message: { confirmation in
                Text(confirmation.target.deletionMessage)
            }
            .alert(store.feedback ?? "操作结果", isPresented: Binding(
                get: { store.feedback != nil }, set: { if !$0 { store.feedback = nil } }
            )) { Button("好", role: .cancel) { store.feedback = nil } }
            .onChange(of: store.needsLogin) { _, value in
                if value { store.needsLogin = false; openLogin() }
            }
    }
}
