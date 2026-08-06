enum FixtureThreadReaderPages {
    static func firstPage(
        from seed: FixtureThreadSeed
    ) -> ThreadReaderSnapshot {
        let firstPostID = seed.threadID + 10_000
        let firstPost = ThreadReaderPost(
            floorNumber: 1,
            author: seed.author,
            metadata: "首楼 · Fixture",
            document: document(
                threadID: seed.threadID,
                postID: firstPostID,
                scope: .firstPost,
                paragraphs: [
                    "这是一篇完全由本地 Fixture 提供的只读帖子，用来验证推荐、阅读和图片查看链路。",
                    "内容不会访问真实贴吧，也不会发送任何网络请求。"
                ],
                imageResources: seed.imageResources
            )
        )
        let secondPost = fixturePost(
            seed: seed,
            floorNumber: 2,
            subposts: fixtureSubposts(seed: seed, floorNumber: 2),
            subpostTotal: 4
        )
        let thirdPost = fixturePost(
            seed: seed,
            floorNumber: 3,
            imageResources: [FixtureReadingImageResource.green]
        )
        let laterPosts = (5...17).map { floorNumber in
            fixturePost(seed: seed, floorNumber: floorNumber)
        }
        return ThreadReaderSnapshot(
            threadID: seed.threadID,
            title: seed.title,
            forumName: seed.forumName,
            author: seed.author,
            replyCount: seed.replyCount,
            posts: [
                firstPost,
                secondPost,
                thirdPost,
                unavailablePost(seed: seed, floorNumber: 4)
            ] + laterPosts,
            currentPage: 1,
            totalPage: 2,
            hasMore: true,
            nextPostID: nextPostID(for: seed)
        )
    }

    static func secondPage(
        from seed: FixtureThreadSeed
    ) -> ThreadReaderSnapshot {
        ThreadReaderSnapshot(
            threadID: seed.threadID,
            title: seed.title,
            forumName: seed.forumName,
            author: seed.author,
            replyCount: seed.replyCount,
            posts: [fixturePost(seed: seed, floorNumber: 17)]
                + (18...32).map { floorNumber in
                    fixturePost(seed: seed, floorNumber: floorNumber)
                },
            currentPage: 2,
            totalPage: 2,
            hasMore: false,
            nextPostID: nil
        )
    }

    static func nextPostID(for seed: FixtureThreadSeed) -> Int64 {
        seed.threadID + 170_000
    }

    private static func fixturePost(
        seed: FixtureThreadSeed,
        floorNumber: Int,
        imageResources: [String] = [],
        subposts: [ThreadReaderSubpost] = [],
        subpostTotal: Int = 0
    ) -> ThreadReaderPost {
        let postID = seed.threadID + Int64(floorNumber * 10_000)
        return ThreadReaderPost(
            floorNumber: floorNumber,
            author: ThreadReaderAuthor(
                rawUserID: seed.threadID + Int64(floorNumber),
                displayName: "Fixture 读者 \(floorNumber - 1)"
            ),
            metadata: "\(floorNumber) 楼 · 只读 Fixture",
            document: document(
                threadID: seed.threadID,
                postID: postID,
                scope: .post,
                paragraphs: [
                    "这是第 \(floorNumber) 楼的固定正文。它使用独立 postID，并继续复用统一内容 Renderer。"
                ],
                imageResources: imageResources
            ),
            subposts: subposts,
            subpostTotal: subpostTotal
        )
    }

    private static func fixtureSubposts(
        seed: FixtureThreadSeed,
        floorNumber: Int
    ) -> [ThreadReaderSubpost] {
        let parentPostID = seed.threadID + Int64(floorNumber * 10_000)
        return (1...2).map { index in
            let subPostID = parentPostID + Int64(index)
            return ThreadReaderSubpost(
                parentPostID: parentPostID,
                author: ThreadReaderAuthor(
                    rawUserID: seed.threadID + 100 + Int64(index),
                    displayName: "楼中楼读者 \(index)"
                ),
                replyToDisplayName: index == 2 ? "楼中楼读者 1" : nil,
                metadata: "楼中楼回复 · Fixture",
                document: document(
                    threadID: seed.threadID,
                    postID: subPostID,
                    scope: .subPost,
                    paragraphs: ["这是稳定 ID 的楼中楼预览 \(index)。"],
                    imageResources: []
                )
            )
        }
    }

    private static func unavailablePost(
        seed: FixtureThreadSeed,
        floorNumber: Int
    ) -> ThreadReaderPost {
        let postID = seed.threadID + Int64(floorNumber * 10_000)
        let source = ThreadContentSource(
            threadID: seed.threadID,
            postID: postID,
            scope: .post
        )
        return ThreadReaderPost(
            floorNumber: floorNumber,
            author: ThreadReaderAuthor(
                rawUserID: seed.threadID + Int64(floorNumber),
                displayName: "Fixture 读者 \(floorNumber - 1)"
            ),
            metadata: "\(floorNumber) 楼 · 内容不可用",
            document: ThreadContentDocument(
                source: source,
                availability: .unavailable(.folded(message: "本楼已折叠")),
                nodes: [ThreadContentNode(
                    id: ThreadContentNodeID(source: source, ordinal: 0),
                    rawType: 9_999,
                    payload: .unsupported(ThreadUnsupportedContent(
                        rawType: 9_999,
                        presentFields: [.text]
                    ))
                )],
                poll: nil
            )
        )
    }

    private static func document(
        threadID: Int64,
        postID: Int64,
        scope: ThreadContentSource.Scope,
        paragraphs: [String],
        imageResources: [String]
    ) -> ThreadContentDocument {
        let source = ThreadContentSource(
            threadID: threadID,
            postID: postID,
            scope: scope
        )
        var nodes: [ThreadContentNode] = []
        for paragraph in paragraphs.prefix(1) {
            nodes.append(textNode(
                paragraph,
                source: source,
                ordinal: nodes.count
            ))
        }
        for (index, resourceID) in imageResources.enumerated() {
            nodes.append(imageNode(
                resourceID: resourceID,
                source: source,
                ordinal: nodes.count,
                imageIndex: index
            ))
        }
        for paragraph in paragraphs.dropFirst() {
            nodes.append(textNode(
                paragraph,
                source: source,
                ordinal: nodes.count
            ))
        }
        return ThreadContentDocument(
            source: source,
            availability: .available,
            nodes: nodes,
            poll: nil
        )
    }

    private static func textNode(
        _ value: String,
        source: ThreadContentSource,
        ordinal: Int
    ) -> ThreadContentNode {
        ThreadContentNode(
            id: ThreadContentNodeID(source: source, ordinal: ordinal),
            rawType: 0,
            payload: .text(ThreadTextContent(value: value))
        )
    }

    private static func imageNode(
        resourceID: String,
        source: ThreadContentSource,
        ordinal: Int,
        imageIndex: Int
    ) -> ThreadContentNode {
        let nodeID = ThreadContentNodeID(source: source, ordinal: ordinal)
        return ThreadContentNode(
            id: nodeID,
            rawType: 3,
            payload: .image(ThreadImageContent(
                rawType: 3,
                mediaID: ThreadMediaID(sourceNodeID: nodeID),
                request: ThreadImageRequestDescriptor(
                    resourceID: resourceID,
                    candidates: [ThreadImageCandidate(
                        role: .source,
                        destination: ValidatedWebDestination(
                            absoluteString:
                                "https://fixture.invalid/stage10/\(resourceID).png",
                            scheme: .https
                        )
                    )]
                ),
                dimensions: imageIndex == 2
                    ? .known(width: 800, height: 1_200)
                    : .known(width: 1_200, height: 800),
                alternativeText: "Fixture 图片 \(imageIndex + 1)",
                originalByteCount: nil,
                showsOriginalControlHint: false
            ))
        )
    }
}
