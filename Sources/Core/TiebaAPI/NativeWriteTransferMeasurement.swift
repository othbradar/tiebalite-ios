import Foundation

/// Actual successful-transport measurements, not payload-size estimates. Only
/// the native write transport opts in; other HTTP callers keep their loader.
struct NativeWriteTransferMeasurement: Equatable, Sendable {
    let durationSeconds: Double
    let uploadBytes: UInt32
    let downloadBytes: UInt32

    func parsedMetrics(api: String, errorCode: Int32, statusCode: Int = 200) -> NativeWriteRequestMetrics {
        // This native Error descriptor has no logid field. Do not substitute
        // the outgoing client_logid for a server response identifier.
        .init(api: api.hasPrefix("/") ? String(api.dropFirst()) : api, logID: 0,
              cost: durationSeconds * 1_000, result: errorCode > 0 ? Int64(errorCode) : (statusCode == 200 ? 0 : Int64(statusCode)),
              uploadBytes: uploadBytes, downloadBytes: downloadBytes)
    }

    func rejectedHTTPMetrics(api: String) -> NativeWriteRequestMetrics {
        // The native default AF serializer rejects non-2xx before body parsing.
        // Its -1011 error follows the non-timeout failure branch, without bytes.
        .init(api: api.hasPrefix("/") ? String(api.dropFirst()) : api, logID: 0,
              cost: durationSeconds * 1_000, result: -1, uploadBytes: 0, downloadBytes: 0)
    }

    func parseFailureMetrics(api: String) -> NativeWriteRequestMetrics {
        .init(api: api.hasPrefix("/") ? String(api.dropFirst()) : api, logID: 0,
              cost: durationSeconds * 1_000, result: -3, uploadBytes: uploadBytes, downloadBytes: downloadBytes)
    }
}

struct NativeWriteMeasuredData: Sendable {
    let data: Data
    let response: URLResponse
    let measurement: NativeWriteTransferMeasurement?
}

protocol NativeWriteTransferLoading: HTTPDataLoading {
    func measuredData(for request: URLRequest, maximumByteCount: Int) async throws -> NativeWriteMeasuredData
}

extension NativeWriteTransferLoading {
    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        let result = try await measuredData(for: request, maximumByteCount: maximumByteCount)
        return (result.data, result.response)
    }
}
