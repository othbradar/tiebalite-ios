import Observation

/// Shared cloud snapshot, isolated by session. Reopening, foregrounding or
/// pulling the list reads the server; local bookmarks are never bulk-uploaded.
@MainActor
@Observable
final class FavoriteStore {
    enum State: Equatable { case idle, loading, loaded, failed }
    private(set) var state: State = .idle
    private(set) var entries: [ThreadFavorite] = []
    private(set) var isBusy = false
    private(set) var refreshFailed = false
    var feedback: String?
    private var nextOffset: Int?
    private var pagingInvalidated = false
    var hasMore: Bool { nextOffset != nil }
    @ObservationIgnored private let repository: any FavoriteRepositoryProtocol
    @ObservationIgnored private let context: @MainActor () -> ContentCacheContext
    @ObservationIgnored private let account: @MainActor () async throws -> String
    @ObservationIgnored private var scope: ContentCacheContext?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    init(repository: any FavoriteRepositoryProtocol, context: @escaping @MainActor () -> ContentCacheContext,
         account: @escaping @MainActor () async throws -> String) {
        self.repository = repository; self.context = context; self.account = account
    }
    func contains(_ id: Int64) -> Bool { entries.contains { $0.id == id } }
    func sessionChanged() {
        guard scope != context() else { return }
        generation &+= 1; task?.cancel(); task = nil
        scope = context(); entries = []; nextOffset = nil; pagingInvalidated = false
        state = .idle; isBusy = false; feedback = nil; refreshFailed = false
    }
    func refresh() async { await perform(.list(0)) }
    func loadMore() async {
        if pagingInvalidated { await refresh() } else if let nextOffset { await perform(.list(nextOffset)) }
    }
    func save(_ entry: ThreadFavorite) async { await perform(.save(entry)) }
    func remove(_ id: Int64) async { await perform(.remove(id)) }

    private func perform(_ operation: NativeFavoriteRequest.Operation) async {
        sessionChanged()
        guard task == nil else { return }
        generation &+= 1
        let token = generation, expectedScope = context()
        isBusy = true; refreshFailed = false; feedback = nil
        if entries.isEmpty { state = .loading }
        let running = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if token == generation { task = nil; isBusy = false } }
            do {
                let accountID = try await account()
                try Task.checkCancellation()
                guard token == generation, context() == expectedScope else { return }
                let page = try await fetch(operation, accountID: accountID)
                try Task.checkCancellation()
                guard token == generation, context() == expectedScope else { return }
                apply(operation, page: page)
                state = .loaded
            } catch is CancellationError {
                if token == generation { state = entries.isEmpty ? .idle : .loaded }
            } catch {
                guard token == generation, context() == expectedScope else { return }
                state = entries.isEmpty ? .failed : .loaded
                refreshFailed = !operation.isWrite
                if operation.isWrite { feedback = Self.message(error) }
            }
        }
        task = running
        await withTaskCancellationHandler { await running.value } onCancel: { running.cancel() }
    }

    private func fetch(_ operation: NativeFavoriteRequest.Operation, accountID: String) async throws -> FavoritePage? {
        switch operation {
        case let .list(offset): return try await repository.page(offset: offset, account: accountID)
        case let .save(entry): try await repository.save(entry, account: accountID)
        case let .remove(id): try await repository.remove(id, account: accountID)
        }
        return nil
    }

    private func apply(_ operation: NativeFavoriteRequest.Operation, page: FavoritePage?) {
        switch operation {
        case let .list(offset):
            guard let page else { return }
            var seen = Set<Int64>()
            entries = ((offset == 0 ? [] : entries) + page.entries).filter { seen.insert($0.id).inserted }
            nextOffset = page.nextOffset; pagingInvalidated = false
        case let .save(entry):
            entries.removeAll { $0.id == entry.id }; entries.insert(entry, at: 0)
            pagingInvalidated = true; feedback = "已收藏"
        case let .remove(id):
            entries.removeAll { $0.id == id }
            pagingInvalidated = true; feedback = "已取消收藏"
        }
    }
    private static func message(_ error: any Error) -> String {
        switch error as? FavoriteFailure {
        case .accountUnavailable: "请登录并加载账户资料后重试"
        case .rejected: "收藏操作未成功，请刷新收藏列表后重试"
        case .outcomeUnknown: "暂未确认收藏结果，请刷新收藏列表检查"
        default: "收藏操作失败，请重试"
        }
    }
}
