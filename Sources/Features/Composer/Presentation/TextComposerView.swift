import SwiftUI

private struct TextComposerServiceKey: EnvironmentKey {
    static let defaultValue: TextComposerService? = nil
}

extension EnvironmentValues {
    var textComposer: TextComposerService? {
        get { self[TextComposerServiceKey.self] }
        set { self[TextComposerServiceKey.self] = newValue }
    }
}

extension View {
    func textComposer(target: Binding<TextComposeTarget?>, onSuccess: @escaping (TextWriteReceipt) async -> Void) -> some View {
        modifier(TextComposerPresentation(target: target, onSuccess: onSuccess))
    }
}

private struct TextComposerPresentation: ViewModifier {
    @Environment(\.textComposer) private var service
    @Binding var target: TextComposeTarget?
    let onSuccess: (TextWriteReceipt) async -> Void

    func body(content: Content) -> some View {
        content.onChange(of: target) { _, value in
            guard let value else { return }
            service?.present(value, onSuccess: onSuccess)
            target = nil
        }
    }
}

/// Hosted outside the compact/regular projection so rotation preserves the active editor.
struct TextComposerHost: ViewModifier {
    @Bindable var service: TextComposerService

    func body(content: Content) -> some View {
        content.sheet(item: $service.presentation, onDismiss: service.didDismiss, content: { session in
            TextComposerView(target: session.target, service: session.service) { service.completedReceipt = $0 }
        })
    }
}

@MainActor
struct TextComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: TextComposerStore
    private let service: TextComposerService
    private let context: AuthContext
    private let onSuccess: (TextWriteReceipt) -> Void
    @FocusState private var focused: Bool

    init(target: TextComposeTarget, service: TextComposerService, onSuccess: @escaping (TextWriteReceipt) -> Void) {
        self.service = service
        context = service.currentContext()
        self.onSuccess = onSuccess
        let store = TextComposerStore(target: target, repository: service.repository,
                                      context: context, currentContext: service.currentContext)
        store.draft = service.drafts.load(target: target, context: context)
        _store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                targetHeader
                TiebaFlatDivider(inset: 0)
                if store.target.kind == .thread {
                    TextField("标题（选填，最多 31 字）", text: $store.draft.title)
                        .font(Typography.font(.headline)).padding(16)
                        .accessibilityIdentifier("composer.title")
                    TiebaFlatDivider(inset: 0)
                }
                TextEditor(text: $store.draft.content)
                    .font(Typography.font(.body)).scrollContentBackground(.hidden)
                    .padding(.horizontal, 12).padding(.top, 8)
                    .focused($focused).accessibilityLabel("正文")
                    .accessibilityIdentifier("composer.body")
                status
            }
            .background(SemanticColor.background)
            .disabled(store.isSending)
            .navigationTitle(store.target.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(store.isSending)
                        .accessibilityIdentifier("composer.cancel")
                }
                .tiebaFlatToolbarItem()
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.isSending ? "发送中" : "发送") { Task { await store.send() } }
                        .disabled(!store.canSend).accessibilityIdentifier("composer.send")
                }
                .tiebaFlatToolbarItem()
            }
            .interactiveDismissDisabled(store.isSending)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("composer.screen")
            .onChange(of: store.draft) { _, draft in service.drafts.save(draft, target: store.target, context: context) }
            .onChange(of: store.receipt) { _, receipt in
                guard let receipt else { return }
                service.drafts.clear(target: store.target, context: context)
                onSuccess(receipt)
                dismiss()
            }
            .onDisappear {
                store.cancelPending()
                if store.receipt == nil { service.drafts.save(store.draft, target: store.target, context: context) }
            }
        }
        .presentationDetents([.large])
    }

    private var targetHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.target.forumName + (store.target.forumName.hasSuffix("吧") ? "" : "吧"))
                .font(Typography.font(.subheadline)).fontWeight(.semibold)
            if let recipient = store.target.recipient {
                Text("回复 \(recipient.displayName)").font(Typography.font(.subheadline))
                    .accessibilityIdentifier("composer.recipient")
            }
            if !store.target.quote.isEmpty {
                Text(store.target.quote).font(Typography.font(.caption)).lineLimit(2)
                    .foregroundStyle(SemanticColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8).background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 4))
                    .accessibilityIdentifier("composer.quote")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composer.target")
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.isSending { ProgressView("正在发送…").accessibilityIdentifier("composer.sending") }
            if let failure = store.failure {
                Text(failure.message).foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityIdentifier("composer.failure")
            } else if !store.target.isValid {
                Text(TextWriteFailure.invalidTarget.message).accessibilityIdentifier("composer.invalid-target")
            }
            Text("草稿保留在本次会话 · \(store.draft.content.count) 字")
                .foregroundStyle(SemanticColor.secondaryText).accessibilityIdentifier("composer.draft-status")
        }
        .font(Typography.font(.caption)).padding(16)
    }
}
