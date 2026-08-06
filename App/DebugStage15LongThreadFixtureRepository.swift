#if DEBUG
actor Stage15LongThreadFixtureRepository: ThreadReaderRepository {
    private let threadID: Int64
    private let totalPostCount: Int
    private let pageSize: Int
    private var requestedPages: [Int] = []

    init(
        threadID: Int64,
        totalPostCount: Int,
        pageSize: Int
    ) {
        self.threadID = threadID
        self.totalPostCount = max(1, totalPostCount)
        self.pageSize = max(1, pageSize)
    }

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        try Task.checkCancellation()
        guard request.threadID == threadID else {
            throw FixtureReadingRepositoryError.threadNotFound
        }
        let pageIndex = request.pageNumber == 0
            ? 0
            : request.pageNumber - 1
        let start = pageIndex * pageSize
        guard start < totalPostCount else {
            throw FixtureReadingRepositoryError.unavailable
        }
        requestedPages.append(request.pageNumber)

        let end = min(start + pageSize, totalPostCount)
        let posts = (start..<end).map { index in
            Self.makePost(threadID: threadID, floorNumber: index + 1)
        }
        let totalPages = (totalPostCount + pageSize - 1) / pageSize
        let currentPage = pageIndex + 1
        let hasMore = currentPage < totalPages
        return ThreadReaderSnapshot(
            threadID: threadID,
            title: "一千楼虚拟化 Fixture",
            forumName: "列表性能实验室",
            author: ThreadReaderAuthor(
                rawUserID: threadID + 1,
                displayName: "Fixture 楼主"
            ),
            replyCount: Int32(clamping: totalPostCount - 1),
            posts: posts,
            currentPage: currentPage,
            totalPage: totalPages,
            hasMore: hasMore,
            nextPostID: hasMore ? posts.last?.document.source.postID : nil
        )
    }

    func requestedPageNumbers() -> [Int] {
        requestedPages
    }

    private static func makePost(
        threadID: Int64,
        floorNumber: Int
    ) -> ThreadReaderPost {
        let postID = threadID + Int64(floorNumber * 10_000)
        let scope: ThreadContentSource.Scope = floorNumber == 1
            ? .firstPost
            : .post
        let source = ThreadContentSource(
            threadID: threadID,
            postID: postID,
            scope: scope
        )
        let availability: ThreadContentAvailability = floorNumber.isMultiple(
            of: 43
        )
            ? .unavailable(.folded(message: "Fixture 折叠楼层"))
            : .available
        var nodes = [ThreadContentNode(
            id: ThreadContentNodeID(source: source, ordinal: 0),
            rawType: 0,
            payload: .text(ThreadTextContent(
                value: bodyText(floorNumber: floorNumber)
            ))
        )]
        if floorNumber.isMultiple(of: 37) {
            let nodeID = ThreadContentNodeID(source: source, ordinal: 1)
            nodes.append(ThreadContentNode(
                id: nodeID,
                rawType: 3,
                payload: .image(ThreadImageContent(
                    rawType: 3,
                    mediaID: ThreadMediaID(sourceNodeID: nodeID),
                    request: ThreadImageRequestDescriptor(
                        resourceID: FixtureReadingImageResource.green,
                        candidates: [ThreadImageCandidate(
                            role: .source,
                            destination: ValidatedWebDestination(
                                absoluteString: "https://fixture.invalid/"
                                    + "stage15/long-\(floorNumber).png",
                                scheme: .https
                            )
                        )]
                    ),
                    dimensions: .known(width: 1_200, height: 800),
                    alternativeText: "Fixture 图片 \(floorNumber)",
                    originalByteCount: nil,
                    showsOriginalControlHint: false
                ))
            ))
        }
        let subposts = floorNumber.isMultiple(of: 17)
            ? makeSubposts(
                threadID: threadID,
                parentPostID: postID,
                floorNumber: floorNumber
            )
            : []
        return ThreadReaderPost(
            floorNumber: floorNumber,
            author: ThreadReaderAuthor(
                rawUserID: threadID + Int64(floorNumber),
                displayName: "Fixture 读者 \(floorNumber)"
            ),
            metadata: "\(floorNumber) 楼 · 固定长列表 Fixture",
            document: ThreadContentDocument(
                source: source,
                availability: availability,
                nodes: nodes,
                poll: nil
            ),
            subposts: subposts,
            subpostTotal: subposts.count
        )
    }

    private static func makeSubposts(
        threadID: Int64,
        parentPostID: Int64,
        floorNumber: Int
    ) -> [ThreadReaderSubpost] {
        (1...3).map { index in
            let source = ThreadContentSource(
                threadID: threadID,
                postID: parentPostID + Int64(index),
                scope: .subPost
            )
            return ThreadReaderSubpost(
                parentPostID: parentPostID,
                author: ThreadReaderAuthor(
                    rawUserID: threadID + Int64(10_000 + index),
                    displayName: "楼中楼 Fixture \(index)"
                ),
                replyToDisplayName: index == 1 ? nil : "Fixture \(index - 1)",
                metadata: "\(floorNumber) 楼回复 · Fixture",
                document: ThreadContentDocument(
                    source: source,
                    availability: .available,
                    nodes: [ThreadContentNode(
                        id: ThreadContentNodeID(source: source, ordinal: 0),
                        rawType: 0,
                        payload: .text(ThreadTextContent(
                            value: "稳定楼中楼预览 \(index)"
                        ))
                    )],
                    poll: nil
                )
            )
        }
    }

    private static func bodyText(floorNumber: Int) -> String {
        if floorNumber.isMultiple(of: 11) {
            return "第 \(floorNumber) 楼包含一段较长但固定的正文，用来覆盖自适应高度、复用后重算高度以及快速跨页滚动。"
        }
        return "第 \(floorNumber) 楼的固定短正文。"
    }
}
#endif
