import Foundation

protocol HTTPDataLoading: Sendable {
    func data(
        for request: URLRequest,
        maximumByteCount: Int
    ) async throws -> (Data, URLResponse)
}

enum HTTPRedirectDecision {
    static func redirectedRequest(
        _ proposedRequest: URLRequest,
        policy: HTTPRedirectPolicy
    ) -> URLRequest? {
        _ = proposedRequest
        switch policy {
        case .reject:
            return nil
        }
    }
}

actor URLSessionHTTPClient: HTTPClient {
    private static let responseHeaderAllowlist: Set<String> = [
        "content-length",
        "content-type",
        "etag",
        "last-modified",
        "retry-after"
    ]

    private let loader: any HTTPDataLoading

    init(loader: any HTTPDataLoading) {
        self.loader = loader
    }

    static func production() -> URLSessionHTTPClient {
        URLSessionHTTPClient(
            loader: URLSessionDataLoader(
                configuration: makeEphemeralConfiguration()
            )
        )
    }

    static func makeEphemeralConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        return configuration
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        try Task.checkCancellation()

        var urlRequest = URLRequest(
            url: request.url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: request.timeout
        )
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.httpShouldHandleCookies = false
        for (name, value) in request.headers.sorted(by: { $0.key < $1.key }) {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (data, response) = try await loader.data(
                for: urlRequest,
                maximumByteCount: request.responseBodyLimit
            )
            try Task.checkCancellation()
            guard data.count <= request.responseBodyLimit else {
                throw HTTPClientError.responseTooLarge(
                    limit: request.responseBodyLimit
                )
            }
            guard let response = response as? HTTPURLResponse else {
                throw HTTPClientError.malformedResponse
            }

            return HTTPResponse(
                statusCode: response.statusCode,
                headers: Self.allowlistedHeaders(from: response),
                body: data
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPClientError {
            throw error
        } catch let error as URLError {
            throw Self.map(error)
        } catch {
            throw HTTPClientError.transport
        }
    }

    private static func allowlistedHeaders(
        from response: HTTPURLResponse
    ) -> [String: String] {
        var headers: [String: String] = [:]
        for (rawName, rawValue) in response.allHeaderFields {
            guard let name = rawName as? String,
                  let value = rawValue as? String else {
                continue
            }
            let normalizedName = name.lowercased()
            guard responseHeaderAllowlist.contains(normalizedName) else {
                continue
            }
            headers[normalizedName] = value
        }
        return headers
    }

    private static func map(_ error: URLError) -> any Error {
        switch error.code {
        case .cancelled:
            CancellationError()
        case .cannotConnectToHost,
             .cannotFindHost,
             .dataNotAllowed,
             .internationalRoamingOff,
             .networkConnectionLost,
             .notConnectedToInternet:
            HTTPClientError.offline
        case .timedOut:
            HTTPClientError.timedOut
        default:
            HTTPClientError.transport
        }
    }
}

final class URLSessionDataLoader: NSObject, HTTPDataLoading,
    URLSessionTaskDelegate, Sendable {
    private let session: URLSession

    init(configuration: URLSessionConfiguration) {
        session = URLSession(
            configuration: configuration,
            delegate: nil,
            delegateQueue: nil
        )
        super.init()
    }

    func data(
        for request: URLRequest,
        maximumByteCount: Int
    ) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(
            for: request,
            delegate: self
        )
        if response.expectedContentLength > Int64(maximumByteCount) {
            throw HTTPClientError.responseTooLarge(limit: maximumByteCount)
        }

        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        for try await byte in bytes {
            guard data.count < maximumByteCount else {
                throw HTTPClientError.responseTooLarge(limit: maximumByteCount)
            }
            data.append(byte)
        }
        return (data, response)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        _ = session
        _ = task
        _ = response
        completionHandler(
            HTTPRedirectDecision.redirectedRequest(
                request,
                policy: .reject
            )
        )
    }
}
