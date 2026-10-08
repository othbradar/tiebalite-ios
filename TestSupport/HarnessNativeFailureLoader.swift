import Foundation
@testable import TiebaLite

/// Controlled URL failure metadata around the existing single-call harness.
struct HarnessNativeFailureLoader: NativeWriteTransferLoading {
    let base: NativeClientHarnessBridge
    func measuredData(for request: URLRequest, maximumByteCount: Int) async throws -> NativeWriteMeasuredData {
        do {
            let result = try await base.data(for: request, maximumByteCount: maximumByteCount)
            return .init(data: result.0, response: result.1, measurement: nil)
        } catch let error as HTTPClientError {
            let code: URLError.Code
            switch error {
            case .timedOut: code = .timedOut
            case .offline: code = .notConnectedToInternet
            default: throw error
            }
            if let measured = NativeWriteTransferFailure(error: URLError(code), durationSeconds: 0.25) { throw measured }
            throw error
        }
    }
}
