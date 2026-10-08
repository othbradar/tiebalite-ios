import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeWriteSessionTests {
    @Test
    func storedAccountIsReusedWithoutPerSendPreparation() throws {
        let auth = try provider()
        let session = try makeSession(auth, tbs: "fixture-existing")
        for _ in 0..<3 {
            #expect(try session.cachedAccount()?.tbs == "fixture-existing")
            #expect(try session.beginTBSRequest() == nil)
        }
    }

    @Test
    func missingTBSHasOneOperationAndOnlyNonemptyCompletionBecomesReady() throws {
        let auth = try provider()
        let session = try makeSession(auth)
        #expect(try session.cachedAccount() == nil)
        let first = try #require(try session.beginTBSRequest())
        #expect(first.userID == "42")
        #expect(first.authorization.bduss == "fixture-session")
        #expect(try session.beginTBSRequest() == nil)
        #expect(try !session.finishTBSRequest(first, value: ""))
        #expect(try session.cachedAccount() == nil)
        let second = try #require(try session.beginTBSRequest())
        #expect(second != first)
        #expect(try !session.finishTBSRequest(first, value: "fixture-late"))
        #expect(try session.beginTBSRequest() == nil)
        #expect(try session.finishTBSRequest(second, value: "fixture-ready"))
        #expect(try session.cachedAccount()?.tbs == "fixture-ready")
        #expect(try session.cachedAccount()?.nameShow == "FixtureName")
        #expect(try session.beginTBSRequest() == nil)
    }

    @Test
    func requestBelongsToItsAccountOwnerEvenWithTheSameLease() throws {
        let auth = try provider()
        let first = try makeSession(auth)
        let second = try makeSession(auth)
        let firstRequest = try #require(try first.beginTBSRequest())
        let secondRequest = try #require(try second.beginTBSRequest())
        #expect(firstRequest != secondRequest)
        #expect(try !second.finishTBSRequest(firstRequest, value: "fixture-wrong-owner"))
        #expect(try second.finishTBSRequest(secondRequest, value: "fixture-correct-owner"))
    }

    @Test
    func oldAccountCompletionAndResponseCannotPolluteReplacementSession() throws {
        let auth = try provider()
        let old = try makeSession(auth)
        let oldContext = auth.context()
        let pending = try #require(try old.beginTBSRequest())
        try old.acceptParsedResponseState(.init(headerValue: "__ymg_scsc=fixture-old; Path=/"), for: oldContext)
        auth.install(try #require(SessionCredential(bduss: "fixture-other", stoken: "fixture-other-token")))
        let replacement = try makeSession(auth)
        #expect(throws: RequestAuthorizationError.contextMismatch) {
            try old.finishTBSRequest(pending, value: "fixture-stale")
        }
        #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            try old.acceptParsedResponseState(.init(headerValue: "__ymg_scsc=fixture-stale; Path=/"), for: oldContext)
        }
        #expect(throws: RequestAuthorizationError.contextMismatch) {
            try replacement.acceptParsedResponseState(.init(headerValue: "__ymg_scsc=fixture-stale; Path=/"), for: oldContext)
        }
        #expect(try replacement.cachedAccount() == nil)
        #expect(try replacement.customHeaders().isEmpty)
    }

    @Test
    func absentResponseStateKeepsLastValueUntilSessionEnds() throws {
        let auth = try provider()
        let session = try makeSession(auth, tbs: "fixture-existing")
        #expect(try session.customHeaders().isEmpty)
        try session.acceptParsedResponseState(.init(headerValue: "__ymg_scsc=fixture-first; Path=/"), for: auth.context())
        try session.acceptParsedResponseState(nil, for: auth.context())
        #expect(try session.customHeaders() == ["svcp_stk": "fixture-first"])
        try session.acceptParsedResponseState(.init(headerValue: "__ymg_scsc=fixture-next; Path=/"), for: auth.context())
        #expect(try session.customHeaders() == ["svcp_stk": "fixture-next"])
        auth.revoke()
        #expect(throws: RequestAuthorizationError.credentialUnavailable) { try session.customHeaders() }
        #expect(throws: RequestAuthorizationError.credentialUnavailable) { try session.cachedAccount() }
    }

    @Test
    func explicitInvalidationRejectsOutstandingOperations() throws {
        let auth = try provider()
        let session = try makeSession(auth)
        let pending = try #require(try session.beginTBSRequest())
        session.invalidate()
        #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            try session.finishTBSRequest(pending, value: "fixture-late")
        }
        #expect(throws: RequestAuthorizationError.credentialUnavailable) { try session.beginTBSRequest() }
    }

    @Test
    func headerExtractionMatchesTheReferenceMethodIncludingEmptyFirstMatch() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-account-state.json"))
        for sample in try JSONDecoder().decode(StateFixtures.self, from: data).headerCases {
            let state = NativeWriteResponseState(headerValue: sample.headerValue)
            #expect(state?.requestHeaders["svcp_stk"] == sample.expected)
        }
    }

    @Test
    func accountOperationAndResponseStateDescriptionsDoNotExposeValues() throws {
        let auth = try provider()
        let session = try makeSession(auth)
        let operation = try #require(try session.beginTBSRequest())
        let state = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-private; Path=/"))
        #expect(String(describing: operation) == "NativeWriteTBSRequest(redacted)")
        #expect(String(reflecting: operation) == "NativeWriteTBSRequest(redacted)")
        #expect(String(describing: state) == "NativeWriteResponseState(redacted)")
        #expect(String(reflecting: state) == "NativeWriteResponseState(redacted)")
    }

    private func provider() throws -> SessionAuthContextProvider {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        return auth
    }

    private func makeSession(_ auth: SessionAuthContextProvider, tbs: String = "") throws -> NativeWriteSession {
        try NativeWriteSession(auth: auth, context: auth.context(),
                               account: .init(userID: "42", tbs: tbs, nameShow: "FixtureName"))
    }

    private struct StateFixtures: Decodable { let headerCases: [NativeWriteHeaderCase] }
}

private struct NativeWriteHeaderCase: Decodable {
    let headerValue: String?
    let expected: String?
    enum CodingKeys: String, CodingKey { case headerValue = "setCookie", expected }
}
