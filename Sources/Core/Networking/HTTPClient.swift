import Foundation

enum HTTPMethod: String, Equatable, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"
}

enum HTTPRequestValidationError: Error, Equatable, Sendable {
    case embeddedCredentials
    case fragmentNotAllowed
    case invalidHeader
    case invalidResponseBodyLimit
    case invalidTimeout
    case insecureTransport
    case missingHost
}

enum HTTPRedirectPolicy: Equatable, Sendable {
    case reject
}

struct HTTPRequest: Equatable, Sendable {
    let method: HTTPMethod
    let url: URL
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    let responseBodyLimit: Int
    let redirectPolicy: HTTPRedirectPolicy

    init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30,
        responseBodyLimit: Int = 8 * 1_024 * 1_024,
        redirectPolicy: HTTPRedirectPolicy = .reject
    ) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw HTTPRequestValidationError.insecureTransport
        }
        guard url.host?.isEmpty == false else {
            throw HTTPRequestValidationError.missingHost
        }
        guard url.user == nil, url.password == nil else {
            throw HTTPRequestValidationError.embeddedCredentials
        }
        guard url.fragment == nil else {
            throw HTTPRequestValidationError.fragmentNotAllowed
        }
        guard headers.allSatisfy({
            Self.isValidHeader(name: $0.key, value: $0.value)
        }) else {
            throw HTTPRequestValidationError.invalidHeader
        }
        guard timeout.isFinite, timeout > 0 else {
            throw HTTPRequestValidationError.invalidTimeout
        }
        guard responseBodyLimit > 0 else {
            throw HTTPRequestValidationError.invalidResponseBodyLimit
        }

        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.responseBodyLimit = responseBodyLimit
        self.redirectPolicy = redirectPolicy
    }

    private static func isValidHeader(
        name: String,
        value: String
    ) -> Bool {
        guard !name.isEmpty,
              name.utf8.allSatisfy(Self.isHeaderNameByte),
              value.utf8.allSatisfy({ byte in
                  byte == 9 || (32...126).contains(byte)
              }) else {
            return false
        }
        return true
    }

    private static func isHeaderNameByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 33, 35...39, 42, 43, 45, 46, 48...57, 65...90, 94...122, 124, 126:
            true
        default:
            false
        }
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
    case responseTooLarge(limit: Int)
    case server(statusCode: Int)
    case timedOut
    case transport
    case unavailable

    var safeDescription: String {
        switch self {
        case .malformedResponse:
            "malformed"
        case .offline:
            "offline"
        case let .responseTooLarge(limit):
            "response-too-large-\(limit)"
        case let .server(statusCode):
            "server-\(statusCode)"
        case .timedOut:
            "timeout"
        case .transport:
            "transport"
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
