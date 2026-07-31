struct SessionID: Equatable, Hashable, Sendable {
    let rawValue: UInt64
}

struct ProtectedDataLease: Equatable, Sendable {
    let sessionID: SessionID
    let generation: UInt64
}
