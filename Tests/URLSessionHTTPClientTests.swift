import Foundation
import Synchronization
import Testing
@testable import TiebaLite

struct URLSessionHTTPClientTests {
    @Test
    func ephemeralConfigurationDisablesSharedCookiesAndCache() {
        let configuration = URLSessionHTTPClient.makeEphemeralConfiguration()

        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(configuration.urlCache == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(!configuration.waitsForConnectivity)
    }

    @Test
    func redirectPolicyRejectsEveryProposedLocation() throws {
        let locations = [
            "https://fixture.invalid/next",
            "https://other.invalid/next",
            "http://fixture.invalid/next"
        ]

        for location in locations {
            let url = try #require(URL(string: location))
            let request = URLRequest(url: url)
            #expect(
                HTTPRedirectDecision.redirectedRequest(
                    request,
                    policy: .reject
                ) == nil
            )
        }
    }

    @Test
    func productionLoaderDelegateRejectsEveryRedirect() throws {
        let origin = try #require(
            URL(string: "https://redirect-fixture.invalid/origin")
        )
        let target = try #require(
            URL(string: "https://redirect-target.invalid/private")
        )
        let response = try #require(
            HTTPURLResponse(
                url: origin,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": target.absoluteString]
            )
        )
        let configuration = URLSessionHTTPClient.makeEphemeralConfiguration()
        let loader = URLSessionDataLoader(configuration: configuration)
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: origin)
        let decision = Mutex<URLRequest?>(URLRequest(url: target))

        loader.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: target)
        ) { request in
            decision.withLock { storedRequest in
                storedRequest = request
            }
        }

        #expect(decision.withLock { $0 } == nil)
        task.cancel()
        session.invalidateAndCancel()
    }

    @Test
    func productionLoaderEnforcesContentLengthAndExactStreamingLimit() async throws {
        let oversizedURL = try #require(
            URL(string: "https://size-fixture.invalid/oversized")
        )
        HarnessURLProtocol.register(
            .response(
                statusCode: 200,
                headers: [
                    "Content-Length": "3",
                    "Content-Type": "application/octet-stream"
                ],
                body: Data([0x01, 0x02, 0x03])
            ),
            for: oversizedURL
        )
        let oversizedClient = makeProtocolBackedClient()
        let oversizedRequest = try HTTPRequest(
            method: .get,
            url: oversizedURL,
            responseBodyLimit: 2
        )
        await #expect(throws: HTTPClientError.responseTooLarge(limit: 2)) {
            try await oversizedClient.execute(oversizedRequest)
        }

        let unknownLengthURL = try #require(
            URL(string: "https://size-fixture.invalid/unknown-length")
        )
        HarnessURLProtocol.register(
            .response(
                statusCode: 200,
                headers: ["Content-Type": "application/octet-stream"],
                body: Data([0x01, 0x02, 0x03])
            ),
            for: unknownLengthURL
        )
        let unknownLengthClient = makeProtocolBackedClient()
        let unknownLengthRequest = try HTTPRequest(
            method: .get,
            url: unknownLengthURL,
            responseBodyLimit: 2
        )
        await #expect(throws: HTTPClientError.responseTooLarge(limit: 2)) {
            try await unknownLengthClient.execute(unknownLengthRequest)
        }

        let exactURL = try #require(
            URL(string: "https://size-fixture.invalid/exact")
        )
        HarnessURLProtocol.register(
            .response(
                statusCode: 200,
                headers: [
                    "Content-Length": "2",
                    "Content-Type": "application/octet-stream"
                ],
                body: Data([0x01, 0x02])
            ),
            for: exactURL
        )
        let exactClient = makeProtocolBackedClient()
        let exactRequest = try HTTPRequest(
            method: .get,
            url: exactURL,
            responseBodyLimit: 2
        )

        #expect(try await exactClient.execute(exactRequest).body == Data([0x01, 0x02]))
    }

    @Test
    func successBuildsBoundedRequestAndReturnsOnlyAllowlistedHeaders() async throws {
        let responseURL = try #require(URL(string: "https://fixture.invalid/data"))
        let response = try #require(
            HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "ETag": "fixture-tag",
                    "Set-Cookie": "private=value",
                    "X-Private": "secret"
                ]
            )
        )
        let loader = HarnessHTTPDataLoader(
            outcome: .response(Data("ok".utf8), response)
        )
        let client = URLSessionHTTPClient(loader: loader)
        let request = try makeRequest()

        let result = try await client.execute(request)

        #expect(result.statusCode == 200)
        #expect(result.body == Data("ok".utf8))
        #expect(result.headers == [
            "content-type": "application/json",
            "etag": "fixture-tag"
        ])
        let loadedRequest = try #require(await loader.lastRequest())
        #expect(loadedRequest.httpMethod == "POST")
        #expect(loadedRequest.timeoutInterval == 9)
        #expect(!loadedRequest.httpShouldHandleCookies)
        #expect(loadedRequest.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(await loader.lastMaximumByteCount() == 1_024)
    }

    @Test
    func transportMapsOfflineTimeoutMalformedAndBodyLimit() async throws {
        let request = try makeRequest(responseBodyLimit: 2)
        let cases: [(HarnessHTTPDataOutcome, HTTPClientError)] = [
            (.urlError(.notConnectedToInternet), .offline),
            (.urlError(.networkConnectionLost), .offline),
            (.urlError(.timedOut), .timedOut)
        ]

        for (outcome, expectedError) in cases {
            let client = URLSessionHTTPClient(
                loader: HarnessHTTPDataLoader(outcome: outcome)
            )
            do {
                _ = try await client.execute(request)
                Issue.record("Expected transport mapping failure")
            } catch let error as HTTPClientError {
                #expect(error == expectedError)
            } catch {
                Issue.record("Transport escaped the HTTP error taxonomy")
            }
        }

        let nonHTTPClient = URLSessionHTTPClient(
            loader: HarnessHTTPDataLoader(
                outcome: .response(
                    Data(),
                    URLResponse(
                        url: request.url,
                        mimeType: nil,
                        expectedContentLength: 0,
                        textEncodingName: nil
                    )
                )
            )
        )
        await #expect(throws: HTTPClientError.malformedResponse) {
            try await nonHTTPClient.execute(request)
        }

        let response = try #require(
            HTTPURLResponse(
                url: request.url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        let oversizedClient = URLSessionHTTPClient(
            loader: HarnessHTTPDataLoader(
                outcome: .response(Data([0x01, 0x02, 0x03]), response)
            )
        )
        await #expect(throws: HTTPClientError.responseTooLarge(limit: 2)) {
            try await oversizedClient.execute(request)
        }
    }

    @Test
    func cancellationRemainsCancellationError() async throws {
        let loader = HarnessBlockingHTTPDataLoader()
        let client = URLSessionHTTPClient(loader: loader)
        let request = try makeRequest()
        let task = Task {
            try await client.execute(request)
        }

        try await loader.waitUntilStarted()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(true)
        } catch {
            Issue.record("Cancellation was converted into a transport error")
        }
    }

    private func makeRequest(
        responseBodyLimit: Int = 1_024
    ) throws -> HTTPRequest {
        let url = try #require(URL(string: "https://fixture.invalid/data"))
        return try HTTPRequest(
            method: .post,
            url: url,
            headers: ["Content-Type": "application/octet-stream"],
            body: Data([0x01]),
            timeout: 9,
            responseBodyLimit: responseBodyLimit,
            redirectPolicy: .reject
        )
    }

    private func makeProtocolBackedClient() -> URLSessionHTTPClient {
        let configuration = URLSessionHTTPClient.makeEphemeralConfiguration()
        configuration.protocolClasses = [HarnessURLProtocol.self]
        return URLSessionHTTPClient(
            loader: URLSessionDataLoader(configuration: configuration)
        )
    }
}

private enum HarnessHTTPDataOutcome: Sendable {
    case response(Data, URLResponse)
    case urlError(URLError.Code)
}

private actor HarnessHTTPDataLoader: HTTPDataLoading {
    private let outcome: HarnessHTTPDataOutcome
    private var recordedRequest: URLRequest?
    private var recordedMaximumByteCount: Int?

    init(outcome: HarnessHTTPDataOutcome) {
        self.outcome = outcome
    }

    func data(
        for request: URLRequest,
        maximumByteCount: Int
    ) async throws -> (Data, URLResponse) {
        recordedRequest = request
        recordedMaximumByteCount = maximumByteCount
        switch outcome {
        case let .response(data, response):
            return (data, response)
        case let .urlError(code):
            throw URLError(code)
        }
    }

    func lastRequest() -> URLRequest? {
        recordedRequest
    }

    func lastMaximumByteCount() -> Int? {
        recordedMaximumByteCount
    }
}

private actor HarnessBlockingHTTPDataLoader: HTTPDataLoading {
    private let started = HarnessContinuationGate<Void>()
    private let response = HarnessContinuationGate<(Data, URLResponse)>()

    func data(
        for request: URLRequest,
        maximumByteCount: Int
    ) async throws -> (Data, URLResponse) {
        _ = request
        _ = maximumByteCount
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
}

private final class HarnessURLProtocol: URLProtocol {
    enum Stub: Sendable {
        case response(
            statusCode: Int,
            headers: [String: String],
            body: Data
        )
    }

    private struct State: Sendable {
        var stubs: [URL: Stub] = [:]
    }

    private static let state = Mutex(State())

    static func register(_ stub: Stub, for url: URL) {
        state.withLock { storage in
            storage.stubs[url] = stub
        }
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        return state.withLock { storage in
            storage.stubs[url] != nil
        }
    }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
            return
        }
        let stub = Self.state.withLock { storage -> Stub? in
            return storage.stubs[url]
        }
        guard let stub else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.resourceUnavailable)
            )
            return
        }

        switch stub {
        case let .response(statusCode, headers, body):
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            ) else {
                client?.urlProtocol(
                    self,
                    didFailWithError: URLError(.badServerResponse)
                )
                return
            }
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
    }
}
