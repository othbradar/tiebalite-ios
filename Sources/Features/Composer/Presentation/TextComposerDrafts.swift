import Foundation
import Observation

@MainActor
@Observable
final class TextComposerDrafts {
    private var failures: [ComposerDraftStorage.Key: String] = [:]
    var persistenceFailure: String? { failures.values.first }
    func failure(for key: ComposerDraftStorage.Key?) -> String? { key.flatMap { failures[$0] } }
    private(set) var restorationFailed = false
    private(set) var isSaving = false
    @ObservationIgnored private let storage: ComposerDraftStorage?
    @ObservationIgnored private let namespace: () -> String?
    @ObservationIgnored private var drafts: [ComposerDraftStorage.Key: TextDraft] = [:]
    @ObservationIgnored private var dirty: Set<ComposerDraftStorage.Key> = []
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var flushGeneration: UInt64 = 0
    @ObservationIgnored private var knownNamespace: String?

    init(storage: ComposerDraftStorage? = nil, namespace: @escaping () -> String? = { "fixture" }) {
        self.storage = storage
        self.namespace = namespace
        knownNamespace = namespace()
    }

    func key(target: TextComposeTarget, context: AuthContext) -> ComposerDraftStorage.Key? {
        guard case .active = context, let namespace = namespace() else { return nil }
        return .init(namespace: namespace, target: target.id)
    }

    func load(target: TextComposeTarget, context: AuthContext) -> TextDraft {
        guard let key = key(target: target, context: context) else { return TextDraft() }
        return drafts[key] ?? TextDraft()
    }

    func restore(target: TextComposeTarget, context: AuthContext) async -> TextDraft {
        await restore(key: key(target: target, context: context))
    }

    func restore(key: ComposerDraftStorage.Key?) async -> TextDraft {
        guard let key, key.namespace == namespace() else { return TextDraft() }
        if let draft = drafts[key] { restorationFailed = false; return draft }
        await pending?.value
        do {
            let draft = try await storage?.load(key) ?? TextDraft()
            guard key.namespace == namespace() else { return TextDraft() }
            failures[key] = nil
            restorationFailed = false
            // An edit or successful send while I/O was in flight takes precedence.
            if drafts[key] == nil { drafts[key] = draft }
            return drafts[key] ?? TextDraft()
        } catch {
            guard key.namespace == namespace() else { return TextDraft() }
            restorationFailed = true
            failures[key] = "草稿读取失败，请重新打开编辑器重试。"
            return TextDraft()
        }
    }

    func save(_ draft: TextDraft, target: TextComposeTarget, context: AuthContext) {
        guard let key = key(target: target, context: context) else { return }
        save(draft, key: key)
    }

    func save(_ draft: TextDraft, key: ComposerDraftStorage.Key) {
        guard key.namespace == namespace() else { return }
        drafts[key] = draft
        guard storage != nil else { return }
        dirty.insert(key)
        isSaving = true
        debounce?.cancel()
        // Business debounce for editing, never a layout or request-timing workaround.
        debounce = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await self?.flush()
        }
    }

    func flush() async {
        debounce?.cancel()
        debounce = nil
        flushGeneration &+= 1
        let generation = flushGeneration
        let snapshots = dirty.compactMap { key in drafts[key].map { (key, $0) } }
        dirty.removeAll()
        let previous = pending
        let storage = storage
        let operation = Task { [weak self] in
            await previous?.value
            for (key, draft) in snapshots {
                do {
                    try await storage?.save(draft, key: key)
                    self?.failures[key] = nil
                } catch {
                    self?.failures[key] = "草稿未保存到磁盘（空间不足或附件不可用），当前内容仍保留，请重试。"
                }
            }
        }
        pending = operation
        await operation.value
        if generation == flushGeneration { isSaving = !dirty.isEmpty }
    }

    func clear(target: TextComposeTarget, context: AuthContext) {
        guard let key = key(target: target, context: context) else { return }
        clear(key: key)
    }

    func clear(key: ComposerDraftStorage.Key) {
        guard key.namespace == namespace() else { return }
        drafts[key] = TextDraft()
        dirty.remove(key)
        let previous = pending
        pending = Task { [weak self, storage] in
            await previous?.value
            do { try await storage?.clear(key); self?.failures[key] = nil } catch { self?.failures[key] = "已发送，草稿清理失败。" }
        }
    }

    /// Called on the existing auth lifecycle. Logout, expiry or account replacement removes the old account's private drafts.
    func accountDidChange() {
        let current = namespace()
        defer { knownNamespace = current }
        guard let old = knownNamespace, old != current else { return }
        drafts = drafts.filter { $0.key.namespace != old }
        let oldKeys = Set(failures.keys.filter { $0.namespace == old })
        dirty = dirty.filter { $0.namespace != old }
        let previous = pending
        pending = Task { [weak self, storage] in
            await previous?.value
            do {
                try await storage?.revoke(old)
                for key in oldKeys { self?.failures[key] = nil }
            } catch {
                self?.failures[.init(namespace: old, target: "logout")] = "退出后草稿清理失败。"
            }
        }
    }
}
