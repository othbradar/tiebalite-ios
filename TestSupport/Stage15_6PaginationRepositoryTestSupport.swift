#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
actor Stage156NoProgressThreadRepository: ThreadReaderRepository {
    private let base = FixtureThreadReaderRepository()
    private var recordedRequests: [ThreadReaderPageRequest] = []
    private var firstPage: ThreadReaderSnapshot?

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        recordedRequests.append(request)
        if request.pageNumber == 0 {
            let page = try await base.loadPage(request)
            let zeroCursor = ThreadReaderSnapshot(
                threadID: page.threadID,
                title: page.title,
                forumName: page.forumName,
                author: page.author,
                replyCount: page.replyCount,
                posts: page.posts,
                currentPage: page.currentPage,
                totalPage: page.totalPage,
                hasMore: true,
                nextPostID: 0
            )
            firstPage = zeroCursor
            return zeroCursor
        }
        guard request.pageNumber == 2,
              let firstPage else {
            throw FixtureReadingRepositoryError.unavailable
        }
        return ThreadReaderSnapshot(
            threadID: firstPage.threadID,
            title: firstPage.title,
            forumName: firstPage.forumName,
            author: firstPage.author,
            replyCount: firstPage.replyCount,
            posts: firstPage.posts,
            currentPage: 2,
            totalPage: firstPage.totalPage,
            hasMore: true,
            nextPostID: 0
        )
    }

    func requests() -> [ThreadReaderPageRequest] {
        recordedRequests
    }
}
#endif
