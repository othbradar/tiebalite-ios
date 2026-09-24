import Observation

@MainActor
@Observable
final class TextComposerStore {
    let target: TextComposeTarget
    var draft = TextDraft()
    private(set) var isSending = false
    private(set) var failure: TextWriteFailure?
    private(set) var receipt: TextWriteReceipt?
    private let repository: any TextWriteRepository
    private let context: AuthContext
    private let currentContext: () -> AuthContext
    @ObservationIgnored private var operation: Task<TextWriteReceipt, Error>?

    init(target: TextComposeTarget, repository: any TextWriteRepository,
         context: AuthContext, currentContext: @escaping () -> AuthContext) {
        self.target = target
        self.repository = repository
        self.context = context
        self.currentContext = currentContext
    }

    var canSend: Bool { !isSending && receipt == nil && target.isValid && draft.isSendable }

    func send() async {
        guard !isSending, receipt == nil else { return }
        guard target.isValid else { failure = .invalidTarget; return }
        guard draft.isSendable else { failure = .invalidDraft; return }
        guard context == currentContext(), case .active = context else { failure = .authentication; return }
        failure = nil
        isSending = true
        let request = TextWriteRequest(target: target, draft: draft)
        let repository = repository
        let context = context
        let task = Task { try await repository.send(request, context: context) }
        operation = task
        defer { operation = nil; isSending = false }
        do {
            let result = try await task.value
            guard !task.isCancelled, context == currentContext() else { failure = .resultUnknown; return }
            guard result.threadID > 0, result.postID > 0,
                  target.kind == .thread || result.threadID == target.threadID else {
                failure = .resultUnknown
                return
            }
            receipt = result
        } catch is CancellationError {
            failure = .resultUnknown
        } catch let error as TextWriteFailure {
            failure = error
        } catch {
            failure = .resultUnknown
        }
    }

    func cancelPending() { operation?.cancel() }
}

@MainActor
final class TextComposerDrafts {
    private var context: AuthContext?
    private var drafts: [String: TextDraft] = [:]

    func load(target: TextComposeTarget, context: AuthContext) -> TextDraft {
        synchronize(context)
        return drafts[target.id] ?? TextDraft()
    }

    func save(_ draft: TextDraft, target: TextComposeTarget, context: AuthContext) {
        synchronize(context)
        drafts[target.id] = draft
    }

    func clear(target: TextComposeTarget, context: AuthContext) {
        synchronize(context)
        drafts[target.id] = nil
    }

    private func synchronize(_ context: AuthContext) {
        guard self.context != context else { return }
        drafts.removeAll()
        self.context = context
    }
}

@MainActor
@Observable
final class TextComposerService {
    let repository: any TextWriteRepository
    let currentContext: () -> AuthContext
    let drafts = TextComposerDrafts()
    var presentation: TextComposerSession?
    var completedReceipt: TextWriteReceipt?
    @ObservationIgnored private var completion: ((TextWriteReceipt) async -> Void)?
    @ObservationIgnored private var completionTask: Task<Void, Never>?

    init(repository: any TextWriteRepository, currentContext: @escaping () -> AuthContext) {
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
