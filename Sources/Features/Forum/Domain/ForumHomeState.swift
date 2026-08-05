enum ForumHomeLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum ForumHomeState: Equatable, Sendable {
    case empty(ForumSummary)
    case initialFailure(ForumHomeLoadFailure)
    case initialLoading
    case loaded(ForumHomeSnapshot)
    case refreshFailure(ForumHomeSnapshot, ForumHomeLoadFailure)
    case refreshing(ForumHomeSnapshot)
}
