import SwiftUI

extension AppCompositionRoot {
    func makeFavoriteStore() -> FavoriteStore {
#if DEBUG
        if case .fixture = environment.readingDataSourceMode {
            return FavoriteStore(repository: FavoriteFixtureRepository(),
                                 context: { .init(namespace: "fixture", revision: 1) }, account: { "9" })
        }
#endif
        let auth = authContextProvider
        let accountStore = currentAccountStore
        let profiles = LiveCurrentAccountRepository(client: environment.httpClient, authContextProvider: auth)
        let client = FavoriteAppClient(auth: auth, client: environment.httpClient)
        return FavoriteStore(repository: NativeFavoriteRepository(execute: { operation, account in
            try await client.execute(operation, account: account)
        }), context: { auth.contentCacheContext }, account: {
            let context = auth.context()
            guard case .active = context else { throw FavoriteFailure.accountUnavailable }
            accountStore.updateContext(context)
            let profile: UserProfile
            if let current = accountStore.profile { profile = current } else { profile = try await profiles.loadProfile(context: context) }
            guard context == auth.context() else { throw CancellationError() }
            return String(profile.userID.rawValue)
        })
    }
}

/// Separate instance: favorites cannot mutate the established posting runtime,
/// request metrics, cached write response, SDK state or account preparation.
@MainActor
private final class FavoriteAppClient {
    let auth: SessionAuthContextProvider
    let client: any HTTPClient
    let runtime = NativeWriteAppRuntime()
    init(auth: SessionAuthContextProvider, client: any HTTPClient) { self.auth = auth; self.client = client }

    func execute(_ operation: NativeFavoriteRequest.Operation, account userID: String) async throws -> HTTPResponse {
        let context = auth.context(), cache = auth.contentCacheContext
        guard case .active = context else { throw FavoriteFailure.accountUnavailable }
        let authorization = try auth.authorization(for: context)
        try await runtime.prepare()
        var account: TextWriteAccount?
        if let namespace = cache.namespace {
            account = try await NativeWriteAccountVault.shared.load(namespace: namespace)
            if account?.userID != userID { account = nil }
        }
        // Native Common supplies the current account's TBS. If this app has not
        // prepared it, acquire just TBS (read-only), never login or submit a reply.
        if operation.isWrite && account?.tbs.isEmpty != false {
            let value = try runtime.context(for: .tbs, authorization: authorization, account: nil)
            var common = NativeWriteCommonParameters()
            var metrics = runtime.requestMetrics
            let fields = try common.prepareTBS(value.common, authorization: authorization, metrics: &metrics)
            let request = try NativeTBSRequest.make(parameters: fields, context: .init(
                userAgent: value.http.userAgent, acceptLanguage: value.http.acceptLanguage,
                clientLogID: value.http.clientLogID, cookies: value.http.cookies))
            try validate(context)
            let tbs = try NativeTBSResponseDecoder.decode(await client.execute(request))
            account = TextWriteAccount(userID: userID, tbs: tbs, nameShow: "")
        }
        try validate(context)
        // The provider API affects only sign-optimization path selection, disabled
        // here as in our verified ordinary iOS form branch. No TBS request occurs.
        let value = try runtime.context(for: .tbs, authorization: authorization, account: account)
        let request = try NativeFavoriteRequest.make(operation, account: userID, runtime: value)
        let response = try await client.execute(request)
        try validate(context)
        return response
    }

    private func validate(_ context: AuthContext) throws {
        try Task.checkCancellation()
        guard auth.context() == context else { throw CancellationError() }
        _ = try auth.authorization(for: context)
    }
}
