extension TextComposeTarget {
    static func reply(_ intent: SubpostReplyIntent, document: ThreadContentDocument) -> Self {
        TextComposeTarget(kind: .subpostReply, forumID: intent.forumID, forumName: intent.forumName,
                          threadID: intent.route.threadID, postID: intent.route.postID, subpostID: intent.subPostID,
                          recipient: intent.author, quote: quote(document))
    }

    static func quote(_ document: ThreadContentDocument) -> String {
        String(document.nodes.map { node in
            switch node.payload {
            case .text(let text): text.value
            case .emoji(let emoji): emoji.fallbackText
            case .link(let link): link.label
            case .mention(let mention): mention.label
            case .image: "[图片]"
            case .voice: "[语音]"
            case .video: "[视频]"
            case .unsupported: "[内容]"
            }
        }.joined().prefix(160))
    }
}
