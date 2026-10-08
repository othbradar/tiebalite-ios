import Foundation

struct NativeWriteResponse: Sendable {
    let response: HTTPResponse
    let state: NativeWriteResponseState?
    let measurement: NativeWriteTransferMeasurement?
}

/// Reuses the existing URLSession transport. Capture is scoped to one request;
/// the repository must accept the state only at its parsed-response boundary.
struct NativeWriteTransport: Sendable {
    let loader: any HTTPDataLoading

    func execute(_ request: HTTPRequest,
                 onFailure: (@MainActor @Sendable (NativeWriteRequestMetrics) throws -> Void)? = nil) async throws -> NativeWriteResponse {
        let collector = NativeWriteResponseCollector(loader: loader)
        do {
            let response = try await URLSessionHTTPClient(loader: collector).execute(request)
            if !(200..<300).contains(response.statusCode), let onFailure, let measurement = await collector.measurement {
                try Task.checkCancellation()
                try await onFailure(measurement.rejectedHTTPMetrics(api: request.url.path))
            }
            return await NativeWriteResponse(response: response, state: collector.state, measurement: collector.measurement)
        } catch {
            try Task.checkCancellation()
            if let onFailure, let failure = await collector.failure {
                try await onFailure(failure.metrics(api: request.url.path))
            }
            throw error
        }
    }
}

private actor NativeWriteResponseCollector: HTTPDataLoading {
    let loader: any HTTPDataLoading
    private(set) var state: NativeWriteResponseState?
    private(set) var measurement: NativeWriteTransferMeasurement?
    private(set) var failure: NativeWriteTransferFailure?

    init(loader: any HTTPDataLoading) { self.loader = loader }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        let result: (Data, URLResponse)
        if let measured = loader as? any NativeWriteTransferLoading {
            do {
                let captured = try await measured.measuredData(for: request, maximumByteCount: maximumByteCount)
                result = (captured.data, captured.response)
                measurement = captured.measurement
            } catch let failed as NativeWriteTransferFailure {
                failure = failed
                throw failed.underlying
            }
        } else {
            result = try await loader.data(for: request, maximumByteCount: maximumByteCount)
        }
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
