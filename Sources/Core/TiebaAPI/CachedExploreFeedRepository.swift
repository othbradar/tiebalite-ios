import Foundation

actor CachedExploreFeedRepository: ExploreFeedRepository {
    private let source: any ExplorePageLoading
    private let cache: ContentPageCache
    private let scheduler: ContentLoadScheduler
    private let clock: any AppClock
    private let context: @MainActor @Sendable () -> ContentCacheContext
    private var revisions: [String: UInt64] = [:]

    init(source: any ExplorePageLoading, cache: ContentPageCache, scheduler: ContentLoadScheduler = ContentLoadScheduler(),
         clock: any AppClock = SystemAppClock(), context: @escaping @MainActor @Sendable () -> ContentCacheContext) {
        self.source = source; self.cache = cache; self.scheduler = scheduler; self.clock = clock; self.context = context
    }

    func cached(_ feed: ExploreFeed, scope: ContentCacheContext) async -> ExploreCachedPage? {
        guard let key = key(feed, scope: scope), await context() == scope else { return nil }
        let epoch = await cache.epoch, revision = revisions[key, default: 0]
        guard let bytes = await cache.read(key: key),
              let record = try? JSONDecoder().decode(ExplorePageRecord.self, from: bytes) else { return nil }
        let age = await clock.now.timeIntervalSince(record.date)
        guard record.version == 1, age >= 0, age < 7 * 24 * 60 * 60,
              await cache.epoch == epoch, revisions[key, default: 0] == revision, await context() == scope,
              !Task.isCancelled else { return nil }
        await scheduler.cacheHit()
        return .init(page: record.page, isFresh: age < 60)
    }

    func load(_ feed: ExploreFeed, cursor: ExploreCursor?, scope: ContentCacheContext) async throws -> ExplorePage {
        guard let key = key(feed, scope: scope), await context() == scope else { throw CancellationError() }
        let epoch = await cache.epoch, revision = revisions[key, default: 0]
        let cursorKey = cursor.map { "\($0.requestUnix):\($0.pageTag)" } ?? "first"
        let flight = "\(key):\(scope.revision):\(epoch):\(revision):\(cursorKey)"
        let page = try await scheduler.load(key: flight, priority: .foreground) { [source, scheduler] in
            await scheduler.sourceStarted(priority: .foreground)
            return try await source.load(feed, cursor: cursor)
        }
        try Task.checkCancellation()
        guard await context() == scope, await cache.epoch == epoch,
              revisions[key, default: 0] == revision else { throw CancellationError() }
        // Store only consumed display fields, never the raw personalized response.
        let record = ExplorePageRecord(page: page, date: await clock.now)
        let bytes = try JSONEncoder().encode(record)
        guard await context() == scope, revisions[key, default: 0] == revision else { throw CancellationError() }
        let pageKey = cursor?.pageTag.isEmpty != false ? key : key + ":" + ContentPageCache.digest(Data(cursorKey.utf8))
        _ = await cache.write(bytes, key: pageKey, epoch: epoch)
        guard await context() == scope, await cache.epoch == epoch,
              revisions[key, default: 0] == revision else { throw CancellationError() }
        return page
    }

    func invalidate(_ feed: ExploreFeed, scope: ContentCacheContext) async {
        guard let key = key(feed, scope: scope) else { return }
        revisions[key, default: 0] &+= 1
        await cache.remove(key: key)
    }

    private func key(_ feed: ExploreFeed, scope: ContentCacheContext) -> String? {
        guard let namespace = scope.namespace, feed != .following || namespace != "anonymous" else { return nil }
        return "explore-v1:\(namespace):\(feed.rawValue):all"
    }
}

private struct ExplorePageRecord: Codable {
    let version: Int
    let date: Date
    let items: [Item]
    let next: ExploreCursor?
    let requestUnix: UInt64
    init(page: ExplorePage, date: Date) {
        version = 1; self.date = date; items = page.items.map(Item.init); next = page.next; requestUnix = page.requestUnix
    }
    var page: ExplorePage { .init(items: items.map(\.value), next: next, requestUnix: requestUnix) }

    struct Item: Codable {
        let thread: ForumPageDTO.Thread
        let forumID: Int64?
        let nodes: [ThreadContentNode]
        let showsTitle: Bool
        let totalMediaCount: Int
        let thumbnailResource: ImageResourceDescriptor?
        let thumbnailText: String?
        let forumAvatar: ImageResourceDescriptor?
        init(_ value: RecommendationSummary) {
            forumID = value.forumID; nodes = value.feed.abstractNodes; showsTitle = value.feed.showsTitle
            totalMediaCount = value.feed.totalMediaCount
            thumbnailResource = value.thumbnail?.resource; thumbnailText = value.thumbnail?.alternativeText
            forumAvatar = value.forumAvatarResource
            thread = .init(.init(itemID: value.threadID, threadID: value.threadID, title: value.title,
                                 summary: value.feed.abstractText, forumName: value.forumName, authorName: value.authorName,
                                 replyCount: value.replyCount, viewCount: 0, isPinned: false,
                                 mediaCount: value.mediaCount, thumbnailResources: value.mediaResources,
                                 author: value.author,
                                 metadata: .init(timeUnixSeconds: value.feed.timeUnixSeconds, agreeCount: value.feed.agreeCount,
                                                 shareCount: value.feed.shareCount)))
        }
        var value: RecommendationSummary {
            let row = thread.summary
            return .init(threadID: row.threadID, title: row.title, forumName: row.forumName, authorName: row.authorName,
                         replyCount: row.replyCount, thumbnail: thumbnailResource.map {
                            .init(resource: $0, alternativeText: thumbnailText ?? row.title)
                         },
                         author: row.author, forumID: forumID, forumAvatarResource: forumAvatar,
                         feed: .init(abstractText: row.summary ?? "", abstractNodes: nodes, showsTitle: showsTitle,
                                     timeUnixSeconds: row.metadata.timeUnixSeconds, media: row.thumbnailResources,
                                     totalMediaCount: totalMediaCount, agreeCount: row.metadata.agreeCount,
                                     shareCount: row.metadata.shareCount))
        }
    }
}
