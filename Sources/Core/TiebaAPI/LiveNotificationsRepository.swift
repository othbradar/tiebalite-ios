struct LiveNotificationsRepository: NotificationsRepository {
    let client: any HTTPClient
    let authContextProvider: any AuthContextProviding

    func load(kind: NotificationKind, page: Int, context: AuthContext) async throws -> NotificationPage {
        try await execute(kind: kind, page: page, context: context, pipeline: .init(
            decode: { try NotificationsProtocol.decodePage($0, kind: kind, page: page) }, map: { $0 }))
    }

    func unread(context: AuthContext) async throws -> NotificationCounts {
        try await execute(kind: nil, page: 0, context: context, pipeline: .init(decode: NotificationsProtocol.decodeCounts, map: { $0 }))
    }

    private func execute<Value: Sendable>(
        kind: NotificationKind?, page: Int, context: AuthContext, pipeline: EndpointPipeline<Value, Value>
    ) async throws -> Value {
        let authorization = try await authContextProvider.authorization(for: context)
        let executor = EndpointExecutor(client: client, requestBuilder: .init(
            authorizer: ActiveSessionRequestAuthorizer(authContextProvider: authContextProvider)))
        let value = try await executor.execute(
            endpoint: NotificationsProtocol.descriptor(kind: kind), authentication: context,
            body: NotificationsProtocol.body(kind: kind, page: page, authorization: authorization), pipeline: pipeline)
        try Task.checkCancellation()
        _ = try await authContextProvider.authorization(for: context)
        return value
    }
}
