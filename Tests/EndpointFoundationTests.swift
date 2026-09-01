import Foundation
import Testing
@testable import TiebaLite

struct HTTPRequestFoundationTests {
    @Test
    func requestRejectsUnsafeTransportAndInvalidResourceBounds() throws {
        let insecureURL = try #require(URL(string: "http://fixture.invalid/items"))
        #expect(throws: HTTPRequestValidationError.insecureTransport) {
            try HTTPRequest(method: .get, url: insecureURL)
        }

        let missingHostURL = try #require(URL(string: "https:///items"))
        #expect(throws: HTTPRequestValidationError.missingHost) {
            try HTTPRequest(method: .get, url: missingHostURL)
        }

        let secureURL = try #require(URL(string: "https://fixture.invalid/items"))
        let credentialURL = try #require(
            URL(string: "https://user:password@fixture.invalid/items")
        )
        #expect(throws: HTTPRequestValidationError.embeddedCredentials) {
            try HTTPRequest(method: .get, url: credentialURL)
        }
        let fragmentURL = try #require(
            URL(string: "https://fixture.invalid/items#private")
        )
        #expect(throws: HTTPRequestValidationError.fragmentNotAllowed) {
            try HTTPRequest(method: .get, url: fragmentURL)
        }
        #expect(throws: HTTPRequestValidationError.invalidHeader) {
            try HTTPRequest(
                method: .get,
                url: secureURL,
                headers: ["X-Fixture": "safe\r\nX-Injected: second"]
            )
        }
        #expect(throws: HTTPRequestValidationError.invalidTimeout) {
            try HTTPRequest(method: .get, url: secureURL, timeout: 0)
        }
        #expect(throws: HTTPRequestValidationError.invalidResponseBodyLimit) {
            try HTTPRequest(
                method: .get,
                url: secureURL,
                responseBodyLimit: 0
            )
        }
    }
}

struct EndpointRequestBuilderTests {
    @Test
    func descriptorRejectsHostPathAndResponsePolicyAmbiguity() throws {
        let identifier = try #require(EndpointID("fixture.items"))

        #expect(throws: EndpointDescriptorValidationError.invalidHost) {
            try EndpointDescriptor(
                id: identifier,
                method: .get,
                host: "user@fixture.invalid",
                path: "/items",
                bodyCodec: .none,
                responseFamily: .json,
                allowedResponseMIMETypes: ["application/json"],
                authentication: .anonymous,
                timeout: 10,
                responseBodyLimit: 1_024
            )
        }
        #expect(throws: EndpointDescriptorValidationError.invalidPath) {
            try EndpointDescriptor(
                id: identifier,
                method: .get,
                host: "fixture.invalid",
                path: "/safe/../private",
                bodyCodec: .none,
                responseFamily: .json,
                allowedResponseMIMETypes: ["application/json"],
                authentication: .anonymous,
                timeout: 10,
                responseBodyLimit: 1_024
            )
        }
        for invalidPath in ["/贴吧", "/safe/%2e%2e/private", "/safe/%5Cprivate"] {
            #expect(throws: EndpointDescriptorValidationError.invalidPath) {
                try EndpointDescriptor(
                    id: identifier,
                    method: .get,
                    host: "fixture.invalid",
                    path: invalidPath,
                    bodyCodec: .none,
                    responseFamily: .json,
                    allowedResponseMIMETypes: ["application/json"],
                    authentication: .anonymous,
                    timeout: 10,
                    responseBodyLimit: 1_024
                )
            }
        }
        #expect(throws: EndpointDescriptorValidationError.invalidMIMEType) {
            try EndpointDescriptor(
                id: identifier,
                method: .get,
                host: "fixture.invalid",
                path: "/items",
                bodyCodec: .none,
                responseFamily: .json,
                allowedResponseMIMETypes: ["application/json; charset=utf-8"],
                authentication: .anonymous,
                timeout: 10,
                responseBodyLimit: 1_024
            )
        }
    }

    @Test
    func anonymousFormRequestHasDeterministicBytesAndNoCredentialHeaders() async throws {
        let descriptor = try makeDescriptor(
            bodyCodec: .formURLEncoded,
            queryItems: [
                EndpointField(name: "z", value: "two words"),
                EndpointField(name: "a", value: "+")
            ]
        )
        let builder = EndpointRequestBuilder(
            authorizer: AnonymousRequestAuthorizer()
        )

        let request = try await builder.makeRequest(
            endpoint: descriptor,
            authentication: .anonymous,
            body: .formURLEncoded([
                EndpointField(name: "z", value: "last"),
                EndpointField(name: "a", value: "hello world")
            ])
        )

        #expect(
            request.url.absoluteString ==
                "https://fixture.invalid/v1/items?a=%2B&z=two%20words"
        )
        #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Authorization"] == nil)
        #expect(request.headers["Cookie"] == nil)
        #expect(request.body == Data("a=hello+world&z=last".utf8))
        #expect(request.timeout == 10)
        #expect(request.responseBodyLimit == 1_024)
        #expect(request.redirectPolicy == .reject)
    }

    @Test
    func multipartBinaryEncodingIsByteStable() async throws {
        let descriptor = try makeDescriptor(
            bodyCodec: .multipartBinary,
            responseFamily: .protobuf,
            allowedMIMETypes: ["application/x-protobuf"]
        )
        let builder = EndpointRequestBuilder(
            authorizer: AnonymousRequestAuthorizer()
        )
        let body = EndpointRequestBody.multipartBinary(
            boundary: "Phase07-Boundary",
            fields: [EndpointField(name: "mode", value: "fixture")],
            part: MultipartBinaryPart(
                name: "data",
                filename: "request.pb",
                mimeType: "application/octet-stream",
                data: Data([0x00, 0xFF])
            )
        )

        let request = try await builder.makeRequest(
            endpoint: descriptor,
            authentication: .anonymous,
            body: body
        )

        var expected = Data()
        expected.append(Data("--Phase07-Boundary\r\n".utf8))
        expected.append(
            Data(
                "Content-Disposition: form-data; name=\"mode\"\r\n\r\n".utf8
            )
        )
        expected.append(Data("fixture\r\n".utf8))
        expected.append(Data("--Phase07-Boundary\r\n".utf8))
        expected.append(
            Data(
                (
                    "Content-Disposition: form-data; name=\"data\"; " +
                        "filename=\"request.pb\"\r\n"
                ).utf8
            )
        )
        expected.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        expected.append(Data([0x00, 0xFF]))
        expected.append(Data("\r\n--Phase07-Boundary--\r\n".utf8))

        #expect(request.body == expected)
        #expect(
            request.headers["Content-Type"] ==
                "multipart/form-data; boundary=Phase07-Boundary"
        )

        await #expect(
            throws: EndpointRequestBuilderError.invalidBoundaryCollision
        ) {
            try await builder.makeRequest(
                endpoint: descriptor,
                authentication: .anonymous,
                body: .multipartBinary(
                    boundary: "Phase07-Boundary",
                    fields: [],
                    part: MultipartBinaryPart(
                        name: "data",
                        filename: "request.pb",
                        mimeType: "application/octet-stream",
                        data: Data("contains-Phase07-Boundary".utf8)
                    )
                )
            )
        }
    }

    @Test
    func protectedContextsNeverFallBackToAnonymousAuthorization() async throws {
        let activeDescriptor = try makeDescriptor(authentication: .active)
        let candidateDescriptor = try makeDescriptor(authentication: .candidate)
        let builder = EndpointRequestBuilder(
            authorizer: AnonymousRequestAuthorizer()
        )
        let active = AuthContext.active(
            ProtectedDataLease(
                sessionID: SessionID(rawValue: 7),
                generation: 3
            )
        )
        let candidate = AuthContext.candidate(OperationID(sequence: 11))

        await #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            try await builder.makeRequest(
                endpoint: activeDescriptor,
                authentication: active,
                body: .none
            )
        }
        await #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            try await builder.makeRequest(
                endpoint: candidateDescriptor,
                authentication: candidate,
                body: .none
            )
        }
        await #expect(throws: RequestAuthorizationError.contextMismatch) {
            try await builder.makeRequest(
                endpoint: activeDescriptor,
                authentication: .anonymous,
                body: .none
            )
        }
    }

    @Test
    func authorizerCanBindProtectedMaterialToEndpointIdentityAndOrigin() async throws {
        let descriptor = try makeDescriptor(authentication: .active)
        let otherOrigin = try makeDescriptor(
            host: "other.invalid",
            authentication: .active
        )
        let builder = EndpointRequestBuilder(
            authorizer: HarnessOriginBoundAuthorizer(
                endpointID: descriptor.id,
                host: descriptor.host
            )
        )
        let context = AuthContext.active(
            ProtectedDataLease(
                sessionID: SessionID(rawValue: 7),
                generation: 3
            )
        )

        let request = try await builder.makeRequest(
            endpoint: descriptor,
            authentication: context,
            body: .none
        )
        #expect(request.headers["Cookie"] == "fixture-only")
        await #expect(
            throws: RequestAuthorizationError.destinationNotAllowed
        ) {
            try await builder.makeRequest(
                endpoint: otherOrigin,
                authentication: context,
                body: .none
            )
        }
    }

    private func makeDescriptor(
        host: String = "fixture.invalid",
        bodyCodec: EndpointBodyCodec = .none,
        queryItems: [EndpointField] = [],
        responseFamily: EndpointResponseFamily = .json,
        allowedMIMETypes: [String] = ["application/json"],
        authentication: EndpointAuthenticationRequirement = .anonymous
    ) throws -> EndpointDescriptor {
        let identifier = try #require(EndpointID("fixture.items"))
        return try EndpointDescriptor(
            id: identifier,
            method: bodyCodec == .none ? .get : .post,
            host: host,
            path: "/v1/items",
            queryItems: queryItems,
            bodyCodec: bodyCodec,
            responseFamily: responseFamily,
            allowedResponseMIMETypes: allowedMIMETypes,
            authentication: authentication,
            timeout: 10,
            responseBodyLimit: 1_024
        )
    }
}

private struct HarnessOriginBoundAuthorizer: RequestAuthorizing {
    let endpointID: EndpointID
    let host: String

    func headers(
        for context: AuthContext,
        endpoint: EndpointDescriptor
    ) async throws -> [String: String] {
        guard case .active = context,
              endpoint.authentication == .active else {
            throw RequestAuthorizationError.contextMismatch
        }
        guard endpoint.id == endpointID, endpoint.host == host else {
            throw RequestAuthorizationError.destinationNotAllowed
        }
        return ["Cookie": "fixture-only"]
    }
}

struct EndpointPipelineTests {
    private struct WireValue: Equatable, Sendable {
        let count: Int
    }

    private struct DomainValue: Equatable, Sendable {
        let label: String
    }

    private struct SyntheticFailure: Error {
    }

    @Test
    func fixtureAdapterUsesTheSameDecodeAndDomainMappingSeam() throws {
        let descriptor = try makeDescriptor()
        let pipeline = EndpointPipeline<WireValue, DomainValue>(
            decode: { data in
                guard let text = String(data: data, encoding: .utf8),
                      let count = Int(text) else {
                    throw SyntheticFailure()
                }
                return WireValue(count: count)
            },
            map: { wire in
                DomainValue(label: "count-\(wire.count)")
            }
        )
        let adapter = FixtureEndpointAdapter(
            endpoint: descriptor,
            pipeline: pipeline
        )

        #expect(
            try adapter.map(
                Data("2".utf8),
                mimeType: "application/json; charset=utf-8"
            ) == DomainValue(label: "count-2")
        )
    }

    @Test
    func responseFailuresRemainSeparatedByLayer() throws {
        let descriptor = try makeDescriptor(responseBodyLimit: 2)
        let successPipeline = EndpointPipeline<Data, Int>(
            decode: { $0 },
            map: { $0.count }
        )

        #expect(throws: EndpointExecutionError.http(statusCode: 500)) {
            try successPipeline.map(
                HTTPResponse(statusCode: 500),
                for: descriptor
            )
        }
        #expect(
            throws: EndpointExecutionError.unsupportedContent(
                actualMIMEType: nil
            )
        ) {
            try successPipeline.map(
                HTTPResponse(statusCode: 200, body: Data([0x01])),
                for: descriptor
            )
        }
        #expect(
            throws: EndpointExecutionError.unsupportedContent(
                actualMIMEType: "text/plain"
            )
        ) {
            try successPipeline.map(
                HTTPResponse(
                    statusCode: 200,
                    headers: ["Content-Type": "text/plain"],
                    body: Data([0x01])
                ),
                for: descriptor
            )
        }
        #expect(
            throws: EndpointExecutionError.responseTooLarge(limit: 2)
        ) {
            try successPipeline.map(
                HTTPResponse(
                    statusCode: 200,
                    headers: ["content-type": "application/json"],
                    body: Data([0x01, 0x02, 0x03])
                ),
                for: descriptor
            )
        }

        let decodeFailure = EndpointPipeline<Data, Int>(
            decode: { _ in throw SyntheticFailure() },
            map: { $0.count }
        )
        #expect(throws: EndpointExecutionError.decode) {
            try decodeFailure.map(validResponse(), for: descriptor)
        }

        let serverFailure = EndpointPipeline<Data, Int>(
            decode: { _ in throw EndpointWireFailure.server(code: 17) },
            map: { $0.count }
        )
        #expect(throws: EndpointExecutionError.server(code: 17)) {
            try serverFailure.map(validResponse(), for: descriptor)
        }

        let mappingFailure = EndpointPipeline<Data, Int>(
            decode: { $0 },
            map: { _ in throw SyntheticFailure() }
        )
        #expect(throws: EndpointExecutionError.mapping) {
            try mappingFailure.map(validResponse(), for: descriptor)
        }
    }

    @Test
    func decodeAndMappingCancellationRemainCancellation() throws {
        let descriptor = try makeDescriptor()
        let cancelledDecode = EndpointPipeline<Data, Int>(
            decode: { _ in throw CancellationError() },
            map: { $0.count }
        )
        #expect(throws: CancellationError.self) {
            try cancelledDecode.map(validResponse(), for: descriptor)
        }

        let cancelledMapping = EndpointPipeline<Data, Int>(
            decode: { $0 },
            map: { _ in throw CancellationError() }
        )
        #expect(throws: CancellationError.self) {
            try cancelledMapping.map(validResponse(), for: descriptor)
        }
    }

    @Test
    func executorNeverRetriesAndKeepsCancellationObservable() async throws {
        let descriptor = try makeDescriptor()
        let client = HarnessMockHTTPClient()
        let executor = EndpointExecutor(
            client: client,
            requestBuilder: EndpointRequestBuilder(
                authorizer: AnonymousRequestAuthorizer()
            )
        )
        let pipeline = EndpointPipeline<Data, Int>(
            decode: { $0 },
            map: { $0.count }
        )
        let failureTask = Task {
            try await executor.execute(
                endpoint: descriptor,
                authentication: .anonymous,
                body: .none,
                pipeline: pipeline
            )
        }

        try await client.waitForPendingCallCount(1)
        let failureCall = try #require(await client.pendingCalls().first)
        try await client.succeed(
            failureCall.id,
            with: HTTPResponse(statusCode: 500)
        )
        do {
            _ = try await failureTask.value
            Issue.record("Expected one HTTP failure")
        } catch let error as EndpointExecutionError {
            #expect(error == .http(statusCode: 500))
            #expect(await client.events() == [
                .started(failureCall.id),
                .succeeded(failureCall.id)
            ])
        } catch {
            Issue.record("HTTP failure escaped the endpoint taxonomy")
        }

        let cancellationTask = Task {
            try await executor.execute(
                endpoint: descriptor,
                authentication: .anonymous,
                body: .none,
                pipeline: pipeline
            )
        }
        try await client.waitForPendingCallCount(1)
        cancellationTask.cancel()
        do {
            _ = try await cancellationTask.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(await client.pendingCalls().isEmpty)
        } catch {
            Issue.record("Endpoint executor converted cancellation")
        }

        let transportClient = HarnessMockHTTPClient(
            defaultBehavior: .failure(.responseTooLarge(limit: 1_024))
        )
        let transportExecutor = EndpointExecutor(
            client: transportClient,
            requestBuilder: EndpointRequestBuilder(
                authorizer: AnonymousRequestAuthorizer()
            )
        )
        await #expect(
            throws: EndpointExecutionError.responseTooLarge(limit: 1_024)
        ) {
            try await transportExecutor.execute(
                endpoint: descriptor,
                authentication: .anonymous,
                body: .none,
                pipeline: pipeline
            )
        }
    }

    private func makeDescriptor(
        responseBodyLimit: Int = 1_024
    ) throws -> EndpointDescriptor {
        let identifier = try #require(EndpointID("fixture.pipeline"))
        return try EndpointDescriptor(
            id: identifier,
            method: .get,
            host: "fixture.invalid",
            path: "/pipeline",
            bodyCodec: .none,
            responseFamily: .json,
            allowedResponseMIMETypes: ["application/json"],
            authentication: .anonymous,
            timeout: 10,
            responseBodyLimit: responseBodyLimit
        )
    }

    private func validResponse() -> HTTPResponse {
        HTTPResponse(
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: Data([0x01])
        )
    }
}
