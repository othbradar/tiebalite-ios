import Observation

enum SubpostsPhase: Equatable, Sendable {
    case idle, initialLoading, initialFailure, loaded, empty, refreshing, refreshFailure, loadingNextPage, nextPageFailure
}

@MainActor
@Observable
final class SubpostsStore {
    let route: SubpostsRoute
    private(set) var phase: SubpostsPhase = .idle
    private(set) var snapshot: SubpostsPage?
    private(set) var rows: [SubpostsRow] = []
    private(set) var readAnchor: SubpostsRowID?
    private(set) var failure: EndpointExecutionError?
    @ObservationIgnored private let repository: any SubpostsRepository
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0

    init(route: SubpostsRoute, repository: any SubpostsRepository, initialSnapshot: SubpostsPage? = nil) {
        self.route = route
        self.repository = repository
        if let snapshot = initialSnapshot, snapshot.route == route {
            self.snapshot = snapshot
            phase = snapshot.items.isEmpty ? .empty : .loaded
            rebuildRows()
        }
    }

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await refresh()
    }

    func refresh() async {
        cancel()
        await load(page: 1, refreshing: true)
    }

    func loadNextPage() async {
        guard task == nil, let snapshot, snapshot.hasMore else { return }
        await load(page: snapshot.pageNumber + 1, refreshing: false)
    }

    func prefetch(_ ids: [SubpostsRowID]) async {
        guard phase == .loaded, let snapshot,
            ids.contains(where: { id in snapshot.items.suffix(4).contains { id == .reply($0.id) } })
        else { return }
        await loadNextPage()
    }

    func setReadAnchor(_ id: SubpostsRowID?) {
        guard let id, case .reply(let value) = id, snapshot?.items.contains(where: { $0.id == value }) == true else { return }
        readAnchor = id
    }

    func replyIntent(for item: Subpost) -> SubpostReplyIntent? {
        guard let snapshot, snapshot.items.contains(where: { $0.id == item.id }), snapshot.forumID > 0 else { return nil }
        return .init(route: route, forumID: snapshot.forumID, forumName: snapshot.forumName, subPostID: item.id, author: item.author)
    }

    func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        switch phase {
        case .initialLoading: phase = .idle
        case .refreshing, .loadingNextPage: phase = snapshot?.items.isEmpty == true ? .empty : .loaded
        default: break
        }
        rebuildRows()
    }

    private func load(page: Int, refreshing: Bool) async {
        generation &+= 1
        let token = generation
        let retained = snapshot
        phase = refreshing ? (retained == nil ? .initialLoading : .refreshing) : .loadingNextPage
        failure = nil
        rebuildRows()
        let operation = Task { @MainActor [weak self, repository, route] in
            do {
                let incoming = try await repository.loadPage(route: route, page: page)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                guard incoming.route == route, incoming.pageNumber == page,
                    page > 1 || incoming.parent != nil
                else { throw PBFloorProtocolError.identityMismatch }
                self.snapshot = Self.merged(incoming, retained: refreshing ? nil : retained)
                self.phase = self.snapshot?.items.isEmpty == true ? .empty : .loaded
            } catch is CancellationError {
                guard let self, self.generation == token else { return }
                self.phase = retained == nil ? .idle : (retained?.items.isEmpty == true ? .empty : .loaded)
            } catch {
                guard let self, self.generation == token else { return }
                self.failure = (error as? EndpointExecutionError) ?? .mapping
                self.phase = retained == nil ? .initialFailure : (refreshing ? .refreshFailure : .nextPageFailure)
            }
            guard let self, self.generation == token else { return }
            self.task = nil
            self.rebuildRows()
        }
        task = operation
        await operation.value
    }

    private static func merged(_ incoming: SubpostsPage, retained: SubpostsPage?) -> SubpostsPage {
        var seen = Set<Int64>()
        let items = ((retained?.items ?? []) + incoming.items).filter { seen.insert($0.id).inserted }
        return SubpostsPage(
            route: incoming.route, parent: retained?.parent ?? incoming.parent,
            threadAuthorID: retained?.threadAuthorID ?? incoming.threadAuthorID,
            forumID: retained?.forumID ?? incoming.forumID, forumName: retained?.forumName ?? incoming.forumName,
            items: items, pageNumber: incoming.pageNumber, totalPages: incoming.totalPages, totalCount: incoming.totalCount)
    }

    private func rebuildRows() {
        guard let snapshot else {
            rows = []
            return
        }
        rows = SubpostsRow.make(snapshot, phase: phase)
    }
}
