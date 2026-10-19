import Foundation

extension ThreadReaderStore {
    func configuredRows(textSize: ReadingTextSizePreference) -> [ThreadReaderConfiguredRow] {
        let visibility = LocalUserVisibility.shared
        let removals = ContentRemovalVisibility.shared
        let removalChanged = removals.readerChanged(self)
        let changed = visibility.readerChanged(self) || removalChanged
        let removedFloors = (listPresentation?.rows ?? []).filter { $0.post.map { removals.contains($0.source) } == true }.count
        if !changed, let cached = configuredRowsCache, cached.revision == listRevision, cached.textSize == textSize { return cached.rows }
        let rows = (listPresentation?.rows ?? []).compactMap { row -> ThreadReaderConfiguredRow? in
            var displayed = row
            if case var .post(post) = row.content {
                guard !visibility.ids.contains(post.author.rawUserID), !removals.contains(post.source) else { return nil }
                if let count = post.replyCount { post.replyCount = max(0, count - Int32(removedFloors)) }
                let visibleRemoved = post.inlineSubposts.filter { removals.contains($0.document.source) }.map { $0.document.source.postID }
                let presentedAt = listPresentation?.presentedAt(postID: post.source.postID) ?? .distantPast
                let removedReplies = Set(visibleRemoved).union(removals.removedSubposts(
                    thread: post.source.threadID, parent: post.source.postID, after: presentedAt
                ))
                post.totalSubpostCount = max(0, post.totalSubpostCount - removedReplies.count)
                post.inlineSubposts.removeAll { removals.contains($0.document.source) }
                post.remainingSubpostCount = max(0, post.totalSubpostCount - post.inlineSubposts.count)
                post.inlineSubposts.removeAll { visibility.ids.contains($0.author.rawUserID) }
                displayed = .init(id: row.id, content: .post(post))
            }
            return ThreadReaderConfiguredRow(row: displayed, readingTextSize: textSize)
        }
        configuredRowsCache = .init(revision: listRevision, textSize: textSize, rows: rows)
        configuredRowsBuildCount += 1
        return rows
    }

    func setReadAnchor(_ rowID: ThreadReaderRowID?) {
        guard !isNavigating else { return }
        guard let rowID, rowID.isPost, listPresentation?.rows.contains(where: { $0.id == rowID }) == true else { return }
        let stablePostID = rowID
        guard readAnchor != stablePostID else {
            return
        }
        readAnchor = stablePostID
        checkpointReading()
    }

}

extension ThreadReaderStore {
    func replySucceeded(_ receipt: TextWriteReceipt, entry: ThreadReadingEntry) async {
        guard receipt.threadID == threadID else { return }
        if query == .init() { await replySucceededInDefaultMode(receipt, entry: entry) } else { await reload() }
    }

    func selectQuery(_ newQuery: ThreadReadingQuery) async {
        guard newQuery != query || isNavigating else { return }
        await navigate(query: newQuery, page: nil)
    }

    func jumpToPage(_ page: Int) async {
        guard page > 0, page <= Int(Int32.max), state.snapshot?.totalPage.map({ page <= $0 }) != false else {
            navigationMessage = "页码超出范围"
            return
        }
        await navigate(query: query, page: page == 1 ? 0 : page)
    }

    func returnToFirstPost() async { await navigate(query: query, page: 0) }

    func locatePost(_ postID: Int64) async {
        guard postID > 0 else { return }
        await navigate(query: .init(), page: 0, postID: postID)
    }

    private func navigate(query newQuery: ThreadReadingQuery, page: Int?, postID: Int64 = 0) async {
        cancel()
        let token = nextGeneration
        await saveReadingPosition()
        guard token == nextGeneration else { return }
        isNavigating = true
        navigationMessage = nil
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if token == nextGeneration { isNavigating = false; navigationTask = nil } }
            do {
                let cache = repository as? any ReadingContentCacheAccess
                let reading = page == nil ? await cache?.restoreThread(threadID, query: newQuery) : nil
                let ticket = await cache?.ticket()
                let pages: [(ReadingPageLocator, ThreadReaderSnapshot)]
                if let reading {
                    guard reading.ticket == ticket else { throw CancellationError() }
                    pages = reading.pages.map { ($0.locator, $0.value) }
                } else {
                    var locator = ReadingPageLocator(page: page ?? 0, postID: postID)
                    let value = try await repository.loadPage(.init(threadID: threadID, pageNumber: locator.page,
                                                                    postID: postID, query: newQuery))
                    if postID > 0 { locator = .init(page: value.currentPage, postID: postID) }
                    guard value.threadID == threadID, value.currentPage == locator.responsePage,
                          postID == 0 || value.posts.contains(where: { $0.id.postID == postID }) else {
                        throw ThreadReaderLoadFailure.unavailable
                    }
                    pages = [(locator, value)]
                }
                try Task.checkCancellation()
                if let ticket, await cache?.isValid(ticket) != true { throw CancellationError() }
                guard token == nextGeneration, contentContext == cacheContext,
                      let last = pages.last else { return }
                query = newQuery
                cacheTicket = ticket
                loadedPages = pages
                replyPosts = reading?.replyPosts
                let snapshot = assembledPages(metadata: last.1)
                state = .loaded(snapshot)
                loadedPostIDs = Set(snapshot.posts.map(\.id.postID))
                isShowingCachedContent = reading != nil
                listPresentation = .init(snapshot: snapshot, pagination: paginationState(for: snapshot))
                let target = postID > 0 ? postID : reading?.position?.postID
                readAnchor = target.flatMap { id in listPresentation?.rows.first { $0.post?.source.postID == id }?.id }
                    ?? listPresentation?.rows.first { $0.id.isPost }?.id
                refreshFailed = false
                hasCompletedInitialLoad = true
                readingSession &+= 1
            } catch is CancellationError {
                // A newer action or disappearing route owns the reader now.
            } catch {
                if token == nextGeneration, contentContext == cacheContext {
                    navigationMessage = "加载失败，请重试"
                }
            }
        }
        navigationTask = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }
}
