import Foundation

#if TEST_SUPPORT
@testable import TiebaLite

enum HarnessImageDataOutcome: Sendable {
    case response(
        statusCode: Int,
        headers: [String: String],
        body: Data
    )
    case urlError(URLError.Code)
}

actor HarnessImageDataLoader: HTTPDataLoading {
    private var outcomes: [URL: [HarnessImageDataOutcome]]
    private var requests: [URLRequest] = []

    init(outcomes: [URL: [HarnessImageDataOutcome]]) {
        self.outcomes = outcomes
    }

    func data(
        for request: URLRequest,
        maximumByteCount: Int
    ) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        requests.append(request)
        guard let url = request.url,
              var queued = outcomes[url],
              !queued.isEmpty else {
            throw URLError(.resourceUnavailable)
        }
        let outcome = queued.removeFirst()
        outcomes[url] = queued
        switch outcome {
        case let .response(statusCode, headers, body):
            guard body.count <= maximumByteCount else {
                throw HTTPClientError.responseTooLarge(
                    limit: maximumByteCount
                )
            }
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            ) else {
                throw URLError(.badServerResponse)
            }
            return (body, response)
        case let .urlError(code):
            throw URLError(code)
        }
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}

actor HarnessBlockingImageDataLoader: HTTPDataLoading {
    private let started = HarnessContinuationGate<Void>()
    private let response = HarnessContinuationGate<(Data, URLResponse)>()
    private var requests: [URLRequest] = []

    func data(
        for request: URLRequest,
        maximumByteCount: Int
    ) async throws -> (Data, URLResponse) {
        _ = maximumByteCount
        requests.append(request)
        started.succeed(())
        return try await withTaskCancellationHandler {
            try await response.wait()
        } onCancel: {
            response.cancel()
        }
    }

    func waitUntilStarted() async throws {
        try await started.wait()
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
#endif
