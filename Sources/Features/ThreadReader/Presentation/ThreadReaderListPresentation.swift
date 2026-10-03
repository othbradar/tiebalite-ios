enum ThreadReaderRowID: Hashable, Sendable {
    case end(threadID: Int64)
    case firstPost(threadID: Int64, postID: Int64)
    case header(threadID: Int64)
    case loadMore(threadID: Int64, page: Int)
    case loadMoreFailure(threadID: Int64, page: Int)
    case loadingNextPage(threadID: Int64, page: Int)
    case post(threadID: Int64, postID: Int64)

    var isPost: Bool {
        switch self {
        case .firstPost, .post:
            true
        case .end, .header, .loadMore, .loadMoreFailure, .loadingNextPage:
            false
        }
    }
}

struct ThreadReaderSubpostRowModel: Identifiable, Equatable, Sendable {
    let id: ThreadContentSource
    let authorName: String
    let author: ThreadReaderAuthor
    let replyToDisplayName: String?
    let metadata: String
    let document: ThreadContentDocument

    init(_ subpost: ThreadReaderSubpost) {
        id = subpost.id
        authorName = subpost.author.displayName
        author = subpost.author
        replyToDisplayName = subpost.replyToDisplayName
        metadata = subpost.metadata
        document = subpost.document
    }
}

struct ThreadReaderPostRowModel: Equatable, Sendable {
    let source: ThreadContentSource
    let floorNumber: Int
    let authorName: String
    let metadata: String
    let document: ThreadContentDocument
    let inlineSubposts: [ThreadReaderSubpostRowModel]
    let remainingSubpostCount: Int
    let totalSubpostCount: Int
    let author: ThreadReaderAuthor
    let isThreadAuthor: Bool
    let title: String?
    let replyCount: Int32?
    let agreeCount: Int64?

    init(_ post: ThreadReaderPost, threadAuthorID: Int64 = 0, title: String? = nil, replyCount: Int32? = nil) {
        author = post.author
        isThreadAuthor = post.author.isThreadAuthor(threadAuthorID)
        self.title = post.floorNumber == 1 ? title : nil
        self.replyCount = post.floorNumber == 1 ? replyCount : nil
        agreeCount = post.agreeCount
        source = post.document.source
        floorNumber = post.floorNumber
        authorName = post.author.displayName
        metadata = post.metadata
        document = post.document
        inlineSubposts = post.subposts.prefix(3).map(
            ThreadReaderSubpostRowModel.init
        )
        totalSubpostCount = max(post.subpostTotal, inlineSubposts.count)
        remainingSubpostCount = max(
            0,
            totalSubpostCount - inlineSubposts.count
        )
    }
}

enum ThreadReaderPaginationRowState: Equatable, Sendable {
    case end
    case refreshFailure
    case cached(hasMore: Bool, nextPage: Int)
    case failure(nextPage: Int)
    case loadMore(nextPage: Int)
    case loading(nextPage: Int)
}

struct ThreadReaderPaginationRowModel: Equatable, Sendable {
    let threadID: Int64
    let state: ThreadReaderPaginationRowState
}

struct ThreadReaderRowModel: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case pagination(ThreadReaderPaginationRowModel)
        case post(ThreadReaderPostRowModel)
    }

    let id: ThreadReaderRowID
    let content: Content

    var post: ThreadReaderPostRowModel? {
        guard case let .post(post) = content else {
            return nil
        }
        return post
    }

    var isPagination: Bool {
        if case .pagination = content {
            return true
        }
        return false
    }
}

struct ThreadReaderListPresentation: Equatable, Sendable {
    private static let prefetchFloorCount = 4

    private(set) var rows: [ThreadReaderRowModel]
    private(set) var prefetchRowIDs: Set<ThreadReaderRowID>
    private let threadID: Int64

    init(
        snapshot: ThreadReaderSnapshot,
        pagination: ThreadReaderPaginationRowState
    ) {
        threadID = snapshot.threadID
        let postRows = snapshot.posts.map { Self.postRow($0, snapshot: snapshot) }
        rows = postRows
            + [Self.paginationRow(
                threadID: snapshot.threadID,
                state: pagination
            )]
        prefetchRowIDs = Set(
            postRows.suffix(Self.prefetchFloorCount).map(\.id)
        )
    }

    var postRowCount: Int {
        rows.lazy.filter { $0.id.isPost }.count
    }

    mutating func append(
        snapshot: ThreadReaderSnapshot,
        newPosts: [ThreadReaderPost],
        pagination: ThreadReaderPaginationRowState
    ) {
        removePaginationRow()
        rows.append(contentsOf: newPosts.map { Self.postRow($0, snapshot: snapshot) })
        rows.append(Self.paginationRow(
            threadID: threadID,
            state: pagination
        ))
        refreshPrefetchRows()
    }

    mutating func setPagination(_ state: ThreadReaderPaginationRowState) {
        removePaginationRow()
        rows.append(Self.paginationRow(threadID: threadID, state: state))
    }

    private mutating func removePaginationRow() {
        if rows.last?.isPagination == true {
            rows.removeLast()
        }
    }

    private mutating func refreshPrefetchRows() {
        prefetchRowIDs = Set(
            rows.lazy
                .filter { $0.id.isPost }
                .suffix(Self.prefetchFloorCount)
                .map(\.id)
        )
    }

    private static func postRow(
        _ post: ThreadReaderPost, snapshot: ThreadReaderSnapshot
    ) -> ThreadReaderRowModel {
        let postID = post.document.source.postID
        let rowID: ThreadReaderRowID = post.floorNumber == 1
            ? .firstPost(
                threadID: post.document.source.threadID,
                postID: postID
            )
            : .post(
                threadID: post.document.source.threadID,
                postID: postID
            )
        return ThreadReaderRowModel(
            id: rowID,
            content: .post(ThreadReaderPostRowModel(
                post, threadAuthorID: snapshot.author.rawUserID, title: snapshot.title, replyCount: snapshot.replyCount
            ))
        )
    }

    private static func paginationRow(
        threadID: Int64,
        state: ThreadReaderPaginationRowState
    ) -> ThreadReaderRowModel {
        let rowID: ThreadReaderRowID
        switch state {
        case let .cached(hasMore, nextPage):
            rowID = hasMore ? .loadMore(threadID: threadID, page: nextPage) : .end(threadID: threadID)
        case .refreshFailure:
            rowID = .end(threadID: threadID)
        case .end:
            rowID = .end(threadID: threadID)
        case let .failure(nextPage):
            rowID = .loadMoreFailure(
                threadID: threadID,
                page: nextPage
            )
        case let .loadMore(nextPage):
            rowID = .loadMore(threadID: threadID, page: nextPage)
        case let .loading(nextPage):
            rowID = .loadingNextPage(
                threadID: threadID,
                page: nextPage
            )
        }
        return ThreadReaderRowModel(
            id: rowID,
            content: .pagination(ThreadReaderPaginationRowModel(
                threadID: threadID,
                state: state
            ))
        )
    }
}
