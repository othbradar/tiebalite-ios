import Foundation

struct NativeWriteResponse: Sendable {
    let response: HTTPResponse
    let state: NativeWriteResponseState?
}

/// Reuses the existing URLSession transport. Capture is scoped to one request;
/// the repository must accept the state only at its parsed-response boundary.
struct NativeWriteTransport: Sendable {
    let loader: any HTTPDataLoading

    func execute(_ request: HTTPRequest) async throws -> NativeWriteResponse {
        let collector = NativeWriteResponseCollector(loader: loader)
        let response = try await URLSessionHTTPClient(loader: collector).execute(request)
        return await NativeWriteResponse(response: response, state: collector.state)
    }
}

private actor NativeWriteResponseCollector: HTTPDataLoading {
    let loader: any HTTPDataLoading
    private(set) var state: NativeWriteResponseState?

    init(loader: any HTTPDataLoading) { self.loader = loader }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        let result = try await loader.data(for: request, maximumByteCount: maximumByteCount)
        try Task.checkCancellation()
        if let response = result.1 as? HTTPURLResponse, acceptsState(request, response: response) {
            state = NativeWriteResponseState(headerValue: response.value(forHTTPHeaderField: "Set-Cookie"))
        }
        return result
    }

    private func acceptsState(_ request: URLRequest, response: HTTPURLResponse) -> Bool {
        guard let url = request.url,
              request.httpMethod == "POST", url.scheme == "https", url.host == "tiebac.baidu.com",
              ["/c/c/post/add", "/c/c/thread/add"].contains(url.path),
              response.url == url, (200..<300).contains(response.statusCode) else { return false }
        return true
    }
}
