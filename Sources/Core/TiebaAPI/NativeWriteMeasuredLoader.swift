import Foundation
import Synchronization

/// Opt-in observation around the existing bounded URLSession loader. Each call
/// has its own capture; no credentials, URLs or address metadata are retained.
struct NativeWriteMeasuredLoader: NativeWriteTransferLoading {
    let base: URLSessionDataLoader

    func measuredData(for request: URLRequest, maximumByteCount: Int) async throws -> NativeWriteMeasuredData {
        let delegate = NativeWriteTransferDelegate()
        let start = CFAbsoluteTimeGetCurrent()
        let result: (Data, URLResponse)
        do {
            result = try await base.data(for: request, maximumByteCount: maximumByteCount, delegate: delegate)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            _ = delegate.finish(durationSeconds: duration)
            try Task.checkCancellation()
            if let failure = NativeWriteTransferFailure(error: error, durationSeconds: duration) { throw failure }
            throw error
        }
        let duration = CFAbsoluteTimeGetCurrent() - start
        try Task.checkCancellation()
        return .init(data: result.0, response: result.1, measurement: delegate.finish(durationSeconds: duration))
    }
}

final class NativeWriteTransferDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private struct State: Sendable {
        var bytes: (upload: UInt32, download: UInt32)?
        var finished = false
    }
    private let state = Mutex(State())

    func record(networkLoad: Bool, requestHeader: Int64, requestBody: Int64,
                responseHeader: Int64, responseBody: Int64) {
        guard networkLoad, requestHeader >= 0, requestBody >= 0, responseHeader >= 0, responseBody >= 0 else { return }
        state.withLock {
            guard !$0.finished else { return }
            $0.bytes = (UInt32(truncatingIfNeeded: requestHeader &+ requestBody),
                        UInt32(truncatingIfNeeded: responseHeader &+ responseBody))
        }
    }

    func finish(durationSeconds: Double) -> NativeWriteTransferMeasurement? {
        state.withLock {
            guard !$0.finished else { return nil }
            $0.finished = true
            guard let bytes = $0.bytes, durationSeconds.isFinite else { return nil }
            $0.bytes = nil
            return .init(durationSeconds: durationSeconds, uploadBytes: bytes.upload, downloadBytes: bytes.download)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        for metric in metrics.transactionMetrics {
            record(networkLoad: metric.resourceFetchType == .networkLoad,
                   requestHeader: metric.countOfRequestHeaderBytesSent, requestBody: metric.countOfRequestBodyBytesSent,
                   responseHeader: metric.countOfResponseHeaderBytesReceived, responseBody: metric.countOfResponseBodyBytesReceived)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(HTTPRedirectDecision.redirectedRequest(request, policy: .reject))
    }
}
