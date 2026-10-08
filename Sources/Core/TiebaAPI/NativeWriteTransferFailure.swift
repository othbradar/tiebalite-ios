import Foundation

/// Local observation of an actual URL loading failure, never a retry or a
/// business receipt. The underlying error is unwrapped before HTTP mapping.
struct NativeWriteTransferFailure: Error, CustomStringConvertible, CustomDebugStringConvertible {
    let underlying: any Error
    let durationSeconds: Double
    let timedOut: Bool

    init?(error: any Error, durationSeconds: Double) {
        guard let urlError = error as? URLError, urlError.code != .cancelled,
              durationSeconds.isFinite, durationSeconds >= 0 else { return nil }
        underlying = error
        self.durationSeconds = durationSeconds
        timedOut = urlError.code == .timedOut
    }

    func metrics(api: String) -> NativeWriteRequestMetrics {
        // Native failure branches do not assign partial transaction byte counts.
        .init(api: api.hasPrefix("/") ? String(api.dropFirst()) : api, logID: 0,
              cost: durationSeconds * 1_000, result: timedOut ? -2 : -1, uploadBytes: 0, downloadBytes: 0)
    }

    var description: String { "NativeWriteTransferFailure(redacted)" }
    var debugDescription: String { description }
}
