import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeTBSPreparationTests {
    @Test
    func existingTBSDoesNotCreateARequest() async throws {
        let auth = try provider()
        let session = try makeSession(auth, tbs: "fixture-cached")
        let client = NativeTBSGateClient()
        let account = try await session.prepareTBS(using: client) { _ in
            Issue.record("Cached TBS unexpectedly built a request")
            throw NativeTBSError.invalidRequestContext
        }
        #expect(account.tbs == "fixture-cached" && account.nameShow == "FixtureName")
        #expect(await client.requestCount == 0)
    }

    @Test
    func oneRequestCompletesWithoutOverwritingANewerProfileName() async throws {
        let auth = try provider()
        let session = try makeSession(auth)
        let client = NativeTBSGateClient()
        let task = Task { try await session.prepareTBS(using: client, makeRequest: request) }
        await client.waitForRequest()
        await #expect(throws: NativeTBSError.alreadyPreparing) {
            try await session.prepareTBS(using: client, makeRequest: request)
        }
        try session.acceptProfileName(profileUserID: "42", displayName: "New fixture", loginName: nil, for: auth.context())
        await client.complete(.success(successResponse))
        let account = try await task.value
        #expect(account.tbs == "fixture-ready" && account.nameShow == "New fixture")
        #expect(try session.beginTBSRequest() == nil)
        #expect(await client.requestCount == 1)
    }

    @Test
    func failedRequestReleasesPreparationWithoutAutomaticRetry() async throws {
        let auth = try provider()
        let session = try makeSession(auth)
        let client = NativeTBSGateClient()
        let first = Task { try await session.prepareTBS(using: client, makeRequest: request) }
        await client.waitForRequest()
        await client.complete(.failure(HTTPClientError.offline))
        await #expect(throws: HTTPClientError.offline) { try await first.value }
        #expect(try session.cachedAccount() == nil)
        #expect(await client.requestCount == 1)
        let second = Task { try await session.prepareTBS(using: client, makeRequest: request) }
        await client.waitForRequest(number: 2)
        await client.complete(.success(successResponse))
        #expect(try await second.value.tbs == "fixture-ready")
        #expect(await client.requestCount == 2)
    }

    @Test
    func cancellationRejectsAnUncooperativeTransportLateSuccess() async throws {
        let auth = try provider()
        let session = try makeSession(auth)
        let client = NativeTBSGateClient()
        let task = Task { try await session.prepareTBS(using: client, makeRequest: request) }
        await client.waitForRequest()
        task.cancel()
        await client.complete(.success(successResponse))
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try session.cachedAccount() == nil)
        #expect(try session.beginTBSRequest() != nil)
        #expect(await client.requestCount == 1)
    }

    @Test
    func replacedAccountDoesNotAcceptAnOldPreparation() async throws {
        let auth = try provider()
        let oldSession = try makeSession(auth)
        let client = NativeTBSGateClient()
        let task = Task { try await oldSession.prepareTBS(using: client, makeRequest: request) }
        await client.waitForRequest()
        auth.install(try #require(SessionCredential(bduss: "fixture-other", stoken: "fixture-other-token")))
        let replacement = try makeSession(auth)
        await client.complete(.success(successResponse))
        await #expect(throws: RequestAuthorizationError.contextMismatch) { try await task.value }
        #expect(try replacement.cachedAccount() == nil)
        #expect(try replacement.beginTBSRequest() != nil)
        #expect(await client.requestCount == 1)
    }

    @Test
    func invalidRequestAndInvalidReceiptCannotBecomeReady() async throws {
        let auth = try provider()
        let session = try makeSession(auth)
        let client = NativeTBSGateClient()
        await #expect(throws: NativeTBSError.invalidRequestContext) {
            try await session.prepareTBS(using: client) { _ in
                try HTTPRequest(method: .post, url: #require(URL(string: "https://tiebac.baidu.com/c/c/post/add")))
            }
        }
        #expect(await client.requestCount == 0)
        let task = Task { try await session.prepareTBS(using: client, makeRequest: request) }
        await client.waitForRequest()
        await client.complete(.success(.init(statusCode: 200, body: Data(#"{"error_code":6,"tbs":"fixture-rejected"}"#.utf8))))
        await #expect(throws: NativeTBSError.serverRejected(6)) { try await task.value }
        #expect(try session.cachedAccount() == nil)
        #expect(try session.beginTBSRequest() != nil)
    }

    private var successResponse: HTTPResponse {
        HTTPResponse(statusCode: 200, body: Data(#"{"error_code":0,"tbs":"fixture-ready"}"#.utf8))
    }

    private func request(_ operation: NativeWriteSession.TBSRequest) throws -> HTTPRequest {
        #expect(operation.userID == "42")
        return try NativeTBSRequest.make(
            parameters: ["BDUSS": operation.authorization.bduss, "sign": "fixture-sign"],
            context: .init(userAgent: "FixtureIOSAgent", acceptLanguage: nil, clientLogID: 0,
                           cookies: .init(networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                          smallFlow: false, smallFlowValue: nil)))
    }

    private func provider() throws -> SessionAuthContextProvider {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        return auth
    }

    private func makeSession(_ auth: SessionAuthContextProvider, tbs: String = "") throws -> NativeWriteSession {
        try NativeWriteSession(auth: auth, context: auth.context(), account: .init(userID: "42", tbs: tbs, nameShow: "FixtureName"))
    }
}
