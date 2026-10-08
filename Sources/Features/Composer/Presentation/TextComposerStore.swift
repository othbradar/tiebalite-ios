import Foundation
import Observation

@MainActor
@Observable
final class TextComposerStore {
    let target: TextComposeTarget
    var draft = TextDraft()
    private(set) var isSending = false
    private(set) var failure: TextWriteFailure?
    private(set) var receipt: TextWriteReceipt?
    var isImporting = false
    var mediaFailure: String?
    private(set) var uploadProgress: Double?
    private let uploader: any ComposerImageUploading
    private var writeStarted = false
    private let repository: any TextWriteRepository
    private let context: AuthContext
    private let currentContext: () -> AuthContext
    @ObservationIgnored private var operation: Task<TextWriteReceipt, Error>?

    init(target: TextComposeTarget, repository: any TextWriteRepository,
         context: AuthContext, currentContext: @escaping () -> AuthContext,
         uploader: any ComposerImageUploading = UnavailableComposerUploader()) {
        self.uploader = uploader
        self.target = target
        self.repository = repository
        self.context = context
        self.currentContext = currentContext
    }

    var canSend: Bool { !isSending && !isImporting && receipt == nil && target.isValid && draft.isSendable }

    func send() async {
        guard !isSending, !isImporting, receipt == nil else { return }
        guard target.isValid else { failure = .invalidTarget; return }
        guard draft.isSendable else { failure = .invalidDraft; return }
        guard context == currentContext(), case .active = context else { failure = .authentication; return }
        failure = nil
        mediaFailure = nil
        writeStarted = false
        isSending = true
        let request = TextWriteRequest(target: target, draft: draft)
        let repository = repository
        let context = context
        let task = Task {
            try (repository as? any TextWriteRequestValidating)?.validateForSending(request)
            let prepared = try await self.uploadPhotos(request)
            try Task.checkCancellation()
            guard context == self.currentContext() else { throw TextWriteFailure.authentication }
            self.uploadProgress = nil
            self.writeStarted = true
            return try await repository.send(prepared, context: context)
        }
        operation = task
        defer { operation = nil; isSending = false; uploadProgress = nil }
        do {
            let result = try await task.value
            guard !task.isCancelled, context == currentContext() else { failure = .resultUnknown; return }
            guard result.threadID > 0, result.postID > 0,
                  target.kind == .thread || result.threadID == target.threadID else {
                failure = .resultUnknown
                return
            }
            receipt = result
        } catch { handleFailure(error) }
    }

    private func handleFailure(_ error: any Error) {
        switch error {
        case is CancellationError:
            if writeStarted { failure = .resultUnknown }
        case let error as ImageUploadFailure: mediaFailure = error.message
        case is RequestAuthorizationError: failure = .authentication
        case let error as TextWriteFailure: failure = error
        default:
            if writeStarted { failure = .resultUnknown } else { mediaFailure = ImageUploadFailure.unavailable.message }
        }
    }

    private func uploadPhotos(_ request: TextWriteRequest) async throws -> TextWriteRequest {
        var tokens: [String] = []
        for (index, photo) in request.draft.photos.enumerated() {
            try Task.checkCancellation()
            guard context == currentContext() else { throw TextWriteFailure.authentication }
            let uploaded: UploadedComposerPhoto
            if let cached = photo.uploaded { uploaded = cached } else {
                uploadProgress = Double(index) / Double(request.draft.photos.count)
                uploaded = try await uploader.upload(photo, forumName: target.forumName, context: context) { [weak self] value in
                    await self?.recordProgress(value, index: index, total: request.draft.photos.count)
                }
                try Task.checkCancellation()
                guard context == currentContext() else { throw TextWriteFailure.authentication }
                if let location = draft.photos.firstIndex(where: { $0.id == photo.id }) { draft.photos[location].uploaded = uploaded }
            }
            tokens.append(uploaded.token)
        }
        var output = request.draft
        if !tokens.isEmpty { output.content += "\n" + tokens.joined(separator: "\n") }
        output.photos = []
        return TextWriteRequest(target: request.target, draft: output)
    }

    private func recordProgress(_ value: Double, index: Int, total: Int) {
        guard isSending, context == currentContext(), !Task.isCancelled else { return }
        uploadProgress = (Double(index) + min(1, max(0, value))) / Double(total)
    }

    func appendPhoto(_ photo: ComposerPhoto) {
        guard !isSending, draft.photos.count < ComposerPhoto.limit,
              !draft.photos.contains(where: { $0.id == photo.id }) else { return }
        draft.photos.append(photo)
    }

    func removePhoto(id: String) {
        guard !isSending else { return }
        draft.photos.removeAll { $0.id == id }
    }

    func cancelPending() { operation?.cancel() }
}

@MainActor
@Observable
final class TextComposerService {
    let repository: any TextWriteRepository
    let uploader: any ComposerImageUploading
    let imageLoader: any ImageLoading
    let currentContext: () -> AuthContext
    let drafts: TextComposerDrafts
    var presentation: TextComposerSession?
    var completedReceipt: TextWriteReceipt?
    @ObservationIgnored private var completion: ((TextWriteReceipt) async -> Void)?
    @ObservationIgnored private var completionTask: Task<Void, Never>?

    init(repository: any TextWriteRepository, uploader: any ComposerImageUploading = UnavailableComposerUploader(),
         imageLoader: any ImageLoading = DisabledImageLoader(), drafts: TextComposerDrafts = TextComposerDrafts(),
         currentContext: @escaping () -> AuthContext) {
        self.drafts = drafts
        self.uploader = uploader
        self.imageLoader = imageLoader
        self.repository = repository
        self.currentContext = currentContext
    }

    func present(_ target: TextComposeTarget, using service: TextComposerService? = nil,
                 onSuccess: @escaping (TextWriteReceipt) async -> Void) {
        guard presentation == nil, completion == nil else { return }
        completion = onSuccess
        completedReceipt = nil
        presentation = TextComposerSession(target: target, service: service ?? self)
    }

    func didDismiss() {
        let receipt = completedReceipt
        let action = completion
        presentation = nil
        completedReceipt = nil
        completion = nil
        guard let receipt, let action else { return }
        completionTask?.cancel()
        completionTask = Task { await action(receipt); completionTask = nil }
    }

}

struct TextComposerSession: Identifiable {
    let target: TextComposeTarget
    let service: TextComposerService
    var id: String { target.id }
}
