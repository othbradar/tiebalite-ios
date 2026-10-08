import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteTransportTests {
    @Test
    func nativeEnvelopeReachesTransportUnchangedWithOneAttempt() async throws {
        let loader = NativeWriteTransportLoader()
        let request = try NativeWriteHTTPRequest.makeRequest(
            kind: .threadReply, business: ["content": "Synthetic reply"], common: [:],
            context: NativeWriteHTTPContext(userAgent: "FixtureNativeAgent", acceptLanguage: nil,
                                            clientLogID: 42, timeout: 19, responseState: nil,
                                            cookies: NativeWriteRequestCookies(
                                                networkStatus: 1, wifiKeepAlive: true, cellularKeepAlive: false,
                                                smallFlow: false, smallFlowValue: nil)),
            boundary: "Boundary+0123456789ABCDEF")
        _ = try await NativeWriteTransport(loader: loader).execute(request)
        let recorded = try #require(await loader.requests.first)
        #expect(recorded.value(forHTTPHeaderField: "Cookie") == "ka=open")
        #expect(await loader.requests.count == 1)
        #expect(recorded.url == request.url && recorded.httpBody == request.body)
        #expect(recorded.timeoutInterval == request.timeout && !recorded.httpShouldHandleCookies)
        let actualHeaders = recorded.allHTTPHeaderFields ?? [:]
        #expect(actualHeaders.count == request.headers.count)
        for (name, value) in request.headers {
            #expect(recorded.value(forHTTPHeaderField: name) == value)
        }
    }

    @Test
    func nativeTransportCapturesOnlySelectedStateAndExecutesOneRequest() async throws {
        let loader = NativeWriteTransportLoader()
        let transport = NativeWriteTransport(loader: loader)
        let request = try request()
        let result = try await transport.execute(request)
        #expect(result.state?.requestHeaders == ["svcp_stk": "fixture-state"])
        #expect(result.response.headers == ["content-type": "application/protobuf"])
        #expect(result.response.body == Data([1, 2, 3]))
        let recorded = try #require(await loader.requests.first)
        #expect(await loader.requests.count == 1)
        #expect(recorded.url == request.url && recorded.httpMethod == "POST")
        #expect(recorded.httpBody == request.body)
        #expect(!recorded.httpShouldHandleCookies)
        #expect(recorded.allHTTPHeaderFields?["svcp_stk"] == nil)
    }

    @Test(arguments: ["/c/c/thread/add", "/c/s/tbs", "/c/u/user/profile"])
    func responseCaptureIsLimitedToNativeWrites(_ path: String) async throws {
        let result = try await NativeWriteTransport(loader: NativeWriteTransportLoader()).execute(request(path: path))
        #expect((result.state != nil) == (path == "/c/c/thread/add"))
        #expect(result.response.headers["set-cookie"] == nil)
    }

    @Test
    func wrongDestinationMethodResponseURLAndHTTPFailureDoNotReturnState() async throws {
        let ordinary = NativeWriteTransport(loader: NativeWriteTransportLoader())
        #expect(try await ordinary.execute(request(host: "fixture.invalid")).state == nil)
        #expect(try await ordinary.execute(request(method: .get)).state == nil)
        let wrongURL = NativeWriteTransport(loader: NativeWriteTransportLoader(responseHost: "fixture.invalid"))
        #expect(try await wrongURL.execute(request()).state == nil)
        let serverError = NativeWriteTransport(loader: NativeWriteTransportLoader(status: 500))
        #expect(try await serverError.execute(request()).state == nil)
    }

    @Test
    func concurrentResponsesHaveSeparateCollectors() async throws {
        let loader = NativeWriteTransportLoader(stateFromQuery: true)
        let transport = NativeWriteTransport(loader: loader)
        async let first = transport.execute(request(query: "first"))
        async let second = transport.execute(request(query: "second"))
        let results = try await (first, second)
        #expect(results.0.state?.requestHeaders == ["svcp_stk": "fixture-first"])
        #expect(results.1.state?.requestHeaders == ["svcp_stk": "fixture-second"])
        #expect(await loader.requests.count == 2)
    }

    @Test
    func transportLimitsAndCancellationRemainInForce() async throws {
        let oversized = NativeWriteTransport(loader: NativeWriteTransportLoader())
        await #expect(throws: HTTPClientError.responseTooLarge(limit: 2)) {
            try await oversized.execute(request(limit: 2))
        }
        let cancelled = NativeWriteTransport(loader: NativeWriteTransportLoader(cancelled: true))
        await #expect(throws: CancellationError.self) { try await cancelled.execute(request()) }
    }

    private func request(host: String = "tiebac.baidu.com", path: String = "/c/c/post/add",
                         method: HTTPMethod = .post, query: String = "", limit: Int = 1_024) throws -> HTTPRequest {
        let url = try #require(URL(string: "https://\(host)\(path)?\(query)"))
        return try HTTPRequest(method: method, url: url, body: Data([4, 5]), responseBodyLimit: limit)
    }
}

private actor NativeWriteTransportLoader: HTTPDataLoading {
    private(set) var requests: [URLRequest] = []
    let responseHost: String?
    let status: Int
    let stateFromQuery: Bool
    let cancelled: Bool

    init(responseHost: String? = nil, status: Int = 200, stateFromQuery: Bool = false, cancelled: Bool = false) {
        self.responseHost = responseHost
        self.status = status
        self.stateFromQuery = stateFromQuery
        self.cancelled = cancelled
    }

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        requests.append(request)
        if cancelled { throw URLError(.cancelled) }
        let requestURL = try #require(request.url)
        var components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        if let responseHost { components.host = responseHost }
        let url = try #require(components.url)
        let token = stateFromQuery ? "fixture-\(requestURL.query ?? "missing")" : "fixture-state"
        let response = try #require(HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [
                "Content-Type": "application/protobuf", "Set-Cookie": "__ymg_scsc=\(token); Path=/",
                "Authorization": "fixture-unrelated"
            ]))
        return (Data([1, 2, 3]), response)
    }
}
