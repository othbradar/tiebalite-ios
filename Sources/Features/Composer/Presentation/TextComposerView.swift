import PhotosUI
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
    @State private var focused = false
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var showsEmoticons = false
    @State private var importGeneration = 0
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var photoPreparation = ComposerPhotoPreparation()

    init(target: TextComposeTarget, service: TextComposerService, onSuccess: @escaping (TextWriteReceipt) -> Void) {
        self.service = service
        context = service.currentContext()
        self.onSuccess = onSuccess
        let store = TextComposerStore(target: target, repository: service.repository,
                                      context: context, currentContext: service.currentContext, uploader: service.uploader)
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
                ComposerTextEditor(text: $store.draft.content, selection: $selection, focused: $focused,
                                   enabled: !store.isSending, showsEmoticons: showsEmoticons, insertEmoticon: insertEmoticon)
                if !store.draft.photos.isEmpty {
                    ComposerPhotoGrid(photos: store.draft.photos, loader: service.imageLoader, remove: store.removePhoto)
                }
                mediaToolbar
                status
            }
            .background(SemanticColor.background)
            .disabled(store.isSending)
            .navigationTitle(store.target.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
#if UITESTING
                ToolbarItem(placement: .topBarLeading) { mockUploadControl }
#endif
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.uploadProgress == nil ? "取消" : "停止上传") {
                        if store.isSending { store.cancelPending() } else { dismiss() }
                    }.disabled(store.isSending && store.uploadProgress == nil)
                        .accessibilityIdentifier("composer.cancel")
                }
                .tiebaFlatToolbarItem()
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.isSending ? "发送中" : (store.mediaFailure == nil ? "发送" : "重试")) { Task { await store.send() } }
                        .disabled(!store.canSend).accessibilityIdentifier("composer.send")
                }
                .tiebaFlatToolbarItem()
            }
            .interactiveDismissDisabled(store.isSending)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("composer.screen")
            .task(id: pickedPhotos) { await importPhotos() }
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

    private var mediaToolbar: some View {
        HStack(spacing: 20) {
            PhotosPicker(selection: $pickedPhotos, maxSelectionCount: max(1, ComposerPhoto.limit - store.draft.photos.count),
                         selectionBehavior: .ordered, matching: .images) {
                Label("图片", systemImage: "photo").frame(minHeight: 44)
            }
            .disabled(store.draft.photos.count >= ComposerPhoto.limit || store.isImporting)
            .accessibilityIdentifier("composer.pick-photos")
            Button {
                showsEmoticons.toggle()
                focused = true
            } label: {
                Label(showsEmoticons ? "键盘" : "表情", systemImage: showsEmoticons ? "keyboard" : "face.smiling")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("composer.toggle-emoticons")
            Spacer()
        }
        .font(Typography.font(.subheadline)).buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func insertEmoticon(_ emoticon: TiebaEmoticon) {
        let result = ComposerInsertion.insert("#(\(emoticon.name))", into: store.draft.content, selection: selection)
        selection = result.selection
        store.draft.content = result.text
    }

    private func importPhotos() async {
        guard !pickedPhotos.isEmpty else { return }
        importGeneration += 1
        let generation = importGeneration
        let selection = pickedPhotos
        store.isImporting = true
        store.mediaFailure = nil
        defer { if generation == importGeneration { store.isImporting = false } }
        do {
            for item in selection {
                guard store.draft.photos.count < ComposerPhoto.limit else { break }
                guard let imported = try await item.loadTransferable(type: ComposerPickedPhoto.self) else {
                    throw ImageUploadFailure.invalidImage
                }
                let photo = try await photoPreparation.prepare(file: imported.file)
                try Task.checkCancellation()
                store.appendPhoto(photo)
            }
            pickedPhotos = []
        } catch is CancellationError {
            return
        } catch let error as ImageUploadFailure {
            store.mediaFailure = error.message
        } catch {
            store.mediaFailure = ImageUploadFailure.invalidImage.message
        }
    }

#if UITESTING
    private var mockUploadControl: some View {
        Group {
            if let uploader = service.uploader as? FixtureComposerImageUploader, store.uploadProgress != nil {
                Button("完成模拟上传") { Task { await uploader.finishSample() } }
                    .accessibilityIdentifier("r10.finish-upload")
            }
        }
    }
#endif

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let progress = store.uploadProgress {
                ProgressView("上传图片 \(Int(progress * 100))%", value: progress).accessibilityIdentifier("composer.uploading")
            } else if store.isSending { ProgressView("正在发送…").accessibilityIdentifier("composer.sending") }
            if store.isImporting { ProgressView("正在处理图片…") }
            if let failure = store.mediaFailure {
                Text(failure).foregroundStyle(SemanticColor.secondaryText).accessibilityIdentifier("composer.media-failure")
            }
            if let failure = store.failure {
                Text(failure.message).foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityIdentifier("composer.failure")
            } else if !store.target.isValid {
                Text(TextWriteFailure.invalidTarget.message).accessibilityIdentifier("composer.invalid-target")
            }
            Text("草稿保留在本次会话 · \(store.draft.content.count) 字 · \(store.draft.photos.count)/9 图")
                .foregroundStyle(SemanticColor.secondaryText).accessibilityIdentifier("composer.draft-status")
        }
        .font(Typography.font(.caption)).padding(16)
    }
}
