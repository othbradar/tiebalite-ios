import Foundation

actor CachedForumHomeRepository: ForumHomeCacheAccess, ForumContentPrefetching {
    private struct Manifest: Codable {
        let schemaVersion: Int
        let generation: String
        let fetchedAt: Date
        let pageKeys: [String]
        let anchor: Int64?
    }

    private let source: any ForumHomeRepository
    private let cache: ContentPageCache
    private let clock: any AppClock
    private let policy: ContentCachePolicy
    private let context: @MainActor @Sendable () -> ContentCacheContext
    private var preparationRevisions: [String: UInt64] = [:]
    private let scheduler: ContentLoadScheduler

    init(source: any ForumHomeRepository, cache: ContentPageCache, clock: any AppClock = SystemAppClock(),
         policy: ContentCachePolicy = .init(), scheduler: ContentLoadScheduler = ContentLoadScheduler(),
         context: @escaping @MainActor @Sendable () -> ContentCacheContext = { .anonymous }) {
        self.scheduler = scheduler
        self.source = source
        self.cache = cache
        self.clock = clock
        self.policy = policy
        self.context = context
    }

    @MainActor var cacheContext: ContentCacheContext { context() }

    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        if let restored = await restoreReading(request), restored.isFresh,
           let page = restored.pages.first(where: { $0.requestPage == request.pageNumber && $0.requestCursor == request.lastThreadID }) {
            return page.page.snapshot
        }
        let reading = try await fetchPage(request, continuing: nil)
        await saveReading(reading, request: request)
        guard let result = reading.snapshot else { throw ForumHomeLoadFailure.unavailable }
        return result
    }

    func restoreReading(_ request: ForumHomePageRequest) async -> ForumCachedReading? {
        let scope = await context()
        guard let namespace = scope.namespace else { return nil }
        let epoch = await cache.epoch
        let identity = await identity(request, namespace: namespace)
        let key = manifestKey(namespace: namespace, identity: identity)
        guard let data = await cache.read(key: key),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data), manifest.schemaVersion == 1,
              !manifest.pageKeys.isEmpty, manifest.pageKeys.count <= 10_000 else { return nil }
        var pages: [ForumCachedPage] = []
        for key in manifest.pageKeys {
            guard !Task.isCancelled, let data = await cache.read(key: key),
                  let page = try? JSONDecoder().decode(ForumCachedPage.self, from: data),
                  page.requestPage == pages.count + 1,
                  page.page.currentPage == page.requestPage,
                  pages.isEmpty || page.requestCursor == pages.last?.page.lastThreadID else { break }
            pages.append(page)
        }
        guard let first = pages.first, await context() == scope, await cache.epoch == epoch else { return nil }
        let age = await clock.now.timeIntervalSince(first.fetchedAt)
        guard age >= 0, age <= policy.maximumAge else {
            await cache.remove(key: key)
            for pageKey in manifest.pageKeys { await cache.remove(key: pageKey) }
            return nil
        }
        let allRestored = pages.count == manifest.pageKeys.count
        return ForumCachedReading(generation: manifest.generation,
                                  queryIdentity: ForumQueryIdentity(route: request.route, query: request.query),
                                  context: scope, cacheEpoch: epoch, pages: pages,
                                  anchor: allRestored ? manifest.anchor : nil, isFresh: age < policy.freshSeconds)
    }

    func fetchPage(_ request: ForumHomePageRequest, continuing: ForumCachedReading?) async throws -> ForumCachedReading {
        let scope = await context()
        let epoch = await cache.epoch
        if let continuing {
            guard continuing.context == scope, continuing.cacheEpoch == epoch,
                  continuing.queryIdentity == ForumQueryIdentity(route: request.route, query: request.query),
                  request.pageNumber == continuing.pages.count + 1,
                  request.lastThreadID == continuing.pages.last?.page.lastThreadID else { throw CancellationError() }
        }
        let page = try await requestPage(request, scope: scope, epoch: epoch, priority: .foreground)
        guard await context() == scope, await cache.epoch == epoch else { throw CancellationError() }
        var reading = continuing ?? ForumCachedReading(
            generation: UUID().uuidString,
            queryIdentity: ForumQueryIdentity(route: request.route, query: request.query), context: scope,
            cacheEpoch: epoch, pages: [], anchor: nil, isFresh: true)
        reading.pages.append(page)
        return reading
    }

    func invalidatePrefetch(_ request: ForumHomePageRequest) async {
        let scope = await context()
        guard let namespace = scope.namespace else { return }
        let identity = await identity(request, namespace: namespace)
        let key = manifestKey(namespace: namespace, identity: identity)
        let oldRevision = preparationRevisions[key, default: 0]
        preparationRevisions[key] = oldRevision &+ 1
        let oldPrepared = "prepared:\(scope.revision):\(await cache.epoch):\(oldRevision):" + key
            + ":\(request.pageNumber):\(request.lastThreadID)"
        await cache.remove(key: oldPrepared)
    }

    func prefetchForum(_ request: ForumHomePageRequest) async throws {
        if let reading = await restoreReading(request), reading.isFresh,
           reading.pages.contains(where: { $0.requestPage == request.pageNumber && $0.requestCursor == request.lastThreadID }) {
            await scheduler.cacheHit()
            return
        }
        let scope = await context()
        let epoch = await cache.epoch
        _ = try await requestPage(request, scope: scope, epoch: epoch, priority: .speculative)
        // Prepared pages deliberately do not replace the reading manifest, anchor or pagination chain.
    }

    private func requestPage(_ request: ForumHomePageRequest, scope: ContentCacheContext, epoch: UInt64,
                             priority: ContentLoadScheduler.Priority) async throws -> ForumCachedPage {
        guard let namespace = scope.namespace else { throw CancellationError() }
        let resolved = await identity(request, namespace: namespace)
        let identityKey = manifestKey(namespace: namespace, identity: resolved)
        let revision = preparationRevisions[identityKey, default: 0]
        let key = "\(scope.revision):\(epoch):\(revision):" + identityKey
            + ":\(request.pageNumber):\(request.lastThreadID)"
        let preparedKey = "prepared:" + key
        if let page = await preparedPage(preparedKey, scope: scope, epoch: epoch),
           preparationRevisions[identityKey, default: 0] == revision {
            if priority == .foreground { await cache.remove(key: preparedKey) }
            await scheduler.cacheHit()
            return page
        }
        let page: ForumCachedPage = try await scheduler.load(key: key, priority: priority) { [source, clock] in
            try Task.checkCancellation()
            guard await self.isCurrent(scope, epoch: epoch, key: identityKey, revision: revision) else { throw CancellationError() }
            // A completed flight may have filled the cache between the first lookup and admission.
            if let page = await self.preparedPage(preparedKey, scope: scope, epoch: epoch) {
                await self.scheduler.cacheHit()
                return page
            }
            await self.scheduler.sourceStarted(priority: priority)
            let snapshot = try await source.loadForumHomePage(request)
            try Task.checkCancellation()
            guard await self.isCurrent(scope, epoch: epoch, key: identityKey, revision: revision) else { throw CancellationError() }
            let page = ForumCachedPage(requestPage: request.pageNumber, requestCursor: request.lastThreadID,
                                       fetchedAt: await clock.now, page: ForumPageDTO(snapshot))
            if let data = try? JSONEncoder().encode(page) {
                await self.cache.write(data, key: preparedKey, epoch: epoch)
            }
            return page
        }
        try Task.checkCancellation()
        guard await context() == scope, await cache.epoch == epoch else { throw CancellationError() }
        guard preparationRevisions[identityKey, default: 0] == revision else { throw CancellationError() }
        if priority == .foreground { await cache.remove(key: preparedKey) }
        return page
    }

    private func preparedPage(_ key: String, scope: ContentCacheContext, epoch: UInt64) async -> ForumCachedPage? {
        guard let data = await cache.read(key: key),
              let page = try? JSONDecoder().decode(ForumCachedPage.self, from: data),
              await clock.now.timeIntervalSince(page.fetchedAt) < policy.freshSeconds,
              await context() == scope, await cache.epoch == epoch else { return nil }
        return page
    }

    private func isCurrent(_ scope: ContentCacheContext, epoch: UInt64, key: String, revision: UInt64) async -> Bool {
        guard await context() == scope, await cache.epoch == epoch else { return false }
        return preparationRevisions[key, default: 0] == revision
    }

    func saveReading(_ reading: ForumCachedReading, request: ForumHomePageRequest) async {
        guard let namespace = reading.context.namespace, let first = reading.pages.first,
              reading.queryIdentity == ForumQueryIdentity(route: request.route, query: request.query),
              await isValid(reading) else { return }
        let resolvedRoute = ForumRoute(forumID: first.page.forum.forumID, forumName: request.route.forumName.rawValue) ?? request.route
        let identity = ForumQueryIdentity(route: resolvedRoute, query: request.query)
        let prefix = manifestKey(namespace: namespace, identity: identity)
        var pageKeys: [String] = []
        for page in reading.pages {
            let key = prefix + ":\(reading.generation):\(page.requestPage):\(page.requestCursor)"
            pageKeys.append(key)
            guard await isValid(reading) else { return }
            if await cache.read(key: key) == nil, let data = try? JSONEncoder().encode(page) {
                await cache.write(data, key: key, epoch: reading.cacheEpoch)
            }
        }
        guard await isValid(reading) else { return }
        if let existing = await cache.read(key: prefix),
           let manifest = try? JSONDecoder().decode(Manifest.self, from: existing),
           manifest.fetchedAt > first.fetchedAt || (manifest.generation == reading.generation && manifest.pageKeys.count > pageKeys.count) {
            return
        }
        let manifest = Manifest(schemaVersion: 1, generation: reading.generation, fetchedAt: first.fetchedAt,
                                pageKeys: pageKeys, anchor: reading.anchor)
        if let data = try? JSONEncoder().encode(manifest) {
            await cache.write(data, key: prefix, epoch: reading.cacheEpoch)
        }
        if let id = first.page.forum.forumID, id > 0,
           request.route.forumID == nil || request.route.forumID?.rawValue == id {
            for name in [request.route.forumName.rawValue, first.page.forum.name] {
                let key = aliasKey(namespace: namespace, name: name)
                let previous = await cache.read(key: key).flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int64.init)
                let value = previous == nil || previous == id ? id : 0
                guard await isValid(reading) else { return }
                await cache.write(Data(String(value).utf8), key: key, epoch: reading.cacheEpoch)
            }
        }
        if !(await isValid(reading)) {
            await cache.remove(key: prefix)
            for key in pageKeys { await cache.remove(key: key) }
        }
    }

    private func isValid(_ reading: ForumCachedReading) async -> Bool {
        guard await context() == reading.context else { return false }
        return await cache.epoch == reading.cacheEpoch
    }

    private func identity(_ request: ForumHomePageRequest, namespace: String) async -> ForumQueryIdentity {
        if request.route.forumID == nil,
           let data = await cache.read(key: aliasKey(namespace: namespace, name: request.route.forumName.rawValue)),
           let value = String(data: data, encoding: .utf8).flatMap(Int64.init),
           let resolved = ForumRoute(forumID: value, forumName: request.route.forumName.rawValue) {
            return ForumQueryIdentity(route: resolved, query: request.query)
        }
        return ForumQueryIdentity(route: request.route, query: request.query)
    }

    private func manifestKey(namespace: String, identity: ForumQueryIdentity) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(identity)) ?? Data()
        return "forum-v1:\(namespace):" + ContentPageCache.digest(data)
    }

    private func aliasKey(namespace: String, name: String) -> String {
        "forum-alias-v1:\(namespace):" + ContentPageCache.digest(Data(ForumSortPreferences.normalizedName(name).utf8))
    }
}
