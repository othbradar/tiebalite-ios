import Foundation

#if TEST_SUPPORT
@testable import TiebaLite

/// Deliberately ignores cancellation so tests can deliver a late response.
/// The normal HarnessMockHTTPClient correctly cancels and cannot model this race.
actor NativeTBSGateClient: HTTPClient {
    private(set) var requestCount = 0
    private var pending: CheckedContinuation<HTTPResponse, any Error>?
    private var observer: CheckedContinuation<Void, Never>?

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            observer?.resume()
            observer = nil
        }
    }

    func waitForRequest(number: Int = 1) async {
        guard requestCount < number else { return }
        await withCheckedContinuation { observer = $0 }
    }

    func complete(_ result: Result<HTTPResponse, any Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}

#endif
