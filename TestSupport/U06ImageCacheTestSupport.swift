import Foundation

#if TEST_SUPPORT
@testable import TiebaLite

actor ImageWorkTestOrder {
    private(set) var values: [Int] = []
    func append(_ value: Int) { values.append(value) }
}

actor ImageCacheTestTransport: HTTPDataLoading {
    let bytes: Data
    let started = HarnessContinuationGate<Void>()
    let released = HarnessContinuationGate<Void>()
    private let held: Bool
    private(set) var requests = 0
    private(set) var cancelled = 0
    private var offline = false

    init(bytes: Data, held: Bool = false) { self.bytes = bytes; self.held = held }
    func setOffline() { offline = true }
    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        requests += 1
        started.succeed(())
        if held {
            // Deliberately uncooperative transport proves an invalidated completion cannot repopulate disk.
            try await withTaskCancellationHandler { try await released.wait() } onCancel: {
                Task { await self.markCancelled() }
            }
        }
        if offline { throw URLError(.notConnectedToInternet) }
        guard let url = request.url, let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"]
        ) else { throw ImageLoadingError.transport }
        return (bytes, response)
    }
    private func markCancelled() { cancelled += 1 }
}
#endif
