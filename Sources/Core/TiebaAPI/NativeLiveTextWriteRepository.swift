import Foundation

@MainActor
protocol TextWriteRequestValidating {
    func validateForSending(_ request: TextWriteRequest) throws
}

/// User-authorized text trial. SDK/Passport integration and image uploads are
/// deliberately absent; failure never falls back to the Android write path.
@MainActor
final class NativeLiveTextWriteRepository: TextWriteRepository, TextWriteRequestValidating {
    private let auth: any AuthContextProviding
    private let loader: any HTTPDataLoading
    private let runtime: any NativeWriteRuntimeProviding
    private let firstLogin: () -> Bool
    private let didPrepareAccount: () -> Void
    private var lease: AuthContext?
    private var session: NativeWriteSession?
    private var client: NativeTextWriteClient?
    private var sending = false

    init(auth: any AuthContextProviding, loader: any HTTPDataLoading, runtime: any NativeWriteRuntimeProviding,
         firstLogin: @escaping () -> Bool, didPrepareAccount: @escaping () -> Void) {
        self.auth = auth
        self.loader = loader
        self.runtime = runtime
        self.firstLogin = firstLogin
        self.didPrepareAccount = didPrepareAccount
    }

    func validateForSending(_ request: TextWriteRequest) throws {
        guard request.draft.photos.isEmpty else { throw TextWriteFailure.nativeImagesUnavailable }
        guard request.target.isValid else { throw TextWriteFailure.invalidTarget }
        guard request.draft.isSendable else { throw TextWriteFailure.invalidDraft }
    }

    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        try validateForSending(request)
        guard !sending else { throw NativeTextWriteClientError.alreadySending }
        sending = true
        defer { sending = false }
        var activeClient: NativeTextWriteClient?
        do {
            _ = try auth.authorization(for: context)
            try await runtime.prepare()
            try Task.checkCancellation()
            let client = try await preparedClient(context: context)
            activeClient = client
            let target = request.target
            let content: NativeWriteContent = target.kind == .thread ? .prepared(request.draft.content) : .replyCompose(.init(
                supportsServerText: true, serverText: request.draft.content, visibleText: request.draft.content,
                isFloor: target.kind == .subpostReply,
                recipientPrompt: target.kind == .subpostReply ? "回复 \(target.recipient?.displayName ?? "") :" : nil,
                portrait: target.recipient?.portrait, displayName: target.recipient?.displayName))
            let origin: NativeWriteOrigin = target.kind == .thread ? .thread(entranceType: 1) : .reply(.init(
                container: target.kind == .subpostReply ? .subposts : .threadPage,
                pageEntryType: 0, floorNumber: "0", replyCount: nil))
            let result = try await client.send(request, content: content, origin: origin)
            return try Self.receipt(result, target: target)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as TextWriteFailure {
            throw failure
        } catch is RequestAuthorizationError {
            throw activeClient?.didStartWrite == true ? TextWriteFailure.resultUnknown : .authentication
        } catch {
            if activeClient?.didStartWrite == true { throw TextWriteFailure.resultUnknown }
            if let error = error as? HTTPClientError {
                switch error {
                case .offline, .timedOut, .transport: throw TextWriteFailure.network
                case .server(let status): throw TextWriteFailure.http(status)
                default: break
                }
            }
            throw TextWriteFailure.requestPreparation
        }
    }

    private static func receipt(_ result: NativeWriteDecodedResponse, target: TextComposeTarget) throws -> TextWriteReceipt {
        if result.serverRejected {
            if result.accountAction == .reauthenticate { throw TextWriteFailure.authentication }
            if result.accountAction != nil || result.category.map({ [.captcha, .sms, .realName].contains($0) }) == true {
                throw TextWriteFailure.verificationRequired
            }
            throw TextWriteFailure.server(Int(result.errorCode))
        }
        guard let receipt = result.correlatedReceipt(for: target) else { throw TextWriteFailure.resultUnknown }
        return receipt
    }

    private func preparedClient(context: AuthContext) async throws -> NativeTextWriteClient {
        let authorization = try auth.authorization(for: context)
        if lease == context, let client { return client }
        session?.invalidate()
        session = nil
        client = nil
        lease = nil
        let values = try runtime.context(for: .account, authorization: authorization, account: nil)
        var common = NativeWriteCommonParameters()
        var metrics = runtime.requestMetrics
        let fields = try common.prepareAccount(values.common, authorization: authorization,
                                               firstLogin: firstLogin(), metrics: &metrics)
        runtime.requestMetrics = metrics
        let request = try NativeAccountPreparation.request(parameters: fields, runtime: values)
        let response = try await URLSessionHTTPClient(loader: loader).execute(request)
        try Task.checkCancellation()
        _ = try auth.authorization(for: context)
        let account = try NativeAccountPreparation.decode(response)
        let session = try NativeWriteSession(auth: auth, context: context, account: account)
        let client = NativeTextWriteClient(session: session, context: context, runtime: runtime, loader: loader)
        self.session = session
        self.client = client
        lease = context
        didPrepareAccount()
        return client
    }
}
