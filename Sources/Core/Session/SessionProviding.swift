enum SessionStatus: Equatable, Sendable {
    case expired
    case signedIn
    case signedOut
}

struct SessionSnapshot: Equatable, Sendable {
    let status: SessionStatus
    let revision: UInt64
}

protocol SessionProviding: Sendable {
    func snapshot() async -> SessionSnapshot
}

struct SignedOutSessionProvider: SessionProviding {
    func snapshot() async -> SessionSnapshot {
        SessionSnapshot(status: .signedOut, revision: 0)
    }
}
