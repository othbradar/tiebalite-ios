protocol CurrentAccountRepository: Sendable {
    func loadProfile(context: AuthContext) async throws -> UserProfile
}

struct UnavailableCurrentAccountRepository: CurrentAccountRepository {
    func loadProfile(context: AuthContext) async throws -> UserProfile {
        throw UserProfileRepositoryError.empty
    }
}

#if DEBUG
struct FixtureCurrentAccountRepository: CurrentAccountRepository {
    func loadProfile(context: AuthContext) async throws -> UserProfile {
        try Task.checkCancellation()
        guard case .active = context, let userID = UserID(12_001) else {
            throw RequestAuthorizationError.contextMismatch
        }
        return UserProfile(userID: userID, displayName: "示例账户", portraitResourceID: "https://fixture.invalid/account.png",
                           introduction: "记录感兴趣的事", sex: nil, followingCount: 72, followerCount: 101,
                           postCount: 12_511, threadCount: nil, totalAgreeCount: nil, displayTiebaID: nil)
    }
}
#endif
