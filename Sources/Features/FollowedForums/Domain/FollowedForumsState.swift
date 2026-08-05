enum FollowedForumsLoadFailure: Error, Equatable, Sendable {
    case unavailable
}

enum FollowedForumsSessionAccess: Equatable, Sendable {
    case active(AuthContext)
    case expired
    case signedOut
    case signingIn
}

enum FollowedForumsState: Equatable, Sendable {
    case empty
    case expired
    case initialFailure(FollowedForumsLoadFailure)
    case initialLoading
    case loaded([FollowedForum])
    case refreshFailure([FollowedForum], FollowedForumsLoadFailure)
    case refreshing([FollowedForum])
    case signedOut
    case signingIn
}
