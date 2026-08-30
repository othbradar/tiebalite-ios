enum ForumHomeLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum ForumHomeState: Equatable, Sendable {
    case empty(ForumSummary)
    case initialFailure(ForumHomeLoadFailure)
    case initialLoading
    case loaded(ForumHomeSnapshot)
    case loadingNextPage(ForumHomeSnapshot)
    case nextPageFailure(ForumHomeSnapshot, ForumHomeLoadFailure)
    case refreshFailure(ForumHomeSnapshot, ForumHomeLoadFailure)
    case refreshing(ForumHomeSnapshot)
}

extension ForumHomeState {
    var snapshot: ForumHomeSnapshot? {
        switch self {
        case let .loaded(snapshot),
             let .loadingNextPage(snapshot),
             let .nextPageFailure(snapshot, _),
             let .refreshFailure(snapshot, _),
             let .refreshing(snapshot):
            snapshot
        case .empty, .initialFailure, .initialLoading:
            nil
        }
    }

    var displayedForum: ForumSummary? {
        switch self {
        case let .empty(forum):
            forum
        case let .loaded(snapshot),
             let .loadingNextPage(snapshot),
             let .nextPageFailure(snapshot, _),
             let .refreshFailure(snapshot, _),
             let .refreshing(snapshot):
            snapshot.forum
        case .initialFailure, .initialLoading:
            nil
        }
    }
}
