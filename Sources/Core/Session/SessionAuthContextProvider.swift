struct SessionAuthorization: Equatable, Sendable,
    CustomStringConvertible, CustomDebugStringConvertible {
    let bduss: String
    let stoken: String

    init(credential: SessionCredential) {
        bduss = credential.bduss
        stoken = credential.stoken
    }

    init(bduss: String, stoken: String) {
        self.bduss = bduss
        self.stoken = stoken
    }

    var description: String {
        "SessionAuthorization(redacted)"
    }

    var debugDescription: String {
        description
    }
}

protocol AuthContextProviding: SessionProviding {
    @MainActor func context() -> AuthContext
    @MainActor func authorization(
        for context: AuthContext
    ) throws -> SessionAuthorization
}

@MainActor
final class SessionAuthContextProvider: AuthContextProviding {
    private var status: SessionStatus = .signedOut
    private var revision: UInt64 = 0
    private var nextSessionID: UInt64 = 0
    private var activeLease: ProtectedDataLease?
    private var credential: SessionCredential?

    func snapshot() async -> SessionSnapshot {
        SessionSnapshot(status: status, revision: revision)
    }

    func context() -> AuthContext {
        guard status == .signedIn,
              let activeLease,
              credential != nil else {
            return .anonymous
        }
        return .active(activeLease)
    }

    func authorization(
        for context: AuthContext
    ) throws -> SessionAuthorization {
        guard case let .active(requestedLease) = context else {
            throw RequestAuthorizationError.contextMismatch
        }
        guard let activeLease,
              let credential,
              status == .signedIn else {
            throw RequestAuthorizationError.credentialUnavailable
        }
        guard requestedLease == activeLease else {
            throw RequestAuthorizationError.contextMismatch
        }
        return SessionAuthorization(credential: credential)
    }

    @discardableResult
    func install(_ credential: SessionCredential) -> ProtectedDataLease {
        nextSessionID &+= 1
        revision &+= 1
        let lease = ProtectedDataLease(
            sessionID: SessionID(rawValue: nextSessionID),
            generation: revision
        )
        self.credential = credential
        activeLease = lease
        status = .signedIn
        return lease
    }

    @discardableResult
    func expire(context: AuthContext) -> Bool {
        guard case let .active(requestedLease) = context,
              requestedLease == activeLease else {
            return false
        }
        revision &+= 1
        credential = nil
        activeLease = nil
        status = .expired
        return true
    }

    func revoke() {
        revision &+= 1
        credential = nil
        activeLease = nil
        status = .signedOut
    }
}

struct ActiveSessionRequestAuthorizer: RequestAuthorizing {
    private let authContextProvider: any AuthContextProviding

    init(authContextProvider: any AuthContextProviding) {
        self.authContextProvider = authContextProvider
    }

    func headers(
        for context: AuthContext,
        endpoint: EndpointDescriptor
    ) async throws -> [String: String] {
        guard endpoint.authentication == .active else {
            throw RequestAuthorizationError.contextMismatch
        }
        _ = try await authContextProvider.authorization(for: context)
        return [:]
    }
}
