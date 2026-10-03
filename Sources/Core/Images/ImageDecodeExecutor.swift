import Foundation

/// ImageIO work uses two worker operations, never the main actor or the loader's serial executor.
enum ImageDecodeExecutor {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "TiebaLite.image-decode"
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()

    static func run<Value: Sendable>(_ operation: @escaping @Sendable () throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        let value: Value = try await withCheckedThrowingContinuation { continuation in
            queue.addOperation {
                continuation.resume(with: Result { try operation() })
            }
        }
        try Task.checkCancellation()
        return value
    }
}
