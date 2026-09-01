import Foundation

#if TEST_SUPPORT
@testable import TiebaLite

actor HarnessCapturingImageLoader: ImageLoading {
    private let payload: ImagePayload
    private var requests: [ImageRequest] = []

    init(payload: ImagePayload) {
        self.payload = payload
    }

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        try Task.checkCancellation()
        requests.append(request)
        return payload
    }

    func recordedRequests() -> [ImageRequest] {
        requests
    }
}

struct HarnessFailingImageLoader: ImageLoading {
    let error: ImageLoadingError

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        throw error
    }
}

final class HarnessCancellationAsImageFailureLoader: ImageLoading, Sendable {
    private let error: ImageLoadingError
    private let started = HarnessContinuationGate<Void>()
    private let response = HarnessContinuationGate<ImagePayload>()

    init(error: ImageLoadingError) {
        self.error = error
    }

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        started.succeed(())
        return try await withTaskCancellationHandler {
            try await response.wait()
        } onCancel: { [error] in
            response.fail(error)
        }
    }

    func waitUntilStarted() async throws {
        try await started.wait()
    }
}
#endif
