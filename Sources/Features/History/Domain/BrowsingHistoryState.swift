enum BrowsingHistoryState: Equatable, Sendable {
    case idle
    case loading
    case loaded([BrowsingHistoryEntry])
    case failed

    var entries: [BrowsingHistoryEntry] {
        if case let .loaded(entries) = self {
            return entries
        }
        return []
    }
}

enum BrowsingHistoryPersistenceIssue: Equatable, Sendable {
    case clearFailed
    case deleteFailed
    case recordFailed
}
