import Observation

@MainActor
@Observable
final class BookmarkStore {
    enum State: Equatable { case idle, loading, loaded, failed }
    private(set) var state: State = .idle
    private(set) var isBusy = false
    var feedback: String?
    private var allEntries: [ThreadBookmark] = []
    private var visibleCount = 40
    var entries: [ThreadBookmark] { Array(allEntries.prefix(visibleCount)) }
    var hasMore: Bool { visibleCount < allEntries.count }
    @ObservationIgnored private let repository: any BookmarkRepositoryProtocol
    @ObservationIgnored private let context: @MainActor () -> ContentCacheContext
    @ObservationIgnored private let account: @MainActor () async throws -> String
    @ObservationIgnored private var loadedContext: ContentCacheContext?
    @ObservationIgnored private var accountID: String?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    init(repository: any BookmarkRepositoryProtocol, context: @escaping @MainActor () -> ContentCacheContext,
         account: @escaping @MainActor () async throws -> String) {
        self.repository = repository; self.context = context; self.account = account
    }

    func contains(_ threadID: Int64) -> Bool { allEntries.contains { $0.id == threadID } }
    func loadMore() { visibleCount += 40 }

    func sessionChanged() {
        guard loadedContext != context() else { return }
        generation &+= 1
        task?.cancel(); task = nil
        loadedContext = context()
        accountID = nil
        allEntries = []; visibleCount = 40
        feedback = nil; isBusy = false; state = .idle
    }

    func load() async {
        sessionChanged()
        guard state != .loaded else { return }
        await perform(nil)
    }

    func refresh() async { await perform(nil) }
    func save(_ entry: ThreadBookmark) async { await perform(.save(entry)) }
    func remove(threadID: Int64) async { await perform(.remove(threadID)) }

    private enum Mutation {
        case save(ThreadBookmark), remove(Int64)
        var isRemoval: Bool { if case .remove = self { return true }; return false }
    }

    private func perform(_ mutation: Mutation?) async {
        sessionChanged()
        guard task == nil else { return }
        generation &+= 1
        let token = generation
        let scope = context()
        isBusy = true; feedback = nil
        if allEntries.isEmpty { state = .loading }
        let operation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if token == generation { isBusy = false; task = nil } }
            do {
                let accountID = try await resolvedAccount()
                try Task.checkCancellation()
                guard token == generation, context() == scope else { return }
                self.accountID = accountID
                try await apply(mutation, accountID: accountID)
                let values = try await repository.entries(account: accountID)
                try Task.checkCancellation()
                guard token == generation, context() == scope else { return }
                allEntries = values
                state = .loaded
                if let mutation { feedback = mutation.isRemoval ? "已移除本机书签" : "已保存到本机书签" }
            } catch is CancellationError {
                if token == generation { state = allEntries.isEmpty ? .idle : .loaded }
            } catch {
                guard token == generation, context() == scope else { return }
                state = allEntries.isEmpty ? .failed : .loaded
                if mutation != nil || !allEntries.isEmpty { feedback = Self.failureMessage(error) }
            }
        }
        task = operation
        await withTaskCancellationHandler { await operation.value } onCancel: { operation.cancel() }
    }
    private func resolvedAccount() async throws -> String {
        if let accountID { return accountID }
        return try await account()
    }

    private func apply(_ mutation: Mutation?, accountID: String) async throws {
        switch mutation {
        case let .save(entry): try await repository.save(entry, account: accountID)
        case let .remove(id): try await repository.remove(threadID: id, account: accountID)
        case nil: break
        }
    }

    private static func failureMessage(_ error: any Error) -> String {
        (error as? BookmarkFailure) == .accountUnavailable
            ? "请登录并加载账户资料后重试" : "本机书签操作失败，请重试"
    }

}
