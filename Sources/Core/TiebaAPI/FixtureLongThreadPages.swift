#if DEBUG
/// Synthetic server responses for read-mode UI tests; production always queries PBPage.
enum FixtureLongThreadPages {
    static func page(seed: FixtureThreadSeed, request: ThreadReaderPageRequest) throws -> ThreadReaderSnapshot {
        let first = FixtureThreadReaderPages.firstPage(from: seed)
        let all = first.posts + (2...5).flatMap { FixtureThreadReaderPages.subsequentPage(from: seed, pageNumber: $0).posts }
        var seen = Set<Int64>()
        var replies = all.filter { $0.floorNumber != 1 && seen.insert($0.id.postID).inserted }
        if request.query.onlyAuthor {
            replies = replies.filter { $0.floorNumber.isMultiple(of: 5) }.map { post in
                ThreadReaderPost(floorNumber: post.floorNumber, author: seed.author, metadata: post.metadata,
                                 document: post.document)
            }
        }
        if request.query.order == .descending { replies.reverse() }
        if request.query.order == .hot {
            // Fixed synthetic ranking; production retains the server's response order.
            replies = replies.filter { $0.floorNumber.isMultiple(of: 3) }
                + replies.filter { !$0.floorNumber.isMultiple(of: 3) }
        }
        let page = max(1, request.pageNumber)
        let total = max(1, (replies.count + 14) / 15)
        guard page <= total else { throw FixtureReadingRepositoryError.unavailable }
        let slice = Array(replies.dropFirst((page - 1) * 15).prefix(15))
        let posts = (page == 1 ? Array(first.posts.prefix(1)) : []) + slice
        return .init(threadID: seed.threadID, title: seed.title, forumName: seed.forumName, forumID: 90,
                     author: seed.author, replyCount: seed.replyCount, posts: posts,
                     currentPage: page, totalPage: total, hasMore: page < total, nextPostID: page < total ? 0 : nil)
    }
}

#endif
