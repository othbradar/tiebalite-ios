import Foundation
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
    private(set) var isShowingCachedContent = false
    @ObservationIgnored private var loadedPages: [Int: SubpostsPage] = [:]
    @ObservationIgnored private var cacheTicket: ReadingCacheTicket?
    @ObservationIgnored private var checkpointTask: Task<Void, Never>?
    @ObservationIgnored private var contentContext: ContentCacheContext
    @ObservationIgnored private let repository: any SubpostsRepository
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0

    init(route: SubpostsRoute, repository: any SubpostsRepository, initialSnapshot: SubpostsPage? = nil) {
        self.route = route
        self.repository = repository
        contentContext = (repository as? any ReadingContentCacheAccess)?.cacheContext ?? .anonymous
        if let snapshot = initialSnapshot, snapshot.route == route {
            self.snapshot = snapshot
            phase = snapshot.items.isEmpty ? .empty : .loaded
            rebuildRows()
        }
    }

    func loadIfNeeded() async {
        if contentContext != cacheContext {
            cancel()
            contentContext = cacheContext
            snapshot = nil
            rows = []
            readAnchor = nil
            loadedPages = [:]
            cacheTicket = nil
            phase = .idle
        }
        guard phase == .idle else { return }
        if let cache = repository as? any ReadingContentCacheAccess {
            phase = .initialLoading
            let token = generation
            let reading = await cache.restoreSubposts(route)
            guard token == generation, contentContext == cacheContext else { return }
            cacheTicket = await cache.ticket()
            guard token == generation, contentContext == cacheContext,
                  reading == nil || reading?.ticket == cacheTicket else { return }
            if let reading {
                cacheTicket = reading.ticket
                for page in reading.pages { loadedPages[page.value.pageNumber] = page.value }
                snapshot = assembledPages()
                readAnchor = reading.position.flatMap { position in
                    snapshot?.items.contains { $0.id == position.postID } == true ? .reply(position.postID) : nil
                }
                phase = snapshot?.items.isEmpty == true ? .empty : .loaded
                isShowingCachedContent = true
                rebuildRows()
                if !reading.isFresh { await refresh() }
                return
            }
        }
        await refresh()
    }

    func refresh() async {
        cancel()
        await load(page: currentPage, refreshing: true)
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
        if id == .parent(route.postID) || id == .count { readAnchor = nil; checkpointReading(); return }
        guard let id, case .reply(let value) = id, snapshot?.items.contains(where: { $0.id == value }) == true else { return }
        readAnchor = id
        checkpointReading()
    }

    func replyIntent(for item: Subpost) -> SubpostReplyIntent? {
        guard let snapshot, snapshot.items.contains(where: { $0.id == item.id }), snapshot.forumID > 0 else { return nil }
        return .init(route: route, forumID: snapshot.forumID, forumName: snapshot.forumName, subPostID: item.id,
                     author: item.author, replyCount: snapshot.totalCount)
    }

    func cancel() {
        checkpointReading()
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
                let incoming: SubpostsPage
                if refreshing, let cache = repository as? any ReadingContentCacheAccess {
                    incoming = try await cache.refreshSubposts(route, page: page)
                } else { incoming = try await repository.loadPage(route: route, page: page) }
                try Task.checkCancellation()
                guard let self, self.generation == token, self.contentContext == self.cacheContext else { return }
                guard incoming.route == route, incoming.pageNumber == page,
                    page > 1 || incoming.parent != nil
                else { throw PBFloorProtocolError.identityMismatch }
                self.loadedPages[page] = incoming
                self.snapshot = self.assembledPages() ?? Self.merged(incoming, retained: retained)
                self.isShowingCachedContent = false
                self.phase = self.snapshot?.items.isEmpty == true ? .empty : .loaded
            } catch is CancellationError {
                guard let self, self.generation == token, self.contentContext == self.cacheContext else { return }
                self.phase = retained == nil ? .idle : (retained?.items.isEmpty == true ? .empty : .loaded)
            } catch {
                guard let self, self.generation == token, self.contentContext == self.cacheContext else { return }
                self.failure = (error as? EndpointExecutionError) ?? .mapping
                if self.failure?.invalidatesReadingCache == true {
                    self.snapshot = nil
                    self.loadedPages = [:]
                    self.readAnchor = nil
                    self.phase = .initialFailure
                } else {
                    self.phase = retained == nil ? .initialFailure : (refreshing ? .refreshFailure : .nextPageFailure)
                }
            }
            guard let self, self.generation == token, self.contentContext == self.cacheContext else { return }
            self.task = nil
            self.rebuildRows()
        }
        task = operation
        await withTaskCancellationHandler { await operation.value } onCancel: { operation.cancel() }
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

extension SubpostsStore {
    var cacheContext: ContentCacheContext {
        (repository as? any ReadingContentCacheAccess)?.cacheContext ?? .anonymous
    }

    private var currentPage: Int {
        guard case let .reply(postID) = readAnchor else { return loadedPages.keys.min() ?? 1 }
        return loadedPages.values.first { $0.items.contains { $0.id == postID } }?.pageNumber ?? 1
    }

    private func assembledPages() -> SubpostsPage? {
        let sorted = loadedPages.values.sorted { $0.pageNumber < $1.pageNumber }
        guard let first = sorted.first else { return nil }
        return sorted.dropFirst().reduce(first) { Self.merged($1, retained: $0) }
    }

    func saveReadingPosition() async {
        checkpointReading()
        await checkpointTask?.value
    }

    private func checkpointReading() {
        guard let cache = repository as? any ReadingContentCacheAccess, let ticket = cacheTicket,
              let snapshot else { return }
        let postID: Int64
        if case let .reply(value) = readAnchor { postID = value } else { postID = snapshot.parent?.id.postID ?? route.postID }
        let position = ReadingPosition(identity: .init(threadID: route.threadID, parentPostID: route.postID),
                                       postID: postID, locator: .init(page: currentPage, postID: route.postID))
        let previous = checkpointTask
        checkpointTask = Task {
            await previous?.value
            await cache.checkpoint(position, ticket: ticket)
        }
    }
}
