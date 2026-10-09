import Foundation
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
    private(set) var listPresentation: ThreadReaderListPresentation? {
        didSet { listRevision &+= 1 }
    }
    private(set) var listRevision: UInt64 = 0
    private(set) var readAnchor: ThreadReaderRowID?
    @ObservationIgnored private(set) var prefetchPreparationCount = 0
    @ObservationIgnored private var loadedPostIDs: Set<Int64> = []
    @ObservationIgnored var configuredRowsCache: ThreadReaderConfiguredRows?
    @ObservationIgnored private(set) var configuredRowsBuildCount = 0

    private(set) var refreshFailed = false
    private(set) var isShowingCachedContent = false
    @ObservationIgnored private var cacheTicket: ReadingCacheTicket?
    @ObservationIgnored private var checkpointTask: Task<Void, Never>?
    @ObservationIgnored private var loadedPages: [(ReadingPageLocator, ThreadReaderSnapshot)] = []
    @ObservationIgnored private var contentContext: ContentCacheContext
    @ObservationIgnored private var refreshing = false
    @ObservationIgnored private var restoring = false
    private let prefetch: ContentPrefetchSession?
    private let repository: any ThreadReaderRepository
    private let replyFollowup: (any ReplyFollowupLoading)?
    @ObservationIgnored private var replyTask: Task<ReplyReadUpdate?, any Error>?
    @ObservationIgnored private var replyPosts: ReplyPostUpdate?
    @ObservationIgnored private var followedReceipt: TextWriteReceipt?
    @ObservationIgnored private var hasCompletedInitialLoad = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0
    @ObservationIgnored private var hasClaimedDisplayedThread = false

    init(
        threadID: Int64,
        repository: any ThreadReaderRepository,
        initialSnapshot: ThreadReaderSnapshot? = nil,
        prefetch: ContentPrefetchSession? = nil,
        replyFollowup: (any ReplyFollowupLoading)? = nil
    ) {
        self.prefetch = prefetch
        self.threadID = threadID
        self.repository = repository
        self.replyFollowup = replyFollowup
        contentContext = (repository as? any ReadingContentCacheAccess)?.cacheContext ?? .anonymous
        if let snapshot = initialSnapshot, snapshot.threadID == threadID {
            state = .loaded(snapshot)
            hasCompletedInitialLoad = true
            listPresentation = ThreadReaderListPresentation(snapshot: snapshot, pagination: paginationState(for: snapshot))
            loadedPostIDs = Set(snapshot.posts.map(\.id.postID))
        }
    }

    func loadIfNeeded() async {
        if contentContext != cacheContext {
            cancel()
            contentContext = cacheContext
            state = .initialLoading
            listPresentation = nil
            readAnchor = nil
            loadedPages = []
            loadedPostIDs = []
            cacheTicket = nil
            followedReceipt = nil
            replyPosts = nil
            hasCompletedInitialLoad = false
            hasClaimedDisplayedThread = false
        }
        guard !hasCompletedInitialLoad, !restoring,
              activeGeneration == nil else {
            return
        }
        if let cache = repository as? any ReadingContentCacheAccess {
            restoring = true
            let generation = nextGeneration
            let reading = await cache.restoreThread(threadID)
            guard generation == nextGeneration, contentContext == cacheContext else { restoring = false; return }
            cacheTicket = await cache.ticket()
            guard generation == nextGeneration, contentContext == cacheContext,
                  reading == nil || reading?.ticket == cacheTicket else { restoring = false; return }
            restoring = false
            if let reading, let last = reading.pages.last {
                loadedPages = reading.pages.map { ($0.locator, $0.value) }
                replyPosts = reading.replyPosts
                let snapshot = assembledPages(metadata: last.value)
                loadedPostIDs = Set(snapshot.posts.map(\.id.postID))
                state = .loaded(snapshot)
                isShowingCachedContent = true
                listPresentation = .init(snapshot: snapshot, pagination: paginationState(for: snapshot))
                if let position = reading.position {
                    readAnchor = listPresentation?.rows.first { $0.post?.source.postID == position.postID }?.id
                }
                hasCompletedInitialLoad = true
                if !reading.isFresh { await reload() }
                return
            }
        }
        await replaceInitialLoad()
    }

    func reload() async {
        replyTask?.cancel()
        replyTask = nil
        prefetch?.cancel()
        guard let retained = state.snapshot else { await replaceInitialLoad(); return }
        loadTask?.cancel()
        refreshing = true
        refreshFailed = false
        let locator = currentLocator ?? .init(page: 0, postID: 0)
        await startLoad(request: .init(threadID: threadID, pageNumber: locator.page, postID: locator.postID),
                        retained: retained, loadingState: .loaded(retained))
    }

    func loadNextPage() async {
        guard activeGeneration == nil, replyTask == nil,
              let retained = state.snapshot,
              retained.hasMore else {
            return
        }
        guard let nextPostID = retained.nextPostID else {
            state = .nextPageFailure(retained)
            listPresentation?.setPagination(.failure(
                nextPage: retained.currentPage + 1
            ))
            return
        }
        let request = ThreadReaderPageRequest(
            threadID: threadID,
            pageNumber: retained.currentPage + 1,
            postID: nextPostID,
            loadedPostIDs: loadedPostIDs
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

    func cancel() {
        replyTask?.cancel()
        replyTask = nil
        prefetch?.cancel()
        checkpointReading()
        restoring = false
        refreshing = false
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
        refreshing = false
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
        let isRefresh = refreshing
        let task = Task { @MainActor [weak self] in
            do {
                let page: ThreadReaderSnapshot
                if isRefresh, let cache = repository as? any ReadingContentCacheAccess {
                    page = try await cache.refreshThread(request)
                } else { page = try await repository.loadPage(request) }
                try Task.checkCancellation()
                guard self?.contentContext == self?.cacheContext else { return }
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
                guard let self, self.activeGeneration == generation, self.contentContext == self.cacheContext else { return }
                if ReadingContentRevoked.isConfirmed(error) {
                    self.loadedPages = []
                    self.loadedPostIDs = []
                    self.readAnchor = nil
                    self.finishFailure(generation: generation, retained: nil)
                } else {
                    self.finishFailure(generation: generation, retained: retained)
                }
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

        let locator = ReadingPageLocator(page: request.pageNumber, postID: request.postID)
        let replacedReply = replyPosts?.posts.contains { post in page.posts.contains { $0.id == post.id } } == true
        replyPosts = replyPosts?.removing(Set(page.posts.map(\.id.postID)))
        isShowingCachedContent = false
        if refreshing, let retained {
            guard page.currentPage == locator.responsePage else {
                finishFailure(generation: generation, retained: retained)
                return
            }
            if loadedPages.isEmpty {
                // Notification/initialSnapshot injection can contain multiple pages without provenance.
                // Retain those rows; the next ordinary cache-backed entry supplies exact page records.
                let updated = ReplyPageMerge.replacingPosts(in: retained, with: page)
                state = .loaded(updated)
            } else {
                loadedPages.removeAll { $0.0.responsePage == page.currentPage }
                loadedPages.append((locator, page))
                state = .loaded(assembledPages(metadata: page))
            }
            if let snapshot = state.snapshot {
                loadedPostIDs = Set(snapshot.posts.map(\.id.postID))
                listPresentation = .init(snapshot: snapshot, pagination: paginationState(for: snapshot))
            }
            isShowingCachedContent = false
            clearLoad(generation: generation)
            return
        }
        if let retained {
            guard page.currentPage == request.pageNumber else {
                finishFailure(generation: generation, retained: retained)
                return
            }
            let merged = merge(retained: retained, page: page, replacingReply: replacedReply || replyPosts != nil)
            if page.hasMore, merged.uniquePosts.isEmpty, !replacedReply,
               !loadedPages.contains(where: { $0.0.responsePage == page.currentPage }) {
                finishFailure(generation: generation, retained: retained)
                return
            }
            state = .loaded(merged.snapshot)
            loadedPostIDs.formUnion(merged.uniquePosts.map(\.id.postID))
            if var presentation = listPresentation, !replacedReply, replyPosts == nil,
               !loadedPages.contains(where: { $0.0.responsePage > retained.currentPage }) {
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
            guard page.currentPage == 1 else {
                finishFailure(generation: generation, retained: nil)
                return
            }
            state = .loaded(page)
            loadedPostIDs = Set(page.posts.map(\.id.postID))
            listPresentation = ThreadReaderListPresentation(
                snapshot: page,
                pagination: paginationState(for: page)
            )
            hasCompletedInitialLoad = true
        }
        loadedPages.removeAll { $0.0.responsePage == page.currentPage }
        loadedPages.append((locator, page))
        clearLoad(generation: generation)
    }

    private func finishFailure(
        generation: UInt64,
        retained: ThreadReaderSnapshot?
    ) {
        guard activeGeneration == generation else {
            return
        }
        if let retained, refreshing {
            state = .loaded(retained)
            refreshFailed = true
            listPresentation?.setPagination(.refreshFailure)
        } else if let retained {
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

}

extension ThreadReaderStore {
    private func clearLoad(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        loadTask = nil
        refreshing = false
    }

    func claimDisplayedThread(_ displayedThreadID: Int64) -> Bool {
        guard displayedThreadID == threadID, !hasClaimedDisplayedThread else { return false }
        hasClaimedDisplayedThread = true
        checkpointReading()
        return true
    }

    func replySucceeded(_ receipt: TextWriteReceipt, entry: ThreadReadingEntry) async {
        guard receipt.threadID == threadID, let retained = state.snapshot else { return }
        guard let replyFollowup else { await reload(); return }
        guard followedReceipt != receipt else { return }
        followedReceipt = receipt
        cancel()
        let generation = nextGeneration
        let cache = repository as? any ReadingContentCacheAccess
        let ticket = await cache?.ticket()
        guard generation == nextGeneration, contentContext == cacheContext else { return }
        let request = ReplyFollowupRequest(receipt: receipt, entry: entry, page: retained.currentPage)
        let task = Task { try await replyFollowup.loadReply(request) }
        replyTask = task
        defer { if generation == nextGeneration { replyTask = nil } }
        do {
            let update = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            guard let update, update.threadID == threadID,
                  await canMergeReply(generation: generation, ticket: ticket) else { return }
            if case let .posts(delta) = update {
                await applyReplyPosts(delta, ticket: ticket, generation: generation, retained: retained)
                return
            }
            guard let page = update.page else { return }
            var locator = loadedPages.first { $0.0.responsePage == page.currentPage }?.0
                ?? .init(page: page.currentPage, postID: receipt.postID)
            if let ticket, let saved = await cache?.mergeReplyPage(page, ticket: ticket) { locator = saved }
            guard await canMergeReply(generation: generation, ticket: ticket) else { return }
            let old = loadedPages.first { $0.0.responsePage == page.currentPage }?.1
            let mergedPage = old.map { ReplyPageMerge.merge($0, page: page, pagination: page) } ?? page
            loadedPages.removeAll { $0.0.responsePage == page.currentPage }
            loadedPages.append((locator, mergedPage))
            let current = state.snapshot ?? retained
            let snapshot = ReplyPageMerge.mergeReadPage(current, page: page)
            replyPosts = replyPosts?.removing(Set(page.posts.map(\.id.postID)))
            presentReplyUpdate(ReplyPageMerge.applying(replyPosts, to: snapshot))
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), generation == nextGeneration,
                  contentContext == cacheContext else { return }
            refreshFailed = true
            listPresentation?.setPagination(.refreshFailure)
        }
    }

    private func canMergeReply(generation: UInt64, ticket: ReadingCacheTicket?) async -> Bool {
        let cache = repository as? any ReadingContentCacheAccess
        if let ticket, await cache?.isValid(ticket) != true { return false }
        return !Task.isCancelled && generation == nextGeneration && contentContext == cacheContext
    }

    private func applyReplyPosts(_ delta: ReplyPostUpdate, ticket: ReadingCacheTicket?, generation: UInt64,
                                 retained: ThreadReaderSnapshot) async {
        let cache = repository as? any ReadingContentCacheAccess
        if let ticket { await cache?.mergeReplyPosts(delta, ticket: ticket) }
        guard await canMergeReply(generation: generation, ticket: ticket) else { return }
        replyPosts = replyPosts?.merging(delta) ?? delta
        presentReplyUpdate(ReplyPageMerge.applying(replyPosts, to: state.snapshot ?? retained))
    }

    private func presentReplyUpdate(_ snapshot: ThreadReaderSnapshot) {
        state = .loaded(snapshot)
        loadedPostIDs = Set(snapshot.posts.map(\.id.postID))
        isShowingCachedContent = false
        refreshFailed = false
        listPresentation = .init(snapshot: snapshot, pagination: paginationState(for: snapshot))
    }

    private func paginationState(
        for snapshot: ThreadReaderSnapshot
    ) -> ThreadReaderPaginationRowState {
        if isShowingCachedContent {
            return .cached(hasMore: snapshot.hasMore, nextPage: snapshot.currentPage + 1)
        }
        return snapshot.hasMore ? .loadMore(nextPage: snapshot.currentPage + 1) : .end
    }
    private func merge(
        retained: ThreadReaderSnapshot,
        page: ThreadReaderSnapshot, replacingReply: Bool = false
    ) -> (snapshot: ThreadReaderSnapshot, uniquePosts: [ThreadReaderPost]) {
        var seen = loadedPostIDs
        let uniquePosts = page.posts.filter {
            seen.insert($0.document.source.postID).inserted
        }
        let snapshot = ThreadReaderSnapshot(
            threadID: retained.threadID,
            title: page.title,
            forumName: page.forumName,
            forumID: page.forumID ?? retained.forumID,
            forumAvatarResource: page.forumAvatarResource ?? retained.forumAvatarResource,
            author: page.author,
            replyCount: page.replyCount,
            posts: retained.posts + uniquePosts,
            currentPage: page.currentPage,
            totalPage: page.totalPage ?? retained.totalPage,
            hasMore: page.hasMore,
            nextPostID: page.nextPostID
        )
        let merged = replacingReply || loadedPages.contains { $0.0.responsePage > retained.currentPage }
            ? ReplyPageMerge.merge(retained, page: page, pagination: page) : snapshot
        return (merged, uniquePosts)
    }

    // A notification resolves an anchor before the reader is mounted; this is not a read event.
    func setInitialReadAnchor(_ rowID: ThreadReaderRowID) {
        guard listPresentation?.rows.contains(where: { $0.id == rowID && $0.id.isPost }) == true else { return }
        readAnchor = rowID
    }

    var cacheContext: ContentCacheContext {
        (repository as? any ReadingContentCacheAccess)?.cacheContext ?? .anonymous
    }

    private var currentLocator: ReadingPageLocator? {
        let postID = listPresentation?.rows.first { $0.id == readAnchor }?.post?.source.postID
        return loadedPages.first { page in page.1.posts.contains { $0.id.postID == postID } }?.0 ?? loadedPages.first?.0
    }

    func saveReadingPosition() async {
        checkpointReading()
        await checkpointTask?.value
    }

    private func checkpointReading() {
        guard let cache = repository as? any ReadingContentCacheAccess, let ticket = cacheTicket,
              let locator = currentLocator,
              let post = listPresentation?.rows.first(where: { $0.id == readAnchor })?.post
                ?? listPresentation?.rows.first?.post else { return }
        let position = ReadingPosition(identity: .init(threadID: threadID), postID: post.source.postID, locator: locator)
        let previous = checkpointTask
        checkpointTask = Task {
            await previous?.value
            await cache.checkpoint(position, ticket: ticket)
        }
    }

    private func assembledPages(metadata: ThreadReaderSnapshot) -> ThreadReaderSnapshot {
        let sorted = loadedPages.sorted { $0.0.responsePage < $1.0.responsePage }
        var last = sorted.first?.1 ?? metadata
        for page in sorted.dropFirst() where page.0.responsePage == last.currentPage + 1 { last = page.1 }
        var seen = Set<Int64>()
        let posts = sorted.flatMap { $0.1.posts }.filter { seen.insert($0.id.postID).inserted }
        return ReplyPageMerge.applying(replyPosts, to: ReplyPageMerge.snapshot(metadata: metadata, pagination: last, posts: posts))
    }

}

// Prefetch only supplies repository data; it cannot mutate the current reader snapshot or anchor.
extension ThreadReaderStore {
    func prepareRetry() {
        guard activeGeneration == nil else {
            return
        }
        hasCompletedInitialLoad = false
        state = .initialLoading
    }

    func prefetchNextPage() {
        guard activeGeneration == nil, replyTask == nil, contentContext == cacheContext,
              let snapshot = state.snapshot, snapshot.hasMore, let postID = snapshot.nextPostID else { return }
        prefetch?.followingThreadPage(.init(threadID: threadID, page: snapshot.currentPage + 1, postID: postID,
                                            context: contentContext, generation: nextGeneration)) {
            prefetchPreparationCount += 1
            return .init(threadID: threadID, pageNumber: snapshot.currentPage + 1, postID: postID,
                         loadedPostIDs: loadedPostIDs)
        }
    }
}

extension ThreadReaderStore {
    func configuredRows(textSize: ReadingTextSizePreference) -> [ThreadReaderConfiguredRow] {
        if let cached = configuredRowsCache, cached.revision == listRevision, cached.textSize == textSize { return cached.rows }
        let rows = (listPresentation?.rows ?? []).map { ThreadReaderConfiguredRow(row: $0, readingTextSize: textSize) }
        configuredRowsCache = .init(revision: listRevision, textSize: textSize, rows: rows)
        configuredRowsBuildCount += 1
        return rows
    }

    func setReadAnchor(_ rowID: ThreadReaderRowID?) {
        guard let rowID, rowID.isPost, listPresentation?.rows.contains(where: { $0.id == rowID }) == true else { return }
        let stablePostID = rowID
        guard readAnchor != stablePostID else {
            return
        }
        readAnchor = stablePostID
        checkpointReading()
    }

}
