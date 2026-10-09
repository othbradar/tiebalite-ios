import Foundation

@MainActor
protocol TextWriteRequestValidating {
    func validateForSending(_ request: TextWriteRequest) throws
}

/// User-authorized native trial. SDK/Passport integration remains separate;
/// text and image failures never fall back to the Android write path.
@MainActor
final class NativeLiveTextWriteRepository: TextWriteRepository, TextWriteRequestValidating, ComposerImageUploading, ReplyFollowupLoading {
    private let auth: any AuthContextProviding
    private let loader: any HTTPDataLoading
    private let runtime: any NativeWriteRuntimeProviding
    private let firstLogin: () -> Bool
    private let didPrepareAccount: () -> Void
    private let accountVault: NativeWriteAccountVault?
    private let accountNamespace: () -> String?
    private let currentProfile: () -> UserProfile?
    private var lease: AuthContext?
    private var metricsContext: AuthContext?
    private var session: NativeWriteSession?
    private var client: NativeTextWriteClient?
    private var sending = false
    private struct PendingReply {
        let receipt: TextWriteReceipt
        let target: TextComposeTarget
        let context: AuthContext
    }
    private var replyRead: PendingReply?
    private var replyReadCount: Int64 = 0
    private let replyReadSwitch: () -> Int?
    private(set) var responseStatePersistenceFailed = false

    init(auth: any AuthContextProviding, loader: any HTTPDataLoading, runtime: any NativeWriteRuntimeProviding,
         firstLogin: @escaping () -> Bool, didPrepareAccount: @escaping () -> Void,
         accountVault: NativeWriteAccountVault? = nil, accountNamespace: @escaping () -> String? = { nil },
         currentProfile: @escaping () -> UserProfile? = { nil }, replyReadSwitch: @escaping () -> Int? = { nil }) {
        self.auth = auth
        self.loader = loader
        self.runtime = runtime
        self.firstLogin = firstLogin
        self.didPrepareAccount = didPrepareAccount
        self.accountVault = accountVault
        self.accountNamespace = accountNamespace
        self.currentProfile = currentProfile
        self.replyReadSwitch = replyReadSwitch
    }

    func validateForSending(_ request: TextWriteRequest) throws {
        guard request.draft.photos.allSatisfy({ photo in
            photo.uploaded == nil || photo.uploaded?.source == NativeImageUploadProtocol.receiptSource
        }) else {
            throw ImageUploadFailure.invalidImage
        }
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
            if let profile = currentProfile() {
                try session?.acceptProfileName(profileUserID: String(profile.userID.rawValue),
                                               displayName: profile.accountDisplayName,
                                               loginName: profile.accountLoginName, for: context)
            }
            activeClient = client
            let target = request.target
            let content: NativeWriteContent = target.kind == .thread ? .prepared(request.draft.content) : .replyCompose(.init(
                supportsServerText: true, serverText: request.draft.content, visibleText: request.draft.content,
                isFloor: target.kind == .subpostReply,
                recipientPrompt: target.kind == .subpostReply ? "回复 \(target.recipient?.displayName ?? "") :" : nil,
                portrait: target.recipient?.portrait, displayName: target.recipient?.displayName))
            let origin: NativeWriteOrigin = target.kind == .thread ? .thread(entranceType: 1) : .reply(.init(
                container: target.kind == .subpostReply ? .subposts : .threadPage,
                pageEntryType: target.readingEntry.rawValue, floorNumber: "0", replyCount: target.replyCount.map(String.init)))
            let result = try await client.send(request, content: content, origin: origin)
            await persistReceivedState(client.receivedResponseState, context: context)
            let receipt = try Self.receipt(result, target: target)
            replyRead = target.kind == .thread ? nil : .init(receipt: receipt, target: target, context: context)
            return receipt
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

    func loadReply(_ request: ReplyFollowupRequest) async throws -> ReplyReadUpdate? {
        guard let pending = replyRead, pending.receipt == request.receipt else { return nil }
        // Consume before suspension: one accepted receipt can cause at most one read.
        replyRead = nil
        _ = try auth.authorization(for: pending.context)
        guard NativeReplyPageParameters.enabled(override: replyReadSwitch()) else { return nil }
        guard lease == pending.context, let client else { throw NativeReplyReadError.invalidContext }
        let frozen = ReplyFollowupRequest(receipt: request.receipt, entry: pending.target.readingEntry, page: request.page)
        let fields = try NativeReplyPageParameters.fields(frozen, target: pending.target, requestCount: replyReadCount)
        if let count = fields["request_times"].flatMap(Int64.init) { replyReadCount = count }
        let page = try await client.readReply(business: fields)
        try Task.checkCancellation()
        _ = try auth.authorization(for: pending.context)
        return page
    }

    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        guard !sending else { throw NativeTextWriteClientError.alreadySending }
        sending = true
        defer { sending = false }
        do {
            _ = try auth.authorization(for: context)
            try await runtime.prepare()
            try Task.checkCancellation()
            let client = try await preparedClient(context: context)
            return try await client.upload(photo, forumName: forumName, progress: progress)
        } catch is CancellationError {
            throw CancellationError()
        } catch is RequestAuthorizationError {
            throw TextWriteFailure.authentication
        } catch let failure as ImageUploadFailure {
            throw failure
        } catch {
            throw ImageUploadFailure.unavailable
        }
    }

    private func persistReceivedState(_ state: NativeWriteResponseState?, context: AuthContext) async {
        guard let state, let accountVault, let namespace = accountNamespace() else { return }
        do {
            _ = try auth.authorization(for: context)
            guard let account = try session?.cachedAccount() else { return }
            try await accountVault.saveResponseState(state, namespace: namespace, userID: account.userID)
            responseStatePersistenceFailed = false
        } catch {
            // A local storage failure cannot undo a parsed remote result or
            // become an invitation to resend. The vault retains its memory copy.
            responseStatePersistenceFailed = true
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
        if let metricsContext, metricsContext != context {
            runtime.requestMetrics = .init(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0)
        }
        metricsContext = context
        session?.invalidate()
        session = nil
        client = nil
        lease = nil
        let namespace = accountNamespace()
        if let namespace, let stored = try await accountVault?.load(namespace: namespace) {
            try Task.checkCancellation()
            _ = try auth.authorization(for: context)
            guard accountNamespace() == namespace else { throw RequestAuthorizationError.contextMismatch }
            return try install(stored, context: context, namespace: namespace)
        }
        let values = try runtime.context(for: .account, authorization: authorization, account: nil)
        var common = NativeWriteCommonParameters()
        var metrics = runtime.requestMetrics
        let fields = try common.prepareAccount(values.common, authorization: authorization,
                                               firstLogin: firstLogin(), metrics: &metrics)
        runtime.requestMetrics = metrics
        let request = try NativeAccountPreparation.request(parameters: fields, runtime: values)
        let preparation = NativePreparationHTTPClient(loader: loader, runtime: runtime) { [auth] in
            _ = try auth.authorization(for: context)
        }
        let response = try await preparation.execute(request)
        try Task.checkCancellation()
        _ = try auth.authorization(for: context)
        let account = try NativeAccountPreparation.decode(response)
        let client = try install(account, context: context, namespace: namespace)
        didPrepareAccount()
        return client
    }

    private func install(_ account: TextWriteAccount, context: AuthContext, namespace: String?) throws -> NativeTextWriteClient {
        let session = try NativeWriteSession(auth: auth, context: context, account: account)
        let client = NativeTextWriteClient(session: session, context: context, runtime: runtime, loader: loader,
                                           persistAccount: { [auth, accountVault, accountNamespace] account in
            guard let namespace, let accountVault else { return }
            _ = try auth.authorization(for: context)
            guard accountNamespace() == namespace else { throw RequestAuthorizationError.contextMismatch }
            try await accountVault.save(account, namespace: namespace)
            do {
                _ = try auth.authorization(for: context)
            } catch {
                try await accountVault.delete(namespace: namespace)
                throw error
            }
        }, loadResponseState: accountVault != nil && namespace != nil ? { [auth, accountVault, accountNamespace] account in
            guard let namespace, let accountVault, accountNamespace() == namespace else {
                throw RequestAuthorizationError.contextMismatch
            }
            _ = try auth.authorization(for: context)
            return try await accountVault.responseState(namespace: namespace, userID: account.userID)
        } : nil)
        self.session = session
        self.client = client
        lease = context
        return client
    }
}
