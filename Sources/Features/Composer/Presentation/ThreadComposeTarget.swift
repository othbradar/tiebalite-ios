extension TextComposeTarget {
    static func reply(snapshot: ThreadReaderSnapshot, post: ThreadReaderPostRowModel? = nil) -> Self {
        TextComposeTarget(kind: post == nil ? .threadReply : .floorReply,
                          forumID: snapshot.forumID ?? 0, forumName: snapshot.forumName, threadID: snapshot.threadID,
                          postID: post?.source.postID ?? 0, recipient: post?.author,
                          quote: post.map { quote($0.document) } ?? snapshot.title)
    }

}
