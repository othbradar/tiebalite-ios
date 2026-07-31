import Foundation

enum EndpointWireFailure: Error, Equatable, Sendable {
    case server(code: Int)
}

enum EndpointTransportFailure: Equatable, Sendable {
    case malformedResponse
    case offline
    case timedOut
    case transport
    case unavailable
}

enum EndpointExecutionError: Error, Equatable, Sendable {
    case authentication
    case decode
    case http(statusCode: Int)
    case mapping
    case responseTooLarge(limit: Int)
    case server(code: Int)
    case transport(EndpointTransportFailure)
    case unsupportedContent(actualMIMEType: String?)
}

struct EndpointPipeline<Wire: Sendable, Domain: Sendable>: Sendable {
    private let decode: @Sendable (Data) throws -> Wire
    private let transform: @Sendable (Wire) throws -> Domain

    init(
        decode: @escaping @Sendable (Data) throws -> Wire,
        map: @escaping @Sendable (Wire) throws -> Domain
    ) {
        self.decode = decode
        transform = map
    }

    func map(
        _ response: HTTPResponse,
        for endpoint: EndpointDescriptor
    ) throws -> Domain {
        guard (200..<300).contains(response.statusCode) else {
            throw EndpointExecutionError.http(statusCode: response.statusCode)
        }
        guard response.body.count <= endpoint.responseBodyLimit else {
            throw EndpointExecutionError.responseTooLarge(
                limit: endpoint.responseBodyLimit
            )
        }
        try validateContentType(response, endpoint: endpoint)

        let wire: Wire
        do {
            wire = try decode(response.body)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as EndpointWireFailure {
            switch failure {
            case let .server(code):
                throw EndpointExecutionError.server(code: code)
            }
        } catch {
            throw EndpointExecutionError.decode
        }

        do {
            return try transform(wire)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw EndpointExecutionError.mapping
        }
    }

    private func validateContentType(
        _ response: HTTPResponse,
        endpoint: EndpointDescriptor
    ) throws {
        guard endpoint.responseFamily != .empty else {
            return
        }
        let rawMIMEType = response.headers.first { key, _ in
            key.caseInsensitiveCompare("content-type") == .orderedSame
        }?.value
        let normalizedMIMEType = rawMIMEType?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let normalizedMIMEType,
              endpoint.allowedResponseMIMETypes.contains(normalizedMIMEType) else {
            throw EndpointExecutionError.unsupportedContent(
                actualMIMEType: normalizedMIMEType
            )
        }
    }
}

struct FixtureEndpointAdapter<Wire: Sendable, Domain: Sendable>: Sendable {
    private let endpoint: EndpointDescriptor
    private let pipeline: EndpointPipeline<Wire, Domain>

    init(
        endpoint: EndpointDescriptor,
        pipeline: EndpointPipeline<Wire, Domain>
    ) {
        self.endpoint = endpoint
        self.pipeline = pipeline
    }

    func map(_ data: Data, mimeType: String) throws -> Domain {
        try pipeline.map(
            HTTPResponse(
                statusCode: 200,
                headers: ["content-type": mimeType],
                body: data
            ),
            for: endpoint
        )
    }
}

struct EndpointExecutor: Sendable {
    private let client: any HTTPClient
    private let requestBuilder: EndpointRequestBuilder

    init(
        client: any HTTPClient,
        requestBuilder: EndpointRequestBuilder
    ) {
        self.client = client
        self.requestBuilder = requestBuilder
    }

    func execute<Wire: Sendable, Domain: Sendable>(
        endpoint: EndpointDescriptor,
        authentication: AuthContext,
        body: EndpointRequestBody,
        pipeline: EndpointPipeline<Wire, Domain>
    ) async throws -> Domain {
        try Task.checkCancellation()

        let request: HTTPRequest
        do {
            request = try await requestBuilder.makeRequest(
                endpoint: endpoint,
                authentication: authentication,
                body: body
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch is RequestAuthorizationError {
            throw EndpointExecutionError.authentication
        }

        let response: HTTPResponse
        do {
            response = try await client.execute(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPClientError {
            throw Self.map(error)
        }
        try Task.checkCancellation()
        return try pipeline.map(response, for: endpoint)
    }

    private static func map(_ error: HTTPClientError) -> EndpointExecutionError {
        switch error {
        case .malformedResponse:
            .transport(.malformedResponse)
        case .offline:
            .transport(.offline)
        case let .responseTooLarge(limit):
            .responseTooLarge(limit: limit)
        case let .server(statusCode):
            .http(statusCode: statusCode)
        case .timedOut:
            .transport(.timedOut)
        case .transport:
            .transport(.transport)
        case .unavailable:
            .transport(.unavailable)
        }
    }
}
