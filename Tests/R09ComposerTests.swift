import Testing
@testable import TiebaLite

@MainActor
struct R09ComposerTests {
    private let context = AuthContext.active(.init(sessionID: .init(rawValue: 9), generation: 1))
    private let target = TextComposeTarget(kind: .thread, forumID: 42, forumName: "测试吧")

    @Test func validationAndFailurePreserveTargetDraft() async {
        let repository = R09ControlledWriter()
        let store = TextComposerStore(target: target, repository: repository, context: context, currentContext: { self.context })
        #expect(!store.canSend)
        store.draft = .init(title: "测试标题", content: "测试正文")
        let task = Task { await store.send() }
        await repository.waitForCall()
        #expect(store.isSending)
        await store.send()
        #expect(await repository.count == 1)
        await repository.finish(.failure(TextWriteFailure.network))
        await task.value
        #expect(store.failure == .network)
        #expect(store.draft.content == "测试正文")
        #expect(store.receipt == nil)
    }

    @Test func successRequiresServerIdentityAndSendsOnce() async {
        let repository = R09ControlledWriter()
        let store = TextComposerStore(target: target, repository: repository, context: context, currentContext: { self.context })
        store.draft.content = "成功样本"
        let task = Task { await store.send() }
        await repository.waitForCall()
        await repository.finish(.success(.init(threadID: 800, postID: 801)))
        await task.value
        #expect(store.receipt == .init(threadID: 800, postID: 801))
        await store.send()
        #expect(await repository.count == 1)
    }

    @Test func sessionChangeBeforeAndDuringSendDoesNotPublishStaleSuccess() async {
        let repository = R09ControlledWriter()
        var current = context
        let store = TextComposerStore(target: target, repository: repository, context: context, currentContext: { current })
        store.draft.content = "租约样本"
        current = .anonymous
        await store.send()
        #expect(await repository.hasNoCalls)
        #expect(store.failure == .authentication)
        current = context
        let task = Task { await store.send() }
        await repository.waitForCall()
        current = .anonymous
        await repository.finish(.success(.init(threadID: 800, postID: 801)))
        await task.value
        #expect(store.receipt == nil)
        #expect(store.failure == .resultUnknown)
    }

    @Test func cancelledOrInvalidResponseCannotClearDraft() async {
        let repository = R09ControlledWriter()
        let store = TextComposerStore(target: target, repository: repository, context: context, currentContext: { self.context })
        store.draft.content = "取消后保留"
        let task = Task { await store.send() }
        await repository.waitForCall()
        store.cancelPending()
        await repository.finish(.success(.init(threadID: 800, postID: 801)))
        await task.value
        #expect(store.receipt == nil)
        #expect(store.failure == .resultUnknown)
        #expect(store.draft.content == "取消后保留")
        let second = Task { await store.send() }
        await repository.waitForCall()
        await repository.finish(.success(.init(threadID: 0, postID: 0)))
        await second.value
        #expect(store.receipt == nil)
        #expect(store.failure == .resultUnknown)
    }

    @Test func onePresentationOwnsTargetAndCompletesOnlyOnceAfterDismissal() async throws {
        let gate = HarnessContinuationGate<Void>()
        let service = TextComposerService(repository: R09ControlledWriter(), currentContext: { self.context })
        var completionCount = 0
        service.present(target) { receipt in
            #expect(receipt == .init(threadID: 800, postID: 801))
            completionCount += 1
            gate.succeed(())
        }
        let original = service.presentation
        service.present(.init(kind: .thread, forumID: 99, forumName: "另一目标")) { _ in Issue.record("Wrong destination") }
        #expect(service.presentation?.id == original?.id)
        service.completedReceipt = .init(threadID: 800, postID: 801)
        service.presentation = nil
        service.didDismiss()
        try await gate.wait()
        service.didDismiss()
        #expect(completionCount == 1)
        #expect(service.presentation == nil)
    }

    @Test func draftIsolationAndDismissal() {
        let drafts = TextComposerDrafts()
        let draft = TextDraft(title: "草稿", content: "保留文字")
        drafts.save(draft, target: target, context: context)
        #expect(drafts.load(target: target, context: context) == draft)
        var other = target
        other.threadID = 99
        #expect(drafts.load(target: other, context: context) == TextDraft())
        #expect(drafts.load(target: target, context: .anonymous) == TextDraft())
        #expect(drafts.load(target: target, context: context) == TextDraft())
    }
}

private actor R09ControlledWriter: TextWriteRepository {
    private(set) var count = 0
    var hasNoCalls: Bool { count == .zero }
    private var continuation: CheckedContinuation<TextWriteReceipt, Error>?
    private var observers: [CheckedContinuation<Void, Never>] = []
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        count += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            observers.forEach { $0.resume() }
            observers.removeAll()
        }
    }
    func waitForCall() async {
        if continuation != nil { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func finish(_ result: Result<TextWriteReceipt, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
