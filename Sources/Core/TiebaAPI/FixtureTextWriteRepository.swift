#if DEBUG
struct FixtureTextWriteRepository: TextWriteRepository {
    var failure: TextWriteFailure?
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        try Task.checkCancellation()
        if let failure { throw failure }
        return .init(threadID: request.target.kind == .thread ? 900_001 : request.target.threadID, postID: 900_002)
    }
}
#endif
