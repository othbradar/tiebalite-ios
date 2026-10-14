import Foundation

enum ExploreFeed: String, Codable, CaseIterable, Sendable {
    case following, hot
    var title: String { self == .following ? "关注" : "热榜" }
}

struct ExploreCursor: Codable, Equatable, Sendable {
    let pageTag: String
    let requestUnix: UInt64
}

struct ExplorePage: Equatable, Sendable {
    let items: [RecommendationSummary]
    let next: ExploreCursor?
    let requestUnix: UInt64
    init(items: [RecommendationSummary], next: ExploreCursor?, requestUnix: UInt64 = 0) {
        self.items = items; self.next = next; self.requestUnix = requestUnix
    }
}

struct ExploreCachedPage: Sendable {
    let page: ExplorePage
    let isFresh: Bool
}

enum ExploreFailure: Error { case loginRequired, invalidData }

protocol ExploreFeedRepository: Sendable {
    func cached(_ feed: ExploreFeed, scope: ContentCacheContext) async -> ExploreCachedPage?
    func load(_ feed: ExploreFeed, cursor: ExploreCursor?, scope: ContentCacheContext) async throws -> ExplorePage
    func invalidate(_ feed: ExploreFeed, scope: ContentCacheContext) async
}

struct UnavailableExploreRepository: ExploreFeedRepository {
    func cached(_ feed: ExploreFeed, scope: ContentCacheContext) async -> ExploreCachedPage? { nil }
    func load(_ feed: ExploreFeed, cursor: ExploreCursor?, scope: ContentCacheContext) async throws -> ExplorePage {
        throw ExploreFailure.invalidData
    }
    func invalidate(_ feed: ExploreFeed, scope: ContentCacheContext) async {}
}
