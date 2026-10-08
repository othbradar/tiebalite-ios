import Foundation
import Testing
@testable import TiebaLite

/// User explicitly withdrew the U08 tail/parent/dirty-page protocol in favor of beta3.
@MainActor
struct U08ReplyTests {
    @Test(arguments: [false, true])
    func beta3ReloadKeepsThreePagesAndAnchorWithoutFollowingNewPage(crossesPage: Bool) async throws {
        let source = U08PublishedReplySource(crossesPage: crossesPage)
        let cache = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: ContentPageCache(directory: nil))
        let original = ThreadReaderStore(threadID: 140_006, repository: cache)
        await original.loadIfNeeded()
        await original.loadNextPage()
        await original.loadNextPage()
        let anchor = try #require(original.listPresentation?.rows.last { $0.id.isPost }?.id)
        original.setReadAnchor(anchor)
        await original.saveReadingPosition()
        let store = ThreadReaderStore(threadID: 140_006, repository: cache)
        await store.loadIfNeeded()
        #expect(store.isShowingCachedContent && store.readAnchor == anchor)
        let before = try #require(store.state.snapshot).posts.map(\.id)
        await source.publish()
        // The exact beta3 success callback invokes the ordinary current-page reload once.
        await store.reload()
        #expect(store.state.snapshot?.posts.contains { $0.id.postID == 999_999 } == !crossesPage)
        #expect(Set(before).isSubset(of: Set(store.state.snapshot?.posts.map(\.id) ?? [])))
        #expect(store.readAnchor == anchor)
        #expect(!store.isShowingCachedContent)
        #expect(await source.requests == [0, 2, 3, 3])
        #expect(await cache.restoreThread(140_006)?.pages.count == 3)
    }

    @Test func beta3ReloadUsesVisiblePageAndFailureKeepsReadingContext() async throws {
        let source = U08ThreadSource()
        let cache = CachedReadingRepository(threads: source, subposts: FixtureSubpostsRepository(), cache: ContentPageCache(directory: nil))
        let store = ThreadReaderStore(threadID: 140_006, repository: cache)
        await store.loadIfNeeded()
        // The fixture repeats boundary floors across pages; use the unique first post.
        let anchor = try #require(store.listPresentation?.rows.first { $0.id.isPost }?.id)
        await store.loadNextPage()
        await store.loadNextPage()
        store.setReadAnchor(anchor)
        let before = store.state.snapshot
        await store.reload()
        #expect(await source.requests.map(\.pageNumber) == [0, 2, 3, 0])
        #expect(store.state.snapshot?.posts.map(\.id) == before?.posts.map(\.id))
        #expect(store.readAnchor == anchor)
        await source.failNext()
        await store.reload()
        #expect(store.refreshFailed && store.readAnchor == anchor)
        #expect(store.state.snapshot?.posts.map(\.id) == before?.posts.map(\.id))
        let requestsAfterFailure = await source.requests.map(\.pageNumber)
        #expect(requestsAfterFailure == [0, 2, 3, 0, 0])
    }

    @Test func beta3SubpostsRefreshesCurrentPageOnceAndRetainsLoadedTail() async throws {
        let source = U08SubpostSource()
        let route = SubpostsRoute(threadID: 140_006, postID: 160_006)
        let store = SubpostsStore(route: route, repository: source)
        await store.loadIfNeeded()
        let first = try #require(store.snapshot?.items.first)
        await store.loadNextPage()
        store.setReadAnchor(.reply(first.id))
        let before = try #require(store.snapshot).items.map(\.id)
        await source.publish()
        await store.refresh()
        #expect(store.readAnchor == .reply(first.id))
        #expect(store.snapshot?.items.map(\.id) == before)
        #expect(await source.requests == [1, 2, 1])
    }

    @Test func unknownOutcomeRetainsDraftAndNeverAutomaticallyResends() async {
        let context = AuthContext.active(.init(sessionID: .init(rawValue: 8), generation: 1))
        let writer = U08UnknownWriter()
        let target = TextComposeTarget(kind: .threadReply, forumID: 42, forumName: "样本", threadID: 101)
        let store = TextComposerStore(target: target, repository: writer, context: context, currentContext: { context })
        store.draft.content = "保留#(滑稽)"
        await store.send()
        store.cancelPending()
        #expect(store.failure == .resultUnknown && store.receipt == nil)
        #expect(store.draft.content == "保留#(滑稽)")
        #expect(await writer.count == 1)
    }

}

private actor U08SubpostSource: SubpostsRepository {
    var requests: [Int] = []
    private var published = false
    func publish() { published = true }
    func loadPage(route: SubpostsRoute, page: Int) async throws -> SubpostsPage {
        requests.append(page)
        let base = try await FixtureSubpostsRepository().loadPage(route: route, page: page)
        var items = base.items
        if published, page == 2, let author = items.first?.author {
            let source = ThreadContentSource(threadID: route.threadID, postID: 99_999, scope: .subPost)
            items.append(.init(author: author, document: .init(source: source, availability: .available, nodes: [], poll: nil),
                               createdAt: nil, agreeCount: 0))
        }
        return .init(route: route, parent: base.parent, threadAuthorID: base.threadAuthorID, forumID: base.forumID,
                     forumName: base.forumName, items: items, pageNumber: page, totalPages: 2, totalCount: items.count)
    }
}

private actor U08PublishedReplySource: ThreadReaderRepository {
    let crossesPage: Bool
    var requests: [Int] = []
    private var published = false
    init(crossesPage: Bool) { self.crossesPage = crossesPage }
    func publish() { published = true }
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        requests.append(request.pageNumber)
        let base = try await FixtureThreadReaderRepository().loadPage(request)
        let targetPage = crossesPage ? 4 : 3
        var posts = base.posts
        if published, base.currentPage == targetPage {
            let source = ThreadContentSource(threadID: base.threadID, postID: 999_999, scope: .post)
            let node = ThreadContentNode(id: .init(source: source, ordinal: 0), rawType: 0,
                                         payload: .text(.init(value: "服务端已返回的新回复")))
            posts.append(.init(floorNumber: 99, author: base.author, metadata: "Fixture",
                               document: .init(source: source, availability: .available, nodes: [node], poll: nil)))
        }
        let lastPage = published ? targetPage : 3
        return .init(threadID: base.threadID, title: base.title, forumName: base.forumName, forumID: base.forumID,
                     author: base.author, replyCount: base.replyCount, posts: posts, currentPage: base.currentPage,
                     totalPage: lastPage, hasMore: base.currentPage < lastPage,
                     nextPostID: base.currentPage < lastPage ? base.nextPostID : nil)
    }
}

private actor U08ThreadSource: ThreadReaderRepository {
    var requests: [ThreadReaderPageRequest] = []
    private var fails = false
    func failNext() { fails = true }
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        requests.append(request)
        if fails { throw EndpointExecutionError.transport(.offline) }
        return try await FixtureThreadReaderRepository().loadPage(request)
    }
}

private actor U08UnknownWriter: TextWriteRepository {
    var count = 0
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        count += 1
        throw TextWriteFailure.resultUnknown
    }
}
