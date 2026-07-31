import Foundation

enum HTTPMethod: String, Equatable, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"
}

enum HTTPRequestValidationError: Error, Equatable, Sendable {
    case insecureTransport
    case missingHost
}

struct HTTPRequest: Equatable, Sendable {
    let method: HTTPMethod
    let url: URL
    let headers: [String: String]
    let body: Data?

    init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw HTTPRequestValidationError.insecureTransport
        }
        guard url.host?.isEmpty == false else {
            throw HTTPRequestValidationError.missingHost
        }

        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

struct HTTPResponse: Equatable, Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

enum HTTPClientError: Error, Equatable, Sendable {
    case malformedResponse
    case offline
    case server(statusCode: Int)
    case timedOut
    case unavailable

    var safeDescription: String {
        switch self {
        case .malformedResponse:
            "malformed"
        case .offline:
            "offline"
        case let .server(statusCode):
            "server-\(statusCode)"
        case .timedOut:
            "timeout"
        case .unavailable:
            "unavailable"
        }
    }
}

protocol HTTPClient: Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

struct DisabledHTTPClient: HTTPClient {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        _ = request
        try Task.checkCancellation()
        throw HTTPClientError.unavailable
    }
}
