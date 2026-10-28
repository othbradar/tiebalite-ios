import Foundation

extension ThreadReaderStore {
    func rememberUnconfirmedPages(_ reading: CachedReading<ThreadReaderSnapshot>?) {
        pagesNeedingConfirmation = Dictionary(uniqueKeysWithValues:
            (reading?.pages.filter(\.requiresPageConfirmation) ?? []).map { ($0.locator.responsePage, $0.value) })
    }

    func resumePageConfirmation(generation: UInt64) async {
        guard generation == nextGeneration, !Task.isCancelled else { return }
        _ = await repairLegacyLocatedPagesIfNeeded()
    }

    /// Older releases stored PID windows as whole pages. Their exact origin was not
    /// saved, so confirm candidate pages with ordinary pagination, without deleting data.
    func repairLegacyLocatedPagesIfNeeded() async -> Bool {
        let candidates = loadedPages.filter { pagesNeedingConfirmation[$0.0.responsePage] == $0.1 }
        guard !candidates.isEmpty else { return false }
        guard !isNavigating else { return true }
        let generation = nextGeneration
        let requestedQuery = query
        let anchor = readAnchor
        isNavigating = true
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == nextGeneration { isNavigating = false; navigationTask = nil }
            }
            do {
                let replacements = try await confirmedPages(candidates.map { $0.0 }, query: requestedQuery, generation: generation)
                guard generation == nextGeneration, contentContext == cacheContext,
                      let retained = state.snapshot else { return }
                for replacement in replacements {
                    loadedPages.removeAll { $0.0.responsePage == replacement.0.responsePage }
                    loadedPages.append(replacement)
                    pagesNeedingConfirmation.removeValue(forKey: replacement.0.responsePage)
                }
                let snapshot = assembledPages(metadata: replacements.last?.1 ?? retained)
                state = .loaded(snapshot)
                loadedPostIDs = Set(snapshot.posts.map(\.id.postID))
                isShowingCachedContent = false
                refreshFailed = false
                listPresentation = .init(snapshot: snapshot, pagination: paginationState(for: snapshot))
                readAnchor = anchor.flatMap { id in listPresentation?.rows.contains { $0.id == id } == true ? id : nil }
                readingSession &+= 1
            } catch is CancellationError {
                // A newer navigation or account owns the reader.
            } catch {
                guard generation == nextGeneration, contentContext == cacheContext else { return }
                if ReadingContentRevoked.isConfirmed(error) {
                    loadedPages = []
                    loadedPostIDs = []
                    readAnchor = nil
                    state = .initialFailure(.unavailable)
                    listPresentation = nil
                    return
                }
                refreshFailed = true
                listPresentation?.setPagination(.refreshFailure)
            }
        }
        navigationTask = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        return true
    }

    private func confirmedPages(_ candidates: [ReadingPageLocator], query: ThreadReadingQuery,
                                generation: UInt64) async throws -> [(ReadingPageLocator, ThreadReaderSnapshot)] {
        var replacements: [(ReadingPageLocator, ThreadReaderSnapshot)] = []
        // Only already cached candidate pages are checked, never a walk from page 1.
        for old in candidates {
            try await validateConfirmationContext(generation)
            let locator = ReadingPageLocator(page: old.responsePage == 1 ? 0 : old.responsePage, postID: 0)
            let value = try await repository.loadPage(.init(threadID: threadID, pageNumber: locator.page, postID: 0, query: query))
            guard value.threadID == threadID, value.currentPage == locator.responsePage else {
                throw ThreadReaderLoadFailure.unavailable
            }
            replacements.append((locator, value))
        }
        try await validateConfirmationContext(generation)
        return replacements
    }

    private func validateConfirmationContext(_ generation: UInt64) async throws {
        try Task.checkCancellation()
        if let cacheTicket, let cache = repository as? any ReadingContentCacheAccess,
           await cache.isValid(cacheTicket) != true { throw CancellationError() }
        guard generation == nextGeneration, contentContext == cacheContext else { throw CancellationError() }
    }

}
