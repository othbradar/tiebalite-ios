import Foundation

enum NativeWriteAPI: String, Sendable {
    case account = "/c/s/login"
    case tbs = "/c/s/tbs"
    case imageUpload = "/c/s/uploadPicture"
    case reply = "/c/c/post/add"
    case thread = "/c/c/thread/add"
    case replyRead = "/c/f/pb/getmypost"
}

/// Values obtained at the native request boundary. The runtime owner acquires
/// its own account/SDK/config values; this client never supplies stand-in IDs.
struct NativeWriteRuntimeContext: Sendable {
    let common: NativeWriteCommonContext
    let http: NativeWriteHTTPContext
    let multipartBoundary: String
}

@MainActor
protocol NativeWriteRuntimeProviding: AnyObject {
    func prepare() async throws
    var requestMetrics: NativeWriteRequestMetrics { get set }
    func context(for api: NativeWriteAPI, authorization: SessionAuthorization,
                 account: TextWriteAccount?) throws -> NativeWriteRuntimeContext
}

extension NativeWriteRuntimeProviding {
    func prepare() async throws { try Task.checkCancellation() }
}

enum NativeWriteOrigin: Sendable {
    case thread(entranceType: Int)
    case reply(NativeTextWriteParameters.ReplyContext)
}

enum NativeWriteContent: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Already converted by the selected native editor path (also used by new threads).
    case prepared(String)
    /// Explicitly selected reply-compose path, never inferred from target IDs.
    case replyCompose(NativeReplyComposeContent)

    var description: String { "NativeWriteContent(redacted)" }
    var debugDescription: String { description }

    func preparedText(for target: TextComposeTarget) throws -> String {
        switch self {
        case .prepared(let text): return text
        case .replyCompose(let input):
            guard target.kind != .thread else { throw TextWriteFailure.invalidTarget }
            return input.preparedText()
        }
    }
}

enum NativeTextWriteClientError: Error, Equatable, Sendable {
    case alreadySending
    case invalidRuntimeContext
}

/// The native account -> optional TBS -> business/Common -> HTTP -> parsed-state
/// chain. Prepared content and runtime providers are explicit dependencies. This
/// does not fall back to the legacy login/write protocol, execute verification,
/// dismiss the composer, or assert a moderation outcome.
@MainActor
final class NativeTextWriteClient {
    private let session: NativeWriteSession
    private let context: AuthContext
    private let runtime: any NativeWriteRuntimeProviding
    private let readClient: NativePreparationHTTPClient
    private let transport: NativeWriteTransport
    private let persistAccount: (TextWriteAccount) async throws -> Void
    private let loadResponseState: ((TextWriteAccount) async throws -> NativeWriteResponseState?)?
    private var common = NativeWriteCommonParameters()
    private var isSending = false
    private(set) var didStartWrite = false
    private(set) var receivedResponseState: NativeWriteResponseState?

    init(session: NativeWriteSession, context: AuthContext, runtime: any NativeWriteRuntimeProviding,
         loader: any HTTPDataLoading, persistAccount: @escaping (TextWriteAccount) async throws -> Void = { _ in },
         loadResponseState: ((TextWriteAccount) async throws -> NativeWriteResponseState?)? = nil) {
        self.session = session
        self.context = context
        self.runtime = runtime
        readClient = NativePreparationHTTPClient(loader: loader, runtime: runtime) {
            _ = try session.authorization(for: context)
        }
        transport = NativeWriteTransport(loader: loader)
        self.persistAccount = persistAccount
        self.loadResponseState = loadResponseState
    }

    func send(_ request: TextWriteRequest, content: NativeWriteContent,
              origin: NativeWriteOrigin) async throws -> NativeWriteDecodedResponse {
        guard !isSending else { throw NativeTextWriteClientError.alreadySending }
        didStartWrite = false
        receivedResponseState = nil
        try validate(request, origin: origin)
        let preparedContent = try content.preparedText(for: request.target)
        try Task.checkCancellation()
        _ = try session.authorization(for: context)
        isSending = true
        defer { isSending = false }

        let account = try await preparedAccount()
        let authorization = try session.authorization(for: context)
        let business = try businessFields(request, content: preparedContent, account: account, origin: origin)
        let api: NativeWriteAPI = request.target.kind == .thread ? .thread : .reply
        let values = try runtimeValues(for: api, authorization: authorization, account: account)
        var metrics = runtime.requestMetrics
        let fields = common.prepare(values.common, business: business, metrics: &metrics)
        runtime.requestMetrics = metrics
        let headers = NativeWriteHTTPContext(
            userAgent: values.http.userAgent, acceptLanguage: values.http.acceptLanguage,
            clientLogID: values.http.clientLogID, timeout: values.http.timeout,
            responseState: try session.parsedResponseState(for: context), cookies: values.http.cookies)
        let outgoing = try NativeWriteHTTPRequest.makeRequest(
            kind: request.target.kind, business: business, common: fields,
            context: headers, boundary: values.multipartBoundary)
        _ = try session.authorization(for: context)
        try Task.checkCancellation()
        didStartWrite = true
        let result = try await transport.execute(outgoing) { [self] metrics in
            try Task.checkCancellation()
            _ = try session.authorization(for: context)
            runtime.requestMetrics = metrics
        }
        try Task.checkCancellation()
        _ = try session.authorization(for: context)
        let decoded = try decodeResponse(result, api: api)
        try session.acceptParsedResponseState(result.state, for: context)
        receivedResponseState = result.state
        return decoded
    }

    func upload(_ photo: ComposerPhoto, forumName: String,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        guard !isSending else { throw NativeTextWriteClientError.alreadySending }
        try Task.checkCancellation()
        _ = try session.authorization(for: context)
        isSending = true
        defer { isSending = false }
        let account = try await preparedAccount()
        let uploader = NativeImageUploadClient(client: readClient, validateAuthorization: { [self] in
            _ = try session.authorization(for: context)
        }, makeRequest: { [self] photo, chunk, final, bytes in
            let authorization = try session.authorization(for: context)
            let values = try runtimeValues(for: .imageUpload, authorization: authorization, account: account)
            let business = NativeImageUploadProtocol.fields(photo: photo, chunk: chunk, final: final, forumName: forumName)
            var metrics = runtime.requestMetrics
            let fields = try common.prepareImageUpload(values.common, business: business, metrics: &metrics)
            runtime.requestMetrics = metrics
            return try NativeImageUploadProtocol.request(fields: fields, bytes: bytes, runtime: values)
        })
        return try await uploader.upload(photo, progress: progress)
    }

    func readReply(business: [String: String]) async throws -> ReplyReadUpdate {
        guard !isSending else { throw NativeTextWriteClientError.alreadySending }
        try Task.checkCancellation()
        let authorization = try session.authorization(for: context)
        guard let account = try session.cachedAccount() else { throw NativeReplyReadError.invalidContext }
        let values = try runtimeValues(for: .replyRead, authorization: authorization, account: account)
        var metrics = runtime.requestMetrics
        let fields = common.prepare(values.common, business: try NativeReplyPageParameters.signingFields(business), metrics: &metrics)
        runtime.requestMetrics = metrics
        // This is a read. It neither prepares the account again nor consumes a send slot.
        let request = try NativeReplyReadProtocol.request(
            business: business, common: fields, context: values.http, boundary: values.multipartBoundary)
        let result = try await transport.execute(request) { [self] metrics in
            try Task.checkCancellation()
            _ = try session.authorization(for: context)
            runtime.requestMetrics = metrics
        }
        try Task.checkCancellation()
        _ = try session.authorization(for: context)
        let response = result.response
        guard (200..<300).contains(response.statusCode) else { throw HTTPClientError.server(statusCode: response.statusCode) }
        if let measurement = result.measurement {
            let errorCode = try? NativeReplyReadProtocol.errorCode(response.body)
            runtime.requestMetrics = errorCode.map {
                measurement.parsedMetrics(api: NativeWriteAPI.replyRead.rawValue, errorCode: $0, statusCode: response.statusCode)
            } ?? measurement.parseFailureMetrics(api: NativeWriteAPI.replyRead.rawValue)
        }
        guard let threadID = business["kz"].flatMap(Int64.init), let postID = business["last_pid"].flatMap(Int64.init) else {
            throw NativeReplyReadError.invalidContext
        }
        return try NativeReplyReadProtocol.decode(response.body, threadID: threadID, targetPostID: postID)
    }

    private func preparedAccount() async throws -> TextWriteAccount {
        let account = try await session.prepareTBS(using: readClient) { operation in
            let values = try runtimeValues(for: .tbs, authorization: operation.authorization, account: nil)
            var metrics = runtime.requestMetrics
            let fields = try common.prepareTBS(values.common, authorization: operation.authorization, metrics: &metrics)
            runtime.requestMetrics = metrics
            return try NativeTBSRequest.make(parameters: fields, context: .init(
                userAgent: values.http.userAgent, acceptLanguage: values.http.acceptLanguage,
                clientLogID: values.http.clientLogID, cookies: values.http.cookies))
        }
        try await persistAccount(account)
        if let loadResponseState {
            let state = try await loadResponseState(account)
            try Task.checkCancellation()
            try session.restoreResponseState(state, for: context)
        }
        try Task.checkCancellation()
        return account
    }

    private func decodeResponse(_ result: NativeWriteResponse, api: NativeWriteAPI) throws -> NativeWriteDecodedResponse {
        guard (200..<300).contains(result.response.statusCode) else {
            throw HTTPClientError.server(statusCode: result.response.statusCode)
        }
        do {
            // Empty bytes must not become SwiftProtobuf's default success envelope.
            guard !result.response.body.isEmpty else { throw HTTPClientError.malformedResponse }
            let decoded = try NativeWriteResponseDecoder.decode(result.response.body)
            if let measurement = result.measurement {
                runtime.requestMetrics = measurement.parsedMetrics(
                    api: api.rawValue, errorCode: decoded.errorCode, statusCode: result.response.statusCode)
            }
            return decoded
        } catch {
            if let measurement = result.measurement {
                runtime.requestMetrics = measurement.parseFailureMetrics(api: api.rawValue)
            }
            throw error
        }
    }

    private func runtimeValues(for api: NativeWriteAPI, authorization: SessionAuthorization,
                               account: TextWriteAccount?) throws -> NativeWriteRuntimeContext {
        let result = try runtime.context(for: api, authorization: authorization, account: account)
        // Prevent a caller from accidentally passing a different endpoint's
        // branch selector, an old account's credentials, or an old TBS snapshot.
        guard result.common.dynamicValues.api == api.rawValue,
              result.common.dynamicValues.sessionValue == authorization.bduss,
              result.common.dynamicValues.secondaryValue == authorization.stoken,
              result.common.dynamicValues.tbs == account?.tbs else {
            throw NativeTextWriteClientError.invalidRuntimeContext
        }
        return result
    }

    private func validate(_ request: TextWriteRequest, origin: NativeWriteOrigin) throws {
        guard request.target.isValid else { throw TextWriteFailure.invalidTarget }
        guard request.draft.isSendable, request.draft.photos.isEmpty else { throw TextWriteFailure.invalidDraft }
        switch (request.target.kind, origin) {
        case (.thread, .thread(let entranceType)) where (0...4).contains(entranceType): break
        case (.threadReply, .reply), (.floorReply, .reply), (.subpostReply, .reply): break
        default: throw TextWriteFailure.invalidTarget
        }
    }

    private func businessFields(_ request: TextWriteRequest, content: String,
                                account: TextWriteAccount, origin: NativeWriteOrigin) throws -> [String: String] {
        switch origin {
        case .thread(let entranceType):
            try NativeTextWriteParameters.thread(request, preparedContent: content, account: account, entranceType: entranceType)
        case .reply(let replyContext):
            try NativeTextWriteParameters.reply(request, preparedContent: content, account: account, context: replyContext)
        }
    }
}
