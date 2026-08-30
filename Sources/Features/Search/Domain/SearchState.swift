enum SearchLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum SearchState: Equatable, Sendable {
    case idle
    case searching(SearchKeyword)
    case loaded(SearchSnapshot)
    case empty(SearchKeyword)
    case failed(
        keyword: SearchKeyword,
        failure: SearchLoadFailure,
        retained: SearchSnapshot?
    )
    case loadingMore(SearchSnapshot)
}

extension SearchState {
    var snapshot: SearchSnapshot? {
        switch self {
        case let .loaded(snapshot),
             let .loadingMore(snapshot),
             let .failed(_, _, snapshot?):
            snapshot
        case .empty, .failed, .idle, .searching:
            nil
        }
    }
}
