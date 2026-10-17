import Foundation

extension AppCompositionRoot {
    func makeContentActionStore() -> ContentActionStore {
#if DEBUG
        if case .fixture = environment.readingDataSourceMode {
            return ContentActionStore(repository: ContentActionFixtureRepository(), ledger: .init(file: nil),
                                      context: { .init(namespace: "fixture", revision: 1) }, account: { 1_100_001 })
        }
#endif
        let auth = authContextProvider
        let provider = ContentActionAccountProvider(auth: auth, store: currentAccountStore, client: environment.httpClient)
        let account: @MainActor () async throws -> Int64 = { try await provider.current() }
        return ContentActionStore(repository: ContentActionAppRepository(auth: auth, client: environment.httpClient, account: account),
                                  ledger: .production(), context: { auth.contentCacheContext }, account: account)
    }
    func invalidateRemovedContent() async {
        let removals = ContentRemovalVisibility.shared
        await contentCacheForProfiles.excludeConfirmedRemovals(removals.targets, dates: removals.dates)
    }
}

/// An independent runtime; this adapter never uses the posting service instance.
@MainActor
private final class ContentActionAppRepository: ContentActionRepository {
    let auth: SessionAuthContextProvider
    let client: any HTTPClient
    let account: @MainActor () async throws -> Int64
    let runtime = NativeWriteAppRuntime()
    init(auth: SessionAuthContextProvider, client: any HTTPClient, account: @escaping @MainActor () async throws -> Int64) {
        self.auth = auth; self.client = client; self.account = account
    }
    func inspect(_ target: ContentActionTarget) async throws -> ContentActionInspection {
        let context = auth.context(), userID = try await account()
        let response = try await execute(.inspect(target), account: userID, context: context)
        return try NativeContentActionProtocol.inspect(response, target: target, account: userID)
    }
    func like(_ inspection: ContentActionInspection, selected: Bool) async throws {
        try await write(.like(inspection, selected), inspection: inspection)
    }
    func delete(_ inspection: ContentActionInspection) async throws {
        guard inspection.canDelete else { throw ContentActionFailure.unavailable }
        try await write(.delete(inspection), inspection: inspection)
    }
    private func write(_ operation: NativeContentActionProtocol.Operation, inspection: ContentActionInspection) async throws {
        let context = auth.context()
        guard try await account() == inspection.accountID else { throw ContentActionFailure.loginRequired }
        let response = try await execute(operation, account: inspection.accountID, context: context)
        try NativeContentActionProtocol.acknowledge(response)
    }
    private func execute(_ operation: NativeContentActionProtocol.Operation, account userID: Int64,
                         context: AuthContext) async throws -> HTTPResponse {
        guard case .active = context else { throw ContentActionFailure.loginRequired }
        let authorization = try auth.authorization(for: context)
        try await runtime.prepare()
        var account: TextWriteAccount?
        if operation.isWrite, let namespace = auth.contentCacheContext.namespace {
            account = try await NativeWriteAccountVault.shared.load(namespace: namespace)
            if account?.userID != String(userID) { account = nil }
        }
        if operation.isWrite && account?.tbs.isEmpty != false {
            let value = try runtime.context(for: .tbs, authorization: authorization, account: nil)
            var common = NativeWriteCommonParameters(), metrics = runtime.requestMetrics
            let fields = try common.prepareTBS(value.common, authorization: authorization, metrics: &metrics)
            let request = try NativeTBSRequest.make(parameters: fields, context: .init(
                userAgent: value.http.userAgent, acceptLanguage: value.http.acceptLanguage,
                clientLogID: value.http.clientLogID, cookies: value.http.cookies))
            try validate(context)
            let tbs = try NativeTBSResponseDecoder.decode(await client.execute(request))
            account = TextWriteAccount(userID: String(userID), tbs: tbs, nameShow: "")
        }
        try validate(context)
        let value = try runtime.context(for: .tbs, authorization: authorization, account: account)
        let request = try NativeContentActionProtocol.request(operation, runtime: value, tbs: account?.tbs ?? "")
        let response: HTTPResponse
        do { response = try await client.execute(request) } catch {
            if operation.isWrite { throw ContentActionFailure.outcomeUnknown }
            throw error
        }
        try validate(context)
        return response
    }
    private func validate(_ context: AuthContext) throws {
        try Task.checkCancellation()
        guard auth.context() == context else { throw CancellationError() }
        _ = try auth.authorization(for: context)
    }
}
