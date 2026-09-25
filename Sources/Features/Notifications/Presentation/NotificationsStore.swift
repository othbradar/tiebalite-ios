import Observation
#if DEBUG
import OSLog
#endif

@MainActor
@Observable
final class NotificationsStore {
    let replies: NotificationsListStore
    let mentions: NotificationsListStore
    var selectedPage: NotificationKind? = .replies
    var selectionGeneration: UInt64 = 0
    private(set) var counts: NotificationCounts = .zero
    private(set) var context: AuthContext = .anonymous
    private(set) var countFailure: EndpointExecutionError?
    var unreadCount: Int { counts.total }
    @ObservationIgnored private let repository: any NotificationsRepository
    @ObservationIgnored private var countTask: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0

    init(repository: any NotificationsRepository) {
        self.repository = repository
        replies = NotificationsListStore(kind: .replies, repository: repository)
        mentions = NotificationsListStore(kind: .mentions, repository: repository)
    }

    func page(_ kind: NotificationKind) -> NotificationsListStore { kind == .replies ? replies : mentions }

    func updateContext(_ value: AuthContext) {
        guard context != value else { return }
        generation &+= 1
        countTask?.cancel()
        countTask = nil
        context = value
        counts = .zero
        countFailure = nil
        replies.reset(context: value)
        mentions.reset(context: value)
    }

    func select(_ kind: NotificationKind) {
        guard selectedPage != kind else { return }
        selectedPage = kind
        selectionGeneration &+= 1
    }

    func loadSelected() async {
        guard let selectedPage else { return }
        await page(selectedPage).loadIfNeeded()
        await refreshCountsAfterReading()
    }

    func refreshCountsAfterReading() async {
        // A count request started before the list read cannot confirm the server's read side effect.
        if let countTask { await countTask.value }
        guard !Task.isCancelled else { return }
        await refreshCounts()
    }

    func refreshCounts() async {
        guard case .active = context, countTask == nil else { return }
        let token = generation
        let context = context
        let operation = Task { @MainActor [weak self, repository] in
            do {
                let counts = try await repository.unread(context: context)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.counts = counts
                self.countFailure = nil
            } catch is CancellationError {
                // Cancellation must not erase the last confirmed server count.
            } catch {
                guard let self, self.generation == token else { return }
                self.countFailure = NotificationsListStore.failure(error)
#if DEBUG
                Logger(subsystem: "dev.local.tiebaliteios", category: "Notifications")
                    .notice("Count failure: \(String(describing: self.countFailure), privacy: .public)")
#endif
            }
            guard let self, self.generation == token else { return }
            self.countTask = nil
        }
        countTask = operation
        await operation.value
    }
}

enum NotificationsPhase: Equatable, Sendable {
    case idle, initialLoading, initialFailure, loaded, empty, refreshing, refreshFailure, loadingNextPage, nextPageFailure
}

struct NotificationListRow: Identifiable, Equatable, Sendable {
    let id: String
    let item: TiebaNotification?
    let phase: NotificationsPhase
    let hasMore: Bool
}

@MainActor
@Observable
final class NotificationsListStore {
    let kind: NotificationKind
    private(set) var items: [TiebaNotification] = []
    private(set) var rows: [NotificationListRow] = []
    private(set) var phase: NotificationsPhase = .idle
    private(set) var nextPage: Int?
    private(set) var readAnchor: String?
    private(set) var error: EndpointExecutionError?
    @ObservationIgnored private let repository: any NotificationsRepository
    @ObservationIgnored private var context: AuthContext = .anonymous
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var hasLoaded = false

    init(kind: NotificationKind, repository: any NotificationsRepository) { self.kind = kind; self.repository = repository }

    func reset(context: AuthContext) {
        cancel()
        self.context = context
        items = []; rows = []; nextPage = nil; readAnchor = nil; error = nil
        hasLoaded = false
        phase = .idle
    }

    func loadIfNeeded() async {
        guard !hasLoaded, task == nil else { return }
        await refresh()
    }

    func refresh() async {
        cancel()
        await load(page: 0)
    }

    func loadNextPage() async {
        guard task == nil, let nextPage else { return }
        await load(page: nextPage)
    }

    func prefetch(_ ids: [String]) {
        guard phase == .loaded, ids.contains(where: { id in items.suffix(4).contains { $0.id == id } }) else { return }
        // load() installs its task synchronously on the MainActor before its first suspension.
        Task { await loadNextPage() }
    }

    func setAnchor(_ id: String?) {
        guard let id, items.contains(where: { $0.id == id }) else { return }
        readAnchor = id
    }

    func cancel() {
        generation &+= 1
        task?.cancel(); task = nil
        phase = hasLoaded ? (items.isEmpty ? .empty : .loaded) : .idle
        rebuildRows()
    }

    private func load(page: Int) async {
        guard case .active = context else { return }
        generation &+= 1
        let token = generation
        let context = context
        phase = page == 0 ? (hasLoaded ? .refreshing : .initialLoading) : .loadingNextPage
        error = nil
        rebuildRows()
        let operation = Task { @MainActor [weak self, repository, kind] in
            do {
                let incoming = try await repository.load(kind: kind, page: page, context: context)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                var seen = Set<String>()
                self.items = ((page == 0 ? [] : self.items) + incoming.items).filter { seen.insert($0.id).inserted }
                self.nextPage = incoming.nextPage
                self.hasLoaded = true
                self.phase = self.items.isEmpty ? .empty : .loaded
            } catch is CancellationError {
                guard let self, self.generation == token else { return }
                self.phase = self.hasLoaded ? (self.items.isEmpty ? .empty : .loaded) : .idle
            } catch {
                guard let self, self.generation == token else { return }
                self.error = Self.failure(error)
#if DEBUG
                Logger(subsystem: "dev.local.tiebaliteios", category: "Notifications")
                    .notice("List failure: \(String(describing: self.error), privacy: .public)")
#endif
                self.phase = self.hasLoaded ? (page == 0 ? .refreshFailure : .nextPageFailure) : .initialFailure
            }
            guard let self, self.generation == token else { return }
            self.task = nil
            self.rebuildRows()
        }
        task = operation
        await operation.value
    }

    static func failure(_ error: any Error) -> EndpointExecutionError {
        if error is RequestAuthorizationError { return .authentication }
        return (error as? EndpointExecutionError) ?? .mapping
    }

    private func rebuildRows() {
        rows = items.map { .init(id: $0.id, item: $0, phase: .loaded, hasMore: false) }
        rows.append(.init(id: "\(kind.rawValue).footer", item: nil, phase: phase, hasMore: nextPage != nil))
    }
}
