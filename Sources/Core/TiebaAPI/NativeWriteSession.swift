/// A single native write account's preparation state. The account owner supplies
/// its stored metadata; this object does not perform login or fetch on every send.
/// Auth checks and mutation share the existing session provider's actor boundary.
@MainActor
final class NativeWriteSession {
    final class TBSRequest: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        let userID: String
        let authorization: SessionAuthorization
        fileprivate let context: AuthContext

        fileprivate init(userID: String, authorization: SessionAuthorization, context: AuthContext) {
            self.userID = userID
            self.authorization = authorization
            self.context = context
        }

        static func == (lhs: TBSRequest, rhs: TBSRequest) -> Bool { lhs === rhs }
        var description: String { "NativeWriteTBSRequest(redacted)" }
        var debugDescription: String { description }
    }

    private let auth: any AuthContextProviding
    private let context: AuthContext
    private var account: TextWriteAccount?
    private var responseState: NativeWriteResponseState?
    private var pendingTBS: TBSRequest?

    init(auth: any AuthContextProviding, context: AuthContext, account: TextWriteAccount) throws {
        guard case .active = context, Int64(account.userID).map({ $0 > 0 }) == true else {
            throw RequestAuthorizationError.contextMismatch
        }
        _ = try auth.authorization(for: context)
        self.auth = auth
        self.context = context
        self.account = account
    }

    func cachedAccount() throws -> TextWriteAccount? {
        _ = try validate()
        guard let account, !account.tbs.isEmpty else { return nil }
        return account
    }

    func authorization(for requestContext: AuthContext) throws -> SessionAuthorization {
        guard requestContext == context else { throw RequestAuthorizationError.contextMismatch }
        return try validate()
    }

    func parsedResponseState(for requestContext: AuthContext) throws -> NativeWriteResponseState? {
        _ = try authorization(for: requestContext)
        return responseState
    }

    /// Missing TBS starts at most one preparation operation. It is not a send or
    /// an automatic retry. Failure releases the operation for a later explicit try.
    func beginTBSRequest() throws -> TBSRequest? {
        let authorization = try validate()
        guard let account, account.tbs.isEmpty, pendingTBS == nil else { return nil }
        let request = TBSRequest(userID: account.userID, authorization: authorization,
                                 context: context)
        pendingTBS = request
        return request
    }

    /// One explicit preparation attempt. The owner supplies native runtime
    /// providers through makeRequest; no login, retry or write is implied here.
    func prepareTBS(using client: any HTTPClient,
                    makeRequest: (TBSRequest) throws -> HTTPRequest) async throws -> TextWriteAccount {
        try Task.checkCancellation()
        if let account = try cachedAccount() { return account }
        guard let operation = try beginTBSRequest() else { throw NativeTBSError.alreadyPreparing }
        defer {
            if pendingTBS == operation { pendingTBS = nil }
        }
        let request = try makeRequest(operation)
        guard request.method == .post, request.url.absoluteString == "https://tiebac.baidu.com/c/s/tbs" else {
            throw NativeTBSError.invalidRequestContext
        }
        _ = try validate()
        guard pendingTBS == operation else { throw NativeTBSError.superseded }
        let response = try await client.execute(request)
        try Task.checkCancellation()
        _ = try validate()
        let value = try NativeTBSResponseDecoder.decode(response)
        guard try finishTBSRequest(operation, value: value), let account = try cachedAccount() else {
            throw NativeTBSError.superseded
        }
        return account
    }

    @discardableResult
    func finishTBSRequest(_ request: TBSRequest, value: String?) throws -> Bool {
        _ = try validate()
        guard request == pendingTBS, request.context == context,
              let account, account.userID == request.userID else { return false }
        pendingTBS = nil
        guard let value, !value.isEmpty else { return false }
        self.account = TextWriteAccount(userID: account.userID, tbs: value, nameShow: account.nameShow)
        return true
    }

    func acceptParsedResponseState(_ state: NativeWriteResponseState?, for requestContext: AuthContext) throws {
        _ = try validate()
        guard requestContext == context else { throw RequestAuthorizationError.contextMismatch }
        if let state { responseState = state }
    }

    /// Read-through of this account's protected cache, including eviction. A
    /// missing response header uses acceptParsedResponseState instead.
    func restoreResponseState(_ state: NativeWriteResponseState?, for requestContext: AuthContext) throws {
        _ = try authorization(for: requestContext)
        responseState = state
    }

    /// Applies a decoded profile update to the owning account. It neither loads
    /// a profile on send nor changes TBS or any in-flight preparation operation.
    @discardableResult
    func acceptProfileName(profileUserID: String, displayName: String?, loginName: String?,
                           for requestContext: AuthContext) throws -> Bool {
        _ = try validate()
        guard requestContext == context else { throw RequestAuthorizationError.contextMismatch }
        guard var account, let name = NativeWriteAccountName.updatedName(
            accountID: account.userID, currentName: account.nameShow, profileID: profileUserID,
            displayName: displayName, loginName: loginName
        ) else { return false }
        account.nameShow = name
        self.account = account
        return true
    }

    func customHeaders() throws -> [String: String] {
        _ = try validate()
        return responseState?.requestHeaders ?? [:]
    }

    func invalidate() {
        account = nil
        responseState = nil
        pendingTBS = nil
    }

    private func validate() throws -> SessionAuthorization {
        guard account != nil else { throw RequestAuthorizationError.credentialUnavailable }
        do {
            return try auth.authorization(for: context)
        } catch {
            invalidate()
            throw error
        }
    }
}
