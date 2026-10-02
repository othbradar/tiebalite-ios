import Foundation

actor CachedForumHomeRepository: ForumHomeCacheAccess {
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
    private var inFlight: [String: Task<ForumCachedReading, Error>] = [:]

    init(source: any ForumHomeRepository, cache: ContentPageCache, clock: any AppClock = SystemAppClock(),
         policy: ContentCachePolicy = .init(),
         context: @escaping @MainActor @Sendable () -> ContentCacheContext = { .anonymous }) {
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
        let key = "\(scope.namespace ?? "disabled"):\(scope.revision):\(epoch):"
            + manifestKey(namespace: "flight", identity: ForumQueryIdentity(route: request.route, query: request.query))
            + ":\(request.pageNumber):\(request.lastThreadID):\(continuing?.generation ?? "first")"
        if let task = inFlight[key] {
            let reading = try await task.value
            guard await isValid(reading) else { throw CancellationError() }
            return reading
        }
        let task = Task { [source, clock] in
            let page = try await source.loadForumHomePage(request)
            try Task.checkCancellation()
            let cached = ForumCachedPage(requestPage: request.pageNumber, requestCursor: request.lastThreadID,
                                         fetchedAt: await clock.now, page: ForumPageDTO(page))
            var reading = continuing ?? ForumCachedReading(generation: UUID().uuidString,
                                                           queryIdentity: ForumQueryIdentity(route: request.route, query: request.query),
                                                           context: scope,
                                                           cacheEpoch: epoch, pages: [], anchor: nil, isFresh: true)
            reading.pages.append(cached)
            return reading
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let result = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
        guard await context() == scope, await cache.epoch == epoch else { throw CancellationError() }
        return result
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
