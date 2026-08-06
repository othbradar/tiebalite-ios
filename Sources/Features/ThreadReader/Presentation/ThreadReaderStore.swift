import Observation

enum ThreadReaderLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum ThreadReaderState: Equatable, Sendable {
    case initialFailure(ThreadReaderLoadFailure)
    case initialLoading
    case loaded(ThreadReaderSnapshot)
    case loadingNextPage(ThreadReaderSnapshot)
    case nextPageFailure(ThreadReaderSnapshot)

    var snapshot: ThreadReaderSnapshot? {
        switch self {
        case let .loaded(snapshot),
             let .loadingNextPage(snapshot),
             let .nextPageFailure(snapshot):
            snapshot
        case .initialFailure, .initialLoading:
            nil
        }
    }
}

@MainActor
@Observable
final class ThreadReaderStore {
    let threadID: Int64
    private(set) var state: ThreadReaderState = .initialLoading
    private(set) var listPresentation: ThreadReaderListPresentation?
    private(set) var readAnchor: ThreadReaderRowID?

    private let repository: any ThreadReaderRepository
    @ObservationIgnored private var hasCompletedInitialLoad = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0

    init(
        threadID: Int64,
        repository: any ThreadReaderRepository
    ) {
        self.threadID = threadID
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard !hasCompletedInitialLoad,
              activeGeneration == nil else {
            return
        }
        await replaceInitialLoad()
    }

    func reload() async {
        hasCompletedInitialLoad = false
        await replaceInitialLoad()
    }

    func loadNextPage() async {
        guard activeGeneration == nil,
              let retained = state.snapshot,
              retained.hasMore else {
            return
        }
        let request = ThreadReaderPageRequest(
            threadID: threadID,
            pageNumber: retained.currentPage + 1,
            postID: retained.nextPostID ?? 0
        )
        listPresentation?.setPagination(.loading(
            nextPage: request.pageNumber
        ))
        await startLoad(
            request: request,
            retained: retained,
            loadingState: .loadingNextPage(retained)
        )
    }

    func prepareRetry() {
        guard activeGeneration == nil else {
            return
        }
        hasCompletedInitialLoad = false
        state = .initialLoading
    }

    func setReadAnchor(_ rowID: ThreadReaderRowID?) {
        let stablePostID = rowID?.isPost == true ? rowID : nil
        guard readAnchor != stablePostID else {
            return
        }
        readAnchor = stablePostID
    }

    func cancel() {
        loadTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nil
        loadTask = nil
        switch state {
        case let .loadingNextPage(snapshot):
            state = .loaded(snapshot)
            listPresentation?.setPagination(
                paginationState(for: snapshot)
            )
        case .initialLoading:
            hasCompletedInitialLoad = false
        case .initialFailure, .loaded, .nextPageFailure:
            break
        }
    }

    private func replaceInitialLoad() async {
        loadTask?.cancel()
        listPresentation = nil
        await startLoad(
            request: .initial(threadID: threadID),
            retained: nil,
            loadingState: .initialLoading
        )
    }

    private func startLoad(
        request: ThreadReaderPageRequest,
        retained: ThreadReaderSnapshot?,
        loadingState: ThreadReaderState
    ) async {
        nextGeneration &+= 1
        let generation = nextGeneration
        activeGeneration = generation
        state = loadingState

        let repository = repository
        let task = Task { @MainActor [weak self] in
            do {
                let page = try await repository.loadPage(request)
                try Task.checkCancellation()
                self?.finish(
                    generation: generation,
                    request: request,
                    retained: retained,
                    page: page
                )
            } catch is CancellationError {
                self?.finishCancellation(
                    generation: generation,
                    retained: retained
                )
            } catch {
                guard !Task.isCancelled else {
                    self?.finishCancellation(
                        generation: generation,
                        retained: retained
                    )
                    return
                }
                self?.finishFailure(
                    generation: generation,
                    retained: retained
                )
            }
        }
        loadTask = task

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func finish(
        generation: UInt64,
        request: ThreadReaderPageRequest,
        retained: ThreadReaderSnapshot?,
        page: ThreadReaderSnapshot
    ) {
        guard activeGeneration == generation else {
            return
        }
        guard page.threadID == threadID else {
            finishFailure(generation: generation, retained: retained)
            return
        }

        if let retained {
            guard page.currentPage >= request.pageNumber else {
                finishFailure(generation: generation, retained: retained)
                return
            }
            let merged = merge(retained: retained, page: page)
            state = .loaded(merged.snapshot)
            if var presentation = listPresentation {
                presentation.append(
                    snapshot: merged.snapshot,
                    newPosts: merged.uniquePosts,
                    pagination: paginationState(for: merged.snapshot)
                )
                listPresentation = presentation
            } else {
                listPresentation = ThreadReaderListPresentation(
                    snapshot: merged.snapshot,
                    pagination: paginationState(for: merged.snapshot)
                )
            }
        } else {
            state = .loaded(page)
            listPresentation = ThreadReaderListPresentation(
                snapshot: page,
                pagination: paginationState(for: page)
            )
            hasCompletedInitialLoad = true
        }
        clearLoad(generation: generation)
    }

    private func merge(
        retained: ThreadReaderSnapshot,
        page: ThreadReaderSnapshot
    ) -> (snapshot: ThreadReaderSnapshot, uniquePosts: [ThreadReaderPost]) {
        var seen = Set(retained.posts.map { $0.document.source.postID })
        let uniquePosts = page.posts.filter {
            seen.insert($0.document.source.postID).inserted
        }
        let snapshot = ThreadReaderSnapshot(
            threadID: retained.threadID,
            title: page.title,
            forumName: page.forumName,
            author: page.author,
            replyCount: page.replyCount,
            posts: retained.posts + uniquePosts,
            currentPage: page.currentPage,
            totalPage: page.totalPage ?? retained.totalPage,
            hasMore: page.hasMore,
            nextPostID: page.nextPostID
        )
        return (snapshot, uniquePosts)
    }

    private func finishFailure(
        generation: UInt64,
        retained: ThreadReaderSnapshot?
    ) {
        guard activeGeneration == generation else {
            return
        }
        if let retained {
            state = .nextPageFailure(retained)
            listPresentation?.setPagination(.failure(
                nextPage: retained.currentPage + 1
            ))
        } else {
            state = .initialFailure(.unavailable)
            listPresentation = nil
            hasCompletedInitialLoad = true
        }
        clearLoad(generation: generation)
    }

    private func finishCancellation(
        generation: UInt64,
        retained: ThreadReaderSnapshot?
    ) {
        guard activeGeneration == generation else {
            return
        }
        if let retained {
            state = .loaded(retained)
            listPresentation?.setPagination(
                paginationState(for: retained)
            )
        } else {
            state = .initialLoading
            listPresentation = nil
            hasCompletedInitialLoad = false
        }
        clearLoad(generation: generation)
    }

    private func clearLoad(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        loadTask = nil
    }

    private func paginationState(
        for snapshot: ThreadReaderSnapshot
    ) -> ThreadReaderPaginationRowState {
        snapshot.hasMore
            ? .loadMore(nextPage: snapshot.currentPage + 1)
            : .end
    }
}
