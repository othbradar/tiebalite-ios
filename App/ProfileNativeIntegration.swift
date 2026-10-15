import Foundation

extension AppCompositionRoot {
    func makeProfileContentRepository() -> any ProfileContentRepository {
        #if DEBUG
        if environment.readingDataSourceMode == .fixture { return FixtureProfileContentRepository() }
        #endif
        let native = ProfileNativeClient(auth: authContextProvider, client: environment.httpClient, account: currentAccountStore)
        return CachedProfileContentRepository(
            cache: contentCacheForProfiles, scheduler: contentScheduler,
            context: { [authContextProvider] in authContextProvider.contentCacheContext },
            execute: { operation, scope in
                try await native.execute(operation, scope: scope)
            })
    }
}

/// New instance and metrics for profile reads/relationships. Never calls the
/// writer's account preparation, write boundary, upload or follow-up state.
@MainActor
private final class ProfileNativeClient {
    let auth: SessionAuthContextProvider
    let client: any HTTPClient
    let accountStore: CurrentAccountStore
    let runtime = NativeWriteAppRuntime()
    init(auth: SessionAuthContextProvider, client: any HTTPClient, account: CurrentAccountStore) {
        self.auth = auth; self.client = client; accountStore = account
    }

    func execute(_ operation: ProfileContentOperation, scope: ContentCacheContext) async throws -> HTTPResponse {
        let context = auth.context()
        try validate(context, scope)
        let authorization: SessionAuthorization
        let accountID: Int64?
        if case .active = context {
            authorization = try auth.authorization(for: context)
            accountStore.updateContext(context)
            await accountStore.loadIfNeeded()
            try validate(context, scope)
            accountID = accountStore.profile?.userID.rawValue
            guard accountID != nil else { throw ProfileContentFailure.identityUnavailable }
        } else { authorization = .init(bduss: "", stoken: ""); accountID = nil }
        try await runtime.prepare()
        try validate(context, scope)
        let account = try await preparedAccount(operation, accountID: accountID, authorization: authorization,
                                                context: context, scope: scope)
        let value = try runtime.context(for: .tbs, authorization: authorization, account: account)
        let path: String, business: [String: String], protobuf: Bool
        switch operation {
        case let .list(route, cursor):
            path = route.section == .forums ? "/c/f/forum/like" : "/c/u/feed/userpost"
            business = try NativeProfileProtocol.business(route, cursor: cursor, accountID: accountID)
            protobuf = route.section != .forums
        case let .relationship(user):
            path = "/c/u/user/profile"; protobuf = false
            var fields = ["pn": "1", "need_post_count": "1", "page": "0", "is_from_usercenter": "0"]
            if accountID == user.userID.rawValue { fields["uid"] = String(user.userID.rawValue) } else {
                if let accountID { fields["uid"] = String(accountID) }
                fields["friend_uid"] = String(user.userID.rawValue); fields["is_guest"] = "1"
            }
            business = fields
        case let .following(followed, user, portrait):
            guard accountID != user.userID.rawValue, !portrait.isEmpty, let account, !account.tbs.isEmpty else {
                throw ProfileContentFailure.relationshipUnavailable
            }
            path = followed ? "/c/c/user/follow" : "/c/c/user/unfollow"; protobuf = false
            // The basic follow:tbs:/unFollow:tbs: wrappers pass -1, nil tid/fid.
            // parseConcernFromType(-1) returns nil; safeSetObject omits it.
            business = ["portrait": portrait, "tbs": account.tbs]
        }
        let common = common(business, value, authenticated: accountID != nil, protobuf: protobuf)
        let request: HTTPRequest
        if protobuf {
            request = try NativeWriteHTTPRequest.protobufRequest(endpoint: (path, 303002),
                                                                 bytes: NativeProfileProtocol.encode(business, common: common),
                                                                 context: value.http,
                                                                 boundary: value.multipartBoundary, responseBodyLimit: 8 * 1_024 * 1_024)
        } else {
            var headers = try value.http.cookies.headerFields()
            headers["User-Agent"] = value.http.userAgent; headers["Accept-Language"] = value.http.acceptLanguage
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            if value.http.clientLogID != 0 && value.http.clientLogID != -1 {
                headers["client_logid"] = String(value.http.clientLogID)
            }
            guard let url = URL(string: "https://tiebac.baidu.com" + path) else { throw ProfileContentFailure.invalidData }
            request = try HTTPRequest(method: .post, url: url, headers: headers, body: NativeTBSRequest.encode(common),
                                      timeout: common["net_type"] == "1" ? 10 : 25, responseBodyLimit: 4 * 1_024 * 1_024)
        }
        try validate(context, scope)
        let response = try await client.execute(request)
        try validate(context, scope)
        guard (200..<300).contains(response.statusCode) else { throw HTTPClientError.server(statusCode: response.statusCode) }
        return response
    }

    private func preparedAccount(_ operation: ProfileContentOperation, accountID: Int64?,
                                 authorization: SessionAuthorization, context: AuthContext,
                                 scope: ContentCacheContext) async throws -> TextWriteAccount? {
        var account: TextWriteAccount?
        if case .following = operation {
            guard let accountID, let namespace = scope.namespace else { throw ProfileContentFailure.loginRequired }
            account = try await NativeWriteAccountVault.shared.load(namespace: namespace)
            if account?.userID != String(accountID) { account = nil }
            if account?.tbs.isEmpty != false {
                let value = try runtime.context(for: .tbs, authorization: authorization, account: nil)
                var common = NativeWriteCommonParameters(), metrics = runtime.requestMetrics
                let fields = try common.prepareTBS(value.common, authorization: authorization, metrics: &metrics)
                let request = try NativeTBSRequest.make(parameters: fields, context: .init(
                                                            userAgent: value.http.userAgent, acceptLanguage: value.http.acceptLanguage,
                                                            clientLogID: value.http.clientLogID, cookies: value.http.cookies))
                try validate(context, scope)
                let tbs = try NativeTBSResponseDecoder.decode(await client.execute(request))
                account = .init(userID: String(accountID), tbs: tbs, nameShow: "")
            }
        }
        return account
    }

    private func common(_ business: [String: String], _ value: NativeWriteRuntimeContext,
                        authenticated: Bool, protobuf: Bool) -> [String: String] {
        var parameters = NativeWriteStaticCommonParameters()
        let fields = parameters.parameters(value.common.staticValues, mode: value.common.staticMode)
        var metrics = NativeWriteRequestMetrics(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0)
        var common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: fields, business: business, context: value.common.dynamicValues, metrics: &metrics)
        if !authenticated { common.removeValue(forKey: "BDUSS"); common.removeValue(forKey: "stoken") }
        return protobuf ? NativeWriteSigning.common(common, business: business, metadata: value.common.metadata)
            : NativeWriteSigning.tbsForm(common, business: business)
    }
    private func validate(_ context: AuthContext, _ scope: ContentCacheContext) throws {
        try Task.checkCancellation()
        guard context == auth.context(), scope == auth.contentCacheContext else { throw CancellationError() }
    }
}
