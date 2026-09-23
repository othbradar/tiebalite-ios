enum RecommendationsRowID: Hashable, Sendable {
    case thread(Int64)
    case pagination
}

enum RecommendationsRowContent: Equatable, Sendable {
    case thread(RecommendationSummary)
    case pagination(PaginationFooterState)
}

struct RecommendationsRowModel: Identifiable, Equatable, Sendable {
    let content: RecommendationsRowContent
    let isFirstThread: Bool

    var id: RecommendationsRowID {
        switch content {
        case let .thread(item): .thread(item.threadID)
        case .pagination: .pagination
        }
    }
}

struct RecommendationsListPresentation: Equatable, Sendable {
    let rows: [RecommendationsRowModel]
    private let threadIDs: Set<Int64>
    private let prefetchIDs: Set<Int64>

    init(items: [RecommendationSummary], pagination: PaginationFooterState) {
        // The Store owns deduplication and server order; preserve its values intact.
        rows = items.enumerated().map { index, item in
            RecommendationsRowModel(content: .thread(item), isFirstThread: index == 0)
        } + [RecommendationsRowModel(content: .pagination(pagination), isFirstThread: false)]
        threadIDs = Set(items.map(\.threadID))
        prefetchIDs = Set(items.suffix(4).map(\.threadID))
    }

    func prefetchThreadID(in rowIDs: [RecommendationsRowID]) -> Int64? {
        rowIDs.compactMap { threadAnchor(for: $0) }.first { prefetchIDs.contains($0) }
    }

    func threadAnchor(for rowID: RecommendationsRowID?) -> Int64? {
        guard case let .thread(threadID)? = rowID,
              threadID > 0, threadIDs.contains(threadID) else { return nil }
        return threadID
    }

    func restoredRowID(for threadID: Int64?) -> RecommendationsRowID? {
        guard let threadID, threadAnchor(for: .thread(threadID)) != nil else { return nil }
        return .thread(threadID)
    }
}
