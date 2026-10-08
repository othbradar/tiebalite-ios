import Foundation

/// Observes the existing account/TBS request only. The caller retains its
/// decoder, preparation ordering and cancellation policy; no retry is added.
@MainActor
final class NativePreparationHTTPClient: HTTPClient {
    private let transport: NativeWriteTransport
    private let runtime: any NativeWriteRuntimeProviding
    private let validateAuthorization: @MainActor @Sendable () throws -> Void

    init(loader: any HTTPDataLoading, runtime: any NativeWriteRuntimeProviding,
         validateAuthorization: @escaping @MainActor @Sendable () throws -> Void) {
        transport = NativeWriteTransport(loader: loader)
        self.runtime = runtime
        self.validateAuthorization = validateAuthorization
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        try Task.checkCancellation()
        try validateAuthorization()
        guard request.method == .post, request.url.scheme == "https", request.url.host == "tiebac.baidu.com",
              request.url.query == nil, let api = NativeWriteAPI(rawValue: request.url.path),
              api == .account || api == .tbs || api == .imageUpload else { throw NativeTBSError.invalidRequestContext }
        let result = try await transport.execute(request) { [self] metrics in
            try Task.checkCancellation()
            try validateAuthorization()
            runtime.requestMetrics = metrics
        }
        try Task.checkCancellation()
        try validateAuthorization()
        if let measurement = result.measurement,
           let metrics = NativePreparationResponseMetrics.decode(result.response, api: api, measurement: measurement) {
            runtime.requestMetrics = metrics
        }
        return result.response
    }
}
