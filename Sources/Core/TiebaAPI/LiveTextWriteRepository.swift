import Foundation

struct LiveTextWriteRepository: TextWriteRepository {
    let client: any HTTPClient
    let authContextProvider: any AuthContextProviding

    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        guard request.target.isValid else { throw TextWriteFailure.invalidTarget }
        guard request.draft.isSendable else { throw TextWriteFailure.invalidDraft }
        let executor = EndpointExecutor(client: client, requestBuilder: EndpointRequestBuilder(
            authorizer: ActiveSessionRequestAuthorizer(authContextProvider: authContextProvider)))
        var writeStarted = false
        do {
            let authorization = try await authContextProvider.authorization(for: context)
            let account = try await executor.execute(
                endpoint: TextWriteAccountProtocol.descriptor(), authentication: context,
                body: TextWriteAccountProtocol.body(authorization),
                pipeline: EndpointPipeline(decode: TextWriteAccountProtocol.decode, map: { $0 }))
            try Task.checkCancellation()
            _ = try await authContextProvider.authorization(for: context)
            let endpoint = try TextWriteProtocol.descriptor(for: request.target.kind, userID: account.userID)
            let body = try TextWriteProtocol.body(request, authorization: authorization, account: account)
            writeStarted = true
            let outcome = try await executor.execute(
                endpoint: endpoint, authentication: context, body: body,
                pipeline: EndpointPipeline(decode: { bytes in
                    if request.target.kind == .thread { return try TextWriteProtocol.decodeThread(bytes) }
                    return try TextWriteProtocol.decodePost(bytes, target: request.target)
                }, map: { $0 }))
            _ = try await authContextProvider.authorization(for: context)
            switch outcome {
            case .success(let receipt): return receipt
            case .failure(let failure): throw failure
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as TextWriteFailure {
            throw failure
        } catch is RequestAuthorizationError {
            throw writeStarted ? TextWriteFailure.resultUnknown : .authentication
        } catch let error as EndpointExecutionError {
            throw Self.failure(error, writeStarted: writeStarted)
        } catch {
            throw writeStarted ? TextWriteFailure.resultUnknown : .malformedResponse
        }
    }

    private static func failure(_ error: EndpointExecutionError, writeStarted: Bool) -> TextWriteFailure {
        switch error {
        case .authentication: .authentication
        case .http(let code): (code == 401 || code == 403) ? .authentication : .http(code)
        case .server(let code): .server(code)
        case .transport: writeStarted ? .resultUnknown : .network
        case .decode, .mapping, .responseTooLarge, .unsupportedContent: writeStarted ? .resultUnknown : .malformedResponse
        }
    }
}
