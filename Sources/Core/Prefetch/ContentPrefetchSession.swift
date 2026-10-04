import Foundation

struct ThreadPagePrefetchIdentity {
    let threadID: Int64
    let page: Int
    let postID: Int64
    let context: ContentCacheContext
    let generation: UInt64

    var key: String { "thread:\(threadID):\(page):\(postID):\(context):\(generation)" }
}

/// Receives a small candidate window from a page. It never owns displayed state or reading progress.
@MainActor
final class ContentPrefetchSession {
    private let candidates: ContentPrefetchScope
    private let nextPage: ContentPrefetchScope
    private let threads: (any ThreadContentPrefetching)?
    private let forums: (any ForumContentPrefetching)?
    private let sort: (ForumRoute) -> ForumSortOrder

    init(candidates: ContentPrefetchScope, nextPage: ContentPrefetchScope,
         threads: (any ThreadContentPrefetching)?, forums: (any ForumContentPrefetching)?,
         sort: @escaping (ForumRoute) -> ForumSortOrder) {
        self.candidates = candidates
        self.nextPage = nextPage
        self.threads = threads
        self.forums = forums
        self.sort = sort
    }

    func nearbyThreads(_ ids: [Int64]) {
        guard let threads else { return }
        var seen = Set<Int64>()
        let ids = ids.filter { $0 > 0 && seen.insert($0).inserted }.prefix(2)
        candidates.submit(ids.map { id in ("thread:\(id)", { @Sendable in try await threads.prefetchThread(.initial(threadID: id)) }) })
    }

    func nearbyForums(_ routes: [ForumRoute]) {
        guard let forums else { return }
        candidates.submit(routes.prefix(2).map { route in
            let request = ForumHomePageRequest(route: route, query: .latest(sort(route)))
            return (forumKey(request), { @Sendable in try await forums.prefetchForum(request) })
        })
    }

    func followingThreadPage(_ identity: ThreadPagePrefetchIdentity, makeRequest: () -> ThreadReaderPageRequest) {
        guard let threads else { return }
        nextPage.submitOne(key: identity.key) {
            let request = makeRequest()
            return { try await threads.prefetchThread(request) }
        }
    }

    func followingForumPage(_ request: ForumHomePageRequest) {
        guard let forums else { return }
        nextPage.submit([(forumKey(request), { @Sendable in try await forums.prefetchForum(request) })])
    }

    func cancel() { candidates.cancel(); nextPage.cancel() }

    private func forumKey(_ request: ForumHomePageRequest) -> String {
        let identity = ForumQueryIdentity(route: request.route, query: request.query)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return ContentPageCache.digest((try? encoder.encode(identity)) ?? Data()) + ":\(request.pageNumber):\(request.lastThreadID)"
    }
}
