import Foundation
import Observation

@MainActor @Observable
final class ContentActionStore {
    struct Like: Equatable { let count: Int64?; let selected: Bool }
    private(set) var likes: [ContentActionTarget: Like] = [:]
    private(set) var permissions: [ContentActionTarget: ContentActionInspection] = [:]
    private(set) var busy = Set<ContentActionTarget>()
    private(set) var uncertain = Set<ContentActionTarget>()
    var pendingDeletion: ContentActionInspection?
    var feedback: String?
    var needsLogin = false
    @ObservationIgnored var didRemove: (@MainActor (ContentActionTarget?) async -> Void)?
    @ObservationIgnored private let repository: any ContentActionRepository
    @ObservationIgnored private let ledger: ContentRemovalRepository
    @ObservationIgnored private let context: @MainActor () -> ContentCacheContext
    @ObservationIgnored private let account: @MainActor () async throws -> Int64
    @ObservationIgnored private let visibility: ContentRemovalVisibility
    @ObservationIgnored private var scope: ContentCacheContext?
    private struct PreparationKey: Hashable { let target: ContentActionTarget; let authorID: Int64 }
    @ObservationIgnored private var preparations: [PreparationKey: (id: UInt64, task: Task<Void, Never>)] = [:]
    @ObservationIgnored private var preparedNonOwners = Set<PreparationKey>()
    @ObservationIgnored private var preparationSequence: UInt64 = 0
    @ObservationIgnored private var tasks: [ContentActionTarget: Task<Void, Never>] = [:]

    init(repository: any ContentActionRepository, ledger: ContentRemovalRepository,
         visibility: ContentRemovalVisibility = .shared,
         context: @escaping @MainActor () -> ContentCacheContext,
         account: @escaping @MainActor () async throws -> Int64) {
        self.repository = repository; self.ledger = ledger; self.visibility = visibility
        self.context = context; self.account = account
    }
    var session: ContentCacheContext { context() }
    func activate() async {
        do { visibility.update(try await ledger.load()); await didRemove?(nil) } catch { feedback = "无法读取已删除内容记录，删除操作暂不可用。" }
        sessionChanged()
    }
    func sessionChanged() {
        guard scope != context() else { return }
        tasks.values.forEach { $0.cancel() }; tasks = [:]; busy = []
        preparations.values.forEach { $0.task.cancel() }; preparations = [:]; preparedNonOwners = []
        likes = [:]; permissions = [:]; uncertain = []; pendingDeletion = nil; feedback = nil; needsLogin = false
        scope = context()
    }
    /// Cached author UID only narrows candidates; fresh native inspection grants permission.
    func prepareDeletion(_ target: ContentActionTarget, authorID: Int64) async {
        sessionChanged()
        let key = PreparationKey(target: target, authorID: authorID)
        guard !Task.isCancelled, target.isValid, authorID > 0, permissions[target] == nil, !busy.contains(target),
              !visibility.targets.contains(target), !preparedNonOwners.contains(key) else { return }
        if let existing = preparations[key] {
            #if UITESTING
            ScrollWorkMetrics.count("preparation.join")
            #endif
            await existing.task.value
            return
        }
        let expected = context()
        preparationSequence &+= 1
        let sequence = preparationSequence
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if preparations[key]?.id == sequence { preparations[key] = nil } }
            do {
                let accountID = try await account()
                try Task.checkCancellation()
                guard scope == expected, context() == expected else { return }
                guard accountID == authorID else {
                    if preparedNonOwners.count >= 512 { preparedNonOwners.removeAll(keepingCapacity: true) }
                    preparedNonOwners.insert(key)
                    return
                }
                let info = try await repository.inspect(target)
                try validateAccount(info)
                guard scope == expected else { return }
                if info.canDelete, !busy.contains(target), !visibility.targets.contains(target) { permissions[target] = info }
            } catch {
                // Read-only candidate preparation is silent; cancellation/errors remain retryable.
                return
            }
        }
        preparations[key] = (sequence, task)
        // Store-owned read-only preparation survives one row disappearing while another
        // consumer still needs it. Session changes cancel it; writes keep their own busy lifetime.
        await task.value
    }

    func askToDelete(_ target: ContentActionTarget) {
        sessionChanged()
        guard !busy.contains(target), !uncertain.contains(target), let info = permissions[target], info.canDelete else { return }
        pendingDeletion = info
    }
    func toggleLike(_ target: ContentActionTarget) async {
        sessionChanged()
        await run(target) {
            let info = try await self.repository.inspect(target)
            try self.validateAccount(info)
            guard let selected = info.liked else { throw ContentActionFailure.unavailable }
            if self.uncertain.remove(target) != nil {
                self.likes[target] = .init(count: info.likeCount, selected: selected)
                self.feedback = "已重新读取点赞状态。"
                return
            }
            try await self.repository.like(info, selected: !selected)
            try self.validateAccount(info)
            self.likes[target] = .init(count: info.likeCount.map { max(0, $0 + (selected ? -1 : 1)) }, selected: !selected)
        }
    }
    func confirmDeletion(_ confirmation: ContentActionInspection) async {
        sessionChanged()
        let target = confirmation.target
        guard permissions[target] == confirmation, !uncertain.contains(target) else { return }
        pendingDeletion = nil
        await run(target) {
            let info = try await self.repository.inspect(target)
            try self.validateAccount(info)
            guard info.canDelete, info.accountID == confirmation.accountID else { throw ContentActionFailure.unavailable }
            try await self.ledger.prepare()
            try self.validateAccount(info)
            try await self.repository.delete(info)
            // Confirmed remote deletion is public and remains removed after logout.
            let entries: [ConfirmedContentRemoval]
            do { entries = try await self.ledger.record(target) } catch { throw ContentActionFailure.outcomeUnknown }
            self.visibility.update(entries)
            self.permissions[target] = nil
            await self.didRemove?(target)
        }
    }
    private func validateAccount(_ info: ContentActionInspection) throws {
        try Task.checkCancellation()
        guard scope == context(), info.accountID > 0 else { throw CancellationError() }
    }
    private func run(_ target: ContentActionTarget, silent: Bool = false,
                     operation: @escaping @MainActor () async throws -> Void) async {
        guard target.isValid, !busy.contains(target) else { return }
        let expected = context()
        busy.insert(target)
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if scope == expected { busy.remove(target); tasks[target] = nil } }
            do { try await operation() } catch is CancellationError {
                // Session/row cancellation does not imply remote failure.
            } catch {
                guard scope == expected, !silent else { return }
                if error as? ContentActionFailure == .loginRequired { needsLogin = true; return }
                if error as? ContentActionFailure == .outcomeUnknown { uncertain.insert(target) }
                feedback = Self.message(error)
            }
        }
        tasks[target] = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }
    private static func message(_ error: any Error) -> String {
        switch error as? ContentActionFailure {
        case .outcomeUnknown: "暂未确认操作结果。点赞可再次点按以读取实际状态；删除请返回查看，勿重复提交。"
        case .rejected: "操作未成功，请稍后重试。"
        case .storageUnavailable: "无法保存删除记录，尚未提交删除。"
        default: "暂时无法操作此内容，请稍后重试。"
        }
    }
}
