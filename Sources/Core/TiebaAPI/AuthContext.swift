enum AuthContext: Equatable, Sendable {
    case active(ProtectedDataLease)
    case anonymous
    case candidate(OperationID)
}

enum EndpointAuthenticationRequirement: Equatable, Sendable {
    case active
    case anonymous
    case candidate
}

enum RequestAuthorizationError: Error, Equatable, Sendable {
    case contextMismatch
    case credentialUnavailable
    case destinationNotAllowed
}

protocol RequestAuthorizing: Sendable {
    func headers(
        for context: AuthContext,
        endpoint: EndpointDescriptor
    ) async throws -> [String: String]
}

struct AnonymousRequestAuthorizer: RequestAuthorizing {
    func headers(
        for context: AuthContext,
        endpoint: EndpointDescriptor
    ) async throws -> [String: String] {
        guard Self.matches(context, requirement: endpoint.authentication) else {
            throw RequestAuthorizationError.contextMismatch
        }

        switch context {
        case .anonymous:
            return [:]
        case .active, .candidate:
            throw RequestAuthorizationError.credentialUnavailable
        }
    }

    private static func matches(
        _ context: AuthContext,
        requirement: EndpointAuthenticationRequirement
    ) -> Bool {
        switch (context, requirement) {
        case (.active, .active),
             (.anonymous, .anonymous),
             (.candidate, .candidate):
            true
        default:
            false
        }
    }
}
