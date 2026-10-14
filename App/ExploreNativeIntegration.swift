import Foundation

/// Independent read-only runtime; cannot change the posting runtime's metrics,
/// account preparation, receipts or transport state. No login/TBS/write requests.
@MainActor
final class ExploreNativeClient {
    let auth: SessionAuthContextProvider
    private let runtime = NativeWriteAppRuntime()

    init(auth: SessionAuthContextProvider) { self.auth = auth }

    func request(_ feed: ExploreFeed, cursor: ExploreCursor?, context: AuthContext) async throws -> HTTPRequest {
        guard auth.context() == context else { throw CancellationError() }
        let active: Bool
        let authorization: SessionAuthorization
        if case .active = context {
            active = true; authorization = try auth.authorization(for: context)
        } else {
            guard feed == .hot else { throw ExploreFailure.loginRequired }
            active = false; authorization = .init(bduss: "", stoken: "")
        }
        try await runtime.prepare()
        guard auth.context() == context else { throw CancellationError() }
        // Sign optimization is disabled in this explicit runtime. The API value
        // selects that branch only; .tbs here does not perform a TBS request.
        let value = try runtime.context(for: .tbs, authorization: authorization, account: nil)
        let business = try ExploreFeedProtocol.business(feed, cursor: cursor)
        var parameters = NativeWriteStaticCommonParameters()
        let fields = parameters.parameters(value.common.staticValues, mode: value.common.staticMode)
        var metrics = NativeWriteRequestMetrics(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0)
        var common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: fields, business: business, context: value.common.dynamicValues, metrics: &metrics)
        if !active { common.removeValue(forKey: "BDUSS"); common.removeValue(forKey: "stoken") }
        common = NativeWriteSigning.common(common, business: business, metadata: value.common.metadata)
        return try ExploreFeedProtocol.request(feed, business: business, common: common,
                                               context: value.http, boundary: value.multipartBoundary)
    }
}
