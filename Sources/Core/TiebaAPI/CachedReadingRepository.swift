import Foundation

/// Page/progress adapter over the same bounded byte store used by forum pages.
actor CachedReadingRepository: ReadingContentCacheAccess, ThreadContentPrefetching {
    private struct Record: Codable, Sendable {
        let locator: ReadingPageLocator
        let key: String
        let fetchedAt: Date
    }
    private struct PendingPage: Sendable {
        let locator: ReadingPageLocator
        let fetchedAt: Date
        let data: Data
    }
    private struct FetchScope: Sendable {
        let ticket: ReadingCacheTicket
        let key: String
        let revision: UInt64
        let useCache: Bool
        let priority: ContentLoadScheduler.Priority
    }
    private struct ReplyRecord: Codable, Sendable {
        let key: String
        let fetchedAt: Date
    }
    private struct Manifest: Codable, Sendable {
        var records: [Record] = []
        var position: ReadingPosition?
        var replyRecord: ReplyRecord?
    }

    private let threads: any ThreadReaderRepository
    private let subposts: any SubpostsRepository
    private let scheduler: ContentLoadScheduler
    private let cache: ContentPageCache
    private let clock: any AppClock
    private let context: @MainActor @Sendable () -> ContentCacheContext
    private let policy: ContentCachePolicy
    private var writes: [String: Task<Void, Never>] = [:]
    private var writeIDs: [String: UInt64] = [:]
    private var nextWriteID: UInt64 = 0
    private var revocations: [String: UInt64] = [:]

    @MainActor var cacheContext: ContentCacheContext { context() }

    init(threads: any ThreadReaderRepository, subposts: any SubpostsRepository, cache: ContentPageCache,
         clock: any AppClock = SystemAppClock(), scheduler: ContentLoadScheduler = ContentLoadScheduler(),
         policy: ContentCachePolicy = .init(),
         context: @escaping @MainActor @Sendable () -> ContentCacheContext = { .anonymous }) {
        self.scheduler = scheduler
        self.threads = threads
        self.subposts = subposts
        self.cache = cache
        self.clock = clock
        self.policy = policy
        self.context = context
    }

    func ticket() async -> ReadingCacheTicket {
        .init(context: await context(), epoch: await cache.epoch)
    }

    func isValid(_ ticket: ReadingCacheTicket) async -> Bool {
        guard ticket.context.namespace != nil, await context() == ticket.context else { return false }
        return await cache.epoch == ticket.epoch
    }

    func restoreThread(_ threadID: Int64) async -> CachedReading<ThreadReaderSnapshot>? {
        let identity = ReadingCacheIdentity(threadID: threadID)
        guard var reading: CachedReading<ThreadReaderSnapshot> = await restore(identity),
              let key = key(identity, ticket: reading.ticket) else { return nil }
        reading.replyPosts = await replyPosts((await manifest(key)).replyRecord)
        return await isValid(reading.ticket) ? reading : nil
    }

    func restoreSubposts(_ route: SubpostsRoute) async -> CachedReading<SubpostsPage>? {
        await restore(.init(threadID: route.threadID, parentPostID: route.postID))
    }

    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        try await threadPage(request, useCache: true)
    }

    func prefetchThread(_ request: ThreadReaderPageRequest) async throws {
        _ = try await threadPage(request, useCache: true, priority: .speculative)
    }

    func refreshThread(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        let ticket = await ticket()
        if let key = key(.init(threadID: request.threadID), ticket: ticket) { revocations[key, default: 0] &+= 1 }
        return try await threadPage(request, useCache: false)
    }

    func loadPage(route: SubpostsRoute, page: Int) async throws -> SubpostsPage {
        try await subpostsPage(route, page: page, useCache: true)
    }

    func refreshSubposts(_ route: SubpostsRoute, page: Int) async throws -> SubpostsPage {
        try await subpostsPage(route, page: page, useCache: false)
    }

    func checkpoint(_ position: ReadingPosition, ticket: ReadingCacheTicket) async {
        await enqueue(position.identity, ticket: ticket, position: position)
    }

    func mergeReplyPosts(_ update: ReplyPostUpdate, ticket: ReadingCacheTicket) async {
        let identity = ReadingCacheIdentity(threadID: update.threadID)
        guard !update.posts.isEmpty, await isValid(ticket), let key = key(identity, ticket: ticket) else { return }
        revocations[key, default: 0] &+= 1
        await enqueue(identity, ticket: ticket, replies: update)
    }

    func mergeReplyPage(_ page: ThreadReaderSnapshot, ticket: ReadingCacheTicket) async -> ReadingPageLocator? {
        let identity = ReadingCacheIdentity(threadID: page.threadID)
        guard page.currentPage > 0, !page.posts.isEmpty, !page.hasRevokedFirstPost,
              await isValid(ticket), let key = key(identity, ticket: ticket) else { return nil }
        // A pre-send page fetch must not subsequently overwrite the accepted reply.
        revocations[key, default: 0] &+= 1
        await writes[key]?.value
        let existing = await manifest(key)
        let record = existing.records.first { $0.locator.responsePage == page.currentPage }
        let locator = record?.locator ?? .init(page: page.currentPage, postID: page.posts.last?.id.postID ?? 0)
        var merged = page
        if let record, let bytes = await cache.read(key: record.key),
           let old = try? JSONDecoder().decode(CachedReadingPage<ThreadReaderSnapshot>.self, from: bytes) {
            merged = ReplyPageMerge.merge(old.value, page: page, pagination: page)
        }
        guard !Task.isCancelled, await isValid(ticket) else { return nil }
        let now = await clock.now
        let value = CachedReadingPage(locator: locator, fetchedAt: now, value: merged)
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        await enqueue(identity, ticket: ticket, page: .init(locator: locator, fetchedAt: now, data: data))
        return await isValid(ticket) ? locator : nil
    }

    private func threadPage(_ request: ThreadReaderPageRequest, useCache: Bool,
                            priority: ContentLoadScheduler.Priority = .foreground) async throws -> ThreadReaderSnapshot {
        let identity = ReadingCacheIdentity(threadID: request.threadID)
        let locator = ReadingPageLocator(page: request.pageNumber, postID: request.postID)
        return try await fetch(identity, locator: locator, useCache: useCache, priority: priority) { [threads] in
            let page = try await threads.loadPage(request)
            guard page.threadID == request.threadID, page.currentPage == locator.responsePage else {
                throw EndpointExecutionError.mapping
            }
            guard !page.hasRevokedFirstPost else { throw ReadingContentRevoked() }
            return page
        }
    }

    private func subpostsPage(_ route: SubpostsRoute, page: Int, useCache: Bool) async throws -> SubpostsPage {
        let identity = ReadingCacheIdentity(threadID: route.threadID, parentPostID: route.postID)
        return try await fetch(identity, locator: .init(page: page, postID: route.postID), useCache: useCache) { [subposts] in
            let value = try await subposts.loadPage(route: route, page: page)
            guard value.route == route, value.pageNumber == page, page > 1 || value.parent != nil else {
                throw EndpointExecutionError.mapping
            }
            return value
        }
    }

    private func fetch<Page: Codable & Sendable>(
        _ identity: ReadingCacheIdentity, locator: ReadingPageLocator, useCache: Bool,
        priority: ContentLoadScheduler.Priority = .foreground,
        load: @escaping @Sendable () async throws -> Page
    ) async throws -> Page {
        let ticket = await ticket()
        guard await isValid(ticket), let key = key(identity, ticket: ticket) else { throw EndpointExecutionError.authentication }
        let revision = revocations[key, default: 0]
        if useCache, let page: Page = await cachedPage(identity, locator: locator, ticket: ticket) {
            await scheduler.cacheHit()
            return page
        }
        let flightKey = "\(key)|\(ticket.context.revision)|\(ticket.epoch)|\(revision)|\(locator.page)|\(locator.postID)"
        let scope = FetchScope(ticket: ticket, key: key, revision: revision, useCache: useCache, priority: priority)
        return try await scheduler.load(key: flightKey, priority: priority) {
            try await self.fetchAndSave(identity, locator: locator, scope: scope, load: load)
        }
    }

    private func fetchAndSave<Page: Codable & Sendable>(
        _ identity: ReadingCacheIdentity, locator: ReadingPageLocator, scope: FetchScope,
        load: @Sendable () async throws -> Page
    ) async throws -> Page {
        let (ticket, key, revision) = (scope.ticket, scope.key, scope.revision)
        let (useCache, priority) = (scope.useCache, scope.priority)
        if useCache, let page: Page = await cachedPage(identity, locator: locator, ticket: ticket) {
            await scheduler.cacheHit()
            return page
        }
        do {
            try Task.checkCancellation()
            guard await isValid(ticket), revocations[key, default: 0] == revision else { throw CancellationError() }
            await scheduler.sourceStarted(priority: priority)
            let page = try await load()
            try Task.checkCancellation()
            guard await isValid(ticket), revocations[key, default: 0] == revision else { throw CancellationError() }
            if priority == .speculative {
                let existing = await manifest(key)
                // A speculative refresh cannot invalidate the locator/chain used by a saved reading session.
                if existing.records.contains(where: { $0.locator.responsePage == locator.responsePage && $0.locator != locator }) {
                    return page
                }
            }
            let record = CachedReadingPage(locator: locator, fetchedAt: await clock.now, value: page)
            if let data = try? JSONEncoder().encode(record) {
                await enqueue(identity, ticket: ticket, page: .init(locator: locator, fetchedAt: record.fetchedAt, data: data))
            }
            guard await isValid(ticket) else { throw CancellationError() }
            return page
        } catch {
            if priority == .foreground, ReadingContentRevoked.isConfirmed(error) {
                revocations[key, default: 0] &+= 1
                await enqueue(identity, ticket: ticket, invalidate: true)
            }
            throw error
        }
    }

    private func cachedPage<Page: Codable & Sendable>(
        _ identity: ReadingCacheIdentity, locator: ReadingPageLocator, ticket: ReadingCacheTicket
    ) async -> Page? {
        guard let key = key(identity, ticket: ticket) else { return nil }
        await writes[key]?.value
        let manifest = await manifest(key)
        guard let record = manifest.records.first(where: { $0.locator == locator }),
              await clock.now.timeIntervalSince(record.fetchedAt) < 300,
              let data = await cache.read(key: record.key),
              let page = try? JSONDecoder().decode(CachedReadingPage<Page>.self, from: data),
              page.locator == locator, await isValid(ticket) else { return nil }
        return page.value
    }

    /// Restore only an actual contiguous run containing the reading page. A missing earlier page
    /// never causes a sequential network walk to the old position, nor changes the wire hasMore flag.
    func restore<Page: Codable & Sendable>(_ identity: ReadingCacheIdentity) async -> CachedReading<Page>? {
        let ticket = await ticket()
        guard let key = key(identity, ticket: ticket), await isValid(ticket) else { return nil }
        await writes[key]?.value
        let manifest = await manifest(key)
        let now = await clock.now
        var runs: [[CachedReadingPage<Page>]] = []
        for record in manifest.records.sorted(by: { $0.locator.responsePage < $1.locator.responsePage }) {
            guard now.timeIntervalSince(record.fetchedAt) <= policy.maximumAge,
                  let data = await cache.read(key: record.key),
                  let page = try? JSONDecoder().decode(CachedReadingPage<Page>.self, from: data),
                  page.locator == record.locator, page.fetchedAt == record.fetchedAt else { continue }
            if let last = runs.last?.last, last.locator.responsePage + 1 == page.locator.responsePage {
                runs[runs.count - 1].append(page)
            } else { runs.append([page]) }
        }
        guard await isValid(ticket), let pages = runs.first(where: { run in
            run.contains { $0.locator == manifest.position?.locator }
        }) ?? runs.first else { return nil }
        let position = manifest.position.flatMap { position in
            pages.contains { $0.locator == position.locator } ? position : nil
        }
        await scheduler.cacheHit()
        return .init(pages: pages, position: position, ticket: ticket,
                     isFresh: pages.allSatisfy { now.timeIntervalSince($0.fetchedAt) < 300 })
    }

    private func key(_ identity: ReadingCacheIdentity, ticket: ReadingCacheTicket) -> String? {
        ticket.context.namespace.map { "\($0)|\(identity.key)" }
    }

    private func manifest(_ key: String) async -> Manifest {
        guard let data = await cache.read(key: key),
              let value = try? JSONDecoder().decode(Manifest.self, from: data) else { return .init() }
        return value
    }

    /// Serializes tiny manifest updates, including progress versus an in-flight page append.
    /// Successful pages are encoded once; scrolling only encodes the manifest's references/position.
    private func enqueue(_ identity: ReadingCacheIdentity, ticket: ReadingCacheTicket,
                         page: PendingPage? = nil,
                         position: ReadingPosition? = nil, invalidate: Bool = false, replies: ReplyPostUpdate? = nil) async {
        guard let key = key(identity, ticket: ticket) else { return }
        let previous = writes[key]
        nextWriteID &+= 1
        let writeID = nextWriteID
        writeIDs[key] = writeID
        let operation = Task {
            await previous?.value
            await self.commit(key: key, ticket: ticket, page: page, position: position, mutation: (invalidate, replies))
        }
        writes[key] = operation
        await operation.value
        if writeIDs[key] == writeID { writes[key] = nil; writeIDs[key] = nil }
    }

    private func commit(key: String, ticket: ReadingCacheTicket, page: PendingPage?,
                        position: ReadingPosition?, mutation: (invalidate: Bool, replies: ReplyPostUpdate?)) async {
        let (invalidate, replies) = mutation
        guard await isValid(ticket) else { return }
        var manifest = await manifest(key)
        guard await isValid(ticket) else { return }
        if invalidate {
            for record in manifest.records { await cache.remove(key: record.key) }
            if let record = manifest.replyRecord { await cache.remove(key: record.key) }
            await cache.remove(key: key)
            return
        }
        if let page {
            let (locator, fetchedAt) = (page.locator, page.fetchedAt)
            let data = page.data
            let pageKey = "\(key)|pn:\(locator.page)|pid:\(locator.postID)|\(ContentPageCache.digest(data))"
            guard await cache.write(data, key: pageKey, epoch: ticket.epoch), await isValid(ticket) else { return }
            let replaced = manifest.records.filter { $0.locator.responsePage == locator.responsePage }
            manifest.records.removeAll { $0.locator.responsePage == locator.responsePage }
            manifest.records.append(.init(locator: locator, key: pageKey, fetchedAt: fetchedAt))
            for old in replaced where old.key != pageKey { await cache.remove(key: old.key) }
            // References are bounded even when the disk LRU has already evicted their page data.
            manifest.records = Array(manifest.records.sorted { $0.fetchedAt > $1.fetchedAt }.prefix(512))
        }
        manifest.replyRecord = await commitReplies(replies, page: page, existing: manifest.replyRecord, key: key, ticket: ticket)
        if let position, manifest.records.contains(where: { $0.locator == position.locator }) {
            manifest.position = position
        }
        guard await isValid(ticket), let data = try? JSONEncoder().encode(manifest) else { return }
        await cache.write(data, key: key, epoch: ticket.epoch)
    }
}

private extension CachedReadingRepository {
    private func replyPosts(_ record: ReplyRecord?) async -> ReplyPostUpdate? {
        guard let record, await clock.now.timeIntervalSince(record.fetchedAt) <= policy.maximumAge,
              let data = await cache.read(key: record.key) else { return nil }
        return try? JSONDecoder().decode(ReplyPostUpdate.self, from: data)
    }

    private func commitReplies(_ incoming: ReplyPostUpdate?, page: PendingPage?, existing: ReplyRecord?,
                               key: String, ticket: ReadingCacheTicket) async -> ReplyRecord? {
        guard incoming != nil || page != nil else { return existing }
        guard incoming != nil || existing != nil else { return nil }
        var update = await replyPosts(existing)
        if let incoming { update = update?.merging(incoming) ?? incoming }
        // An authoritative normal page supersedes matching delta rows. A delta
        // itself is never assigned a page number or used as a pagination cursor.
        if let page, let value = try? JSONDecoder().decode(CachedReadingPage<ThreadReaderSnapshot>.self, from: page.data) {
            update = update?.removing(Set(value.value.posts.map(\.id.postID)))
        }
        guard let update else {
            if let existing { await cache.remove(key: existing.key) }
            return nil
        }
        guard await isValid(ticket), let data = try? JSONEncoder().encode(update) else { return existing }
        let replyKey = "\(key)|reply-delta|\(ContentPageCache.digest(data))"
        guard await cache.write(data, key: replyKey, epoch: ticket.epoch), await isValid(ticket) else { return existing }
        if let existing, existing.key != replyKey { await cache.remove(key: existing.key) }
        let now = await clock.now
        return .init(key: replyKey, fetchedAt: incoming != nil ? now : (existing?.fetchedAt ?? now))
    }
}
