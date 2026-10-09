/// A receipt-directed response can update one page without claiming that every
/// page between the current reader and that response has been loaded.
enum ReplyPageMerge {
    static func mergeReadPage(_ retained: ThreadReaderSnapshot, page: ThreadReaderSnapshot) -> ThreadReaderSnapshot {
        let tail = page.currentPage == retained.currentPage || page.currentPage == retained.currentPage + 1 ? page : retained
        return merge(retained, page: page, pagination: tail)
    }

    static func applying(_ update: ReplyPostUpdate?, to retained: ThreadReaderSnapshot) -> ThreadReaderSnapshot {
        guard let update, update.threadID == retained.threadID else { return retained }
        let content = ThreadReaderSnapshot(
            threadID: retained.threadID, title: retained.title, forumName: retained.forumName, forumID: retained.forumID,
            forumAvatarResource: retained.forumAvatarResource, author: retained.author,
            replyCount: update.replyCount, posts: update.posts, currentPage: retained.currentPage,
            totalPage: retained.totalPage, hasMore: retained.hasMore, nextPostID: retained.nextPostID)
        return merge(retained, page: content, pagination: retained)
    }

    static func merge(_ retained: ThreadReaderSnapshot, page: ThreadReaderSnapshot,
                      pagination: ThreadReaderSnapshot? = nil) -> ThreadReaderSnapshot {
        guard retained.threadID == page.threadID else { return retained }
        let replacements = Dictionary(page.posts.map { ($0.id.postID, $0) }, uniquingKeysWith: { _, new in new })
        var seen = Set<Int64>()
        var posts = (retained.posts.map { replacements[$0.id.postID] ?? $0 } + page.posts)
            .filter { seen.insert($0.id.postID).inserted }
        if posts.allSatisfy({ $0.floorNumber > 0 }) { posts.sort { $0.floorNumber < $1.floorNumber } }
        let tail = pagination ?? retained
        return .init(threadID: retained.threadID, title: page.title, forumName: page.forumName,
                     forumID: page.forumID ?? retained.forumID,
                     forumAvatarResource: page.forumAvatarResource ?? retained.forumAvatarResource,
                     author: page.author, replyCount: page.replyCount, posts: posts,
                     currentPage: tail.currentPage, totalPage: page.totalPage ?? tail.totalPage,
                     hasMore: tail.hasMore, nextPostID: tail.nextPostID)
    }
}

extension ReplyPageMerge {
    static func replacingPosts(in retained: ThreadReaderSnapshot, with page: ThreadReaderSnapshot) -> ThreadReaderSnapshot {
        var byID: [Int64: ThreadReaderPost] = [:]
        for post in page.posts { byID[post.id.postID] = post }
        var seen = Set<Int64>()
        let posts = (retained.posts.map { byID[$0.id.postID] ?? $0 } + page.posts).filter { seen.insert($0.id.postID).inserted }
        return snapshot(metadata: page, pagination: retained, posts: posts)
    }

    static func snapshot(metadata: ThreadReaderSnapshot, pagination: ThreadReaderSnapshot,
                         posts: [ThreadReaderPost]) -> ThreadReaderSnapshot {
        .init(threadID: metadata.threadID, title: metadata.title, forumName: metadata.forumName,
              forumID: metadata.forumID, forumAvatarResource: metadata.forumAvatarResource,
              author: metadata.author, replyCount: metadata.replyCount, posts: posts,
              currentPage: pagination.currentPage, totalPage: pagination.totalPage,
              hasMore: pagination.hasMore, nextPostID: pagination.nextPostID)
    }
}
