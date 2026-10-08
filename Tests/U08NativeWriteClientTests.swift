import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeWriteClientTests {
    @Test
    func cachedAccountSendsEachTargetOnceWithIndependentNativeRequestBytes() async throws {
        let fixture = try NativeClientFixture.load()
        for sample in fixture.cases {
            let setup = try setup(fixture: fixture, sample: sample)
            let task = Task { try await setup.send() }
            let call = try await next(setup.http)
            let endpoint = sample.kind == "thread" ? "/c/c/thread/add" : "/c/c/post/add"
            let command = sample.kind == "thread" ? 309730 : 309731
            #expect(call.request.url.path == endpoint, "\(sample.name)")
            #expect(call.request.url.query == "cmd=\(command)&format=protobuf", "\(sample.name)")
            #expect(call.request.method == .post)
            #expect(call.request.headers["x_bd_data_type"] == "protobuf")
            #expect(call.request.headers["svcp_stk"] == nil)
            #expect(call.request.body == expectedMultipart(try #require(Data(base64Encoded: sample.wireBase64))), "\(sample.name)")
            try await setup.http.succeed(call.id, with: response(sample.kind == "thread" ? "thread-success" : "post-metadata-success"))
            #expect(try await !task.value.serverRejected)
            #expect(setup.runtime.requestedAPIs == [sample.kind == "thread" ? .thread : .reply])
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test
    func missingTBSCompletesBeforeExactlyOneNativeWriteWithoutLegacyPreparation() async throws {
        let setup = try setup(tbs: "")
        let task = Task { try await setup.send() }
        let read = try await next(setup.http)
        #expect(read.request.url.path == "/c/s/tbs")
        #expect(read.request.headers["x_bd_data_type"] == nil)
        #expect(String(data: read.request.body ?? Data(), encoding: .utf8)?.contains("BDUSS=fx") == true)
        try await setup.http.succeed(read.id, with: .init(statusCode: 200, body: Data(#"{"error_code":0,"tbs":"fixture-tbs"}"#.utf8)))
        let write = try await next(setup.http)
        #expect(write.request.url.path == "/c/c/post/add")
        #expect(write.request.body == expectedMultipart(try #require(Data(base64Encoded: setup.sample.wireBase64))))
        try await setup.http.succeed(write.id, with: response())
        #expect(try await !task.value.serverRejected)
        #expect(try setup.session.cachedAccount()?.tbs == "fixture-tbs")
        #expect(setup.runtime.requestedAPIs == [.tbs, .reply])
        #expect(await setup.http.events().count == 4)
    }

    @Test
    func failedTBSNeverReachesAWriteOrAutomaticRetry() async throws {
        let setup = try setup(tbs: "")
        let task = Task { try await setup.send() }
        let read = try await next(setup.http)
        try await setup.http.succeed(read.id, with: .init(statusCode: 503))
        await #expect(throws: HTTPClientError.server(statusCode: 503)) { try await task.value }
        #expect(setup.runtime.requestedAPIs == [.tbs])
        #expect(try setup.session.cachedAccount() == nil)
        #expect(await setup.http.pendingCalls().isEmpty)
        #expect(await setup.http.events().count == 2)
    }

    @Test
    func parsedResponseStateFeedsNextAttemptButMalformedDataCannotReplaceIt() async throws {
        let setup = try setup()
        let first = Task { try await setup.send() }
        let firstCall = try await next(setup.http)
        try await setup.http.succeed(firstCall.id, with: response(state: "fixture-first"))
        _ = try await first.value
        #expect(try setup.session.customHeaders() == ["svcp_stk": "fixture-first"])
        let second = Task { try await setup.send() }
        let secondCall = try await next(setup.http)
        #expect(secondCall.request.headers["svcp_stk"] == "fixture-first")
        try await setup.http.succeed(secondCall.id, with: .init(
            statusCode: 200, headers: ["Set-Cookie": "__ymg_scsc=fixture-unparsed;"], body: Data([255])))
        await #expect(throws: (any Error).self) { try await second.value }
        #expect(try setup.session.customHeaders() == ["svcp_stk": "fixture-first"])
        let third = Task { try await setup.send() }
        let thirdCall = try await next(setup.http)
        #expect(thirdCall.request.headers["svcp_stk"] == "fixture-first")
        try await setup.http.succeed(thirdCall.id, with: response("post-error-with-ids", state: "fixture-rejected"))
        #expect(try await third.value.serverRejected)
        #expect(try setup.session.customHeaders() == ["svcp_stk": "fixture-rejected"])
        #expect(await setup.http.events().count == 6)
    }

    @Test
    func switchedAccountCannotAcceptLateReceiptOrCapturedState() async throws {
        let setup = try setup()
        let task = Task { try await setup.send() }
        let call = try await next(setup.http)
        setup.auth.install(try #require(SessionCredential(bduss: "fixture-other", stoken: "fixture-other-token")))
        try await setup.http.succeed(call.id, with: response(state: "fixture-old-account"))
        await #expect(throws: RequestAuthorizationError.contextMismatch) { try await task.value }
        #expect(throws: RequestAuthorizationError.credentialUnavailable) { try setup.session.customHeaders() }
        #expect(await setup.http.events().count == 2)
    }

    @Test
    func duplicateAndCancelledSendDoNotStartAnotherRequest() async throws {
        let setup = try setup()
        let task = Task { try await setup.send() }
        _ = try await next(setup.http)
        await #expect(throws: NativeTextWriteClientError.alreadySending) { try await setup.send() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await setup.http.pendingCalls().isEmpty)
        #expect(await setup.http.events().count == 2)
        #expect(setup.runtime.requestedAPIs == [.reply])
        #expect(try setup.session.customHeaders().isEmpty)
    }

    @Test
    func runtimeForAnotherAccountIsRejectedBeforeNetwork() async throws {
        let setup = try setup()
        setup.runtime.mismatchedAccount = true
        await #expect(throws: NativeTextWriteClientError.invalidRuntimeContext) { try await setup.send() }
        #expect(await setup.http.events().isEmpty)
        #expect(try setup.session.cachedAccount()?.tbs == "fixture-tbs")
    }

    @Test
    func emptyWriteResponseCannotBecomeSuccessOrReplaceParsedSessionState() async throws {
        let native = try NativeClientFixture.load().emptyResponse
        #expect(native.state == 4 && native.decodeCount == 0 && native.hasError)
        let setup = try setup()
        let task = Task { try await setup.send() }
        let call = try await next(setup.http)
        try await setup.http.succeed(call.id, with: .init(
            statusCode: 200, headers: ["Set-Cookie": "__ymg_scsc=fixture-empty;"]))
        await #expect(throws: HTTPClientError.malformedResponse) { try await task.value }
        #expect(try setup.session.customHeaders().isEmpty)
        #expect(await setup.http.events().count == 2)
    }

    @Test
    func invalidOriginAndDraftDoNotFetchTBSOrCreateRuntimeValues() async throws {
        let setup = try setup(tbs: "")
        await #expect(throws: TextWriteFailure.invalidTarget) {
            try await setup.client.send(setup.sample.request(), content: .prepared(setup.sample.content), origin: .thread(entranceType: 1))
        }
        let request = try setup.sample.request()
        await #expect(throws: TextWriteFailure.invalidDraft) {
            try await setup.client.send(.init(target: request.target, draft: .init()),
                                        content: .prepared(""), origin: setup.sample.origin())
        }
        #expect(setup.runtime.requestedAPIs.isEmpty)
        #expect(await setup.http.events().isEmpty)
    }

    @Test
    func replyComposePreparesCapturedBodyBeforeOneNativeWrite() async throws {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "floorReply" })
        let setup = try setup(fixture: fixture, sample: sample)
        let content = try #require(NativeClientFixture.replyContent().first { $0.name == "recipient-prefix" })
        let request = try sample.request()
        let task = Task {
            try await setup.client.send(request, content: .replyCompose(content.input), origin: sample.origin())
        }
        let call = try await next(setup.http)
        let multipart = try #require(call.request.body)
        let start = try #require(multipart.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(multipart.range(of: Data("\r\n--Boundary+0123456789ABCDEF--\r\n".utf8))).lowerBound
        let fields = try TiebaNativeWrite_PostRequest(serializedBytes: multipart[start..<end]).data
        #expect(Array(fields.content.utf16) == Array(content.expected.utf16))
        #expect(fields.quoteID == "301" && fields.repostid == "301")
        #expect(request.draft.content == sample.content)
        try await setup.http.succeed(call.id, with: response())
        #expect(try await !task.value.serverRejected)
        #expect(setup.runtime.requestedAPIs == [.reply])
        #expect(await setup.http.events().count == 2)
    }

    @Test
    func replyComposeCannotBeUsedForNewThreadBeforePreparation() async throws {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "thread" })
        let setup = try setup(fixture: fixture, sample: sample, tbs: "")
        let input = try #require(NativeClientFixture.replyContent().first).input
        await #expect(throws: TextWriteFailure.invalidTarget) {
            try await setup.client.send(sample.request(), content: .replyCompose(input), origin: sample.origin())
        }
        #expect(await setup.http.events().isEmpty)
        #expect(setup.runtime.requestedAPIs.isEmpty)
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }

    private func response(_ name: String = "post-success", state: String? = nil) throws -> HTTPResponse {
        var headers = ["Content-Type": "application/protobuf"]
        headers["Set-Cookie"] = state.map { "__ymg_scsc=\($0);" }
        return try HTTPResponse(statusCode: 200, headers: headers, body: NativeClientFixture.response(name))
    }

    private func expectedMultipart(_ data: Data) -> Data {
        var body = Data(("--Boundary+0123456789ABCDEF\r\n" +
            "Content-Disposition: form-data; name=\"data\"; filename=\"data\"\r\n" +
            "Content-Type: image/jpeg\r\n\r\n").utf8)
        body.append(data)
        body.append(Data("\r\n--Boundary+0123456789ABCDEF--\r\n".utf8))
        return body
    }

    private func setup(fixture: NativeClientFixture? = nil, sample: NativeClientSample? = nil,
                       tbs: String = "fixture-tbs") throws -> Setup {
        let fixture = try fixture ?? NativeClientFixture.load()
        let sample = try sample ?? #require(fixture.cases.first)
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fx")))
        let session = try NativeWriteSession(auth: auth, context: auth.context(),
                                             account: .init(userID: "42", tbs: tbs, nameShow: "FixtureName"))
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: sample)
        let http = HarnessMockHTTPClient()
        let client = NativeTextWriteClient(session: session, context: auth.context(), runtime: runtime,
                                           loader: NativeClientHarnessBridge(client: http))
        return Setup(auth: auth, session: session, runtime: runtime, sample: sample, http: http, client: client)
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let session: NativeWriteSession
        let runtime: NativeClientFixtureRuntime
        let sample: NativeClientSample
        let http: HarnessMockHTTPClient
        let client: NativeTextWriteClient

        func send() async throws -> NativeWriteDecodedResponse {
            try await client.send(sample.request(), content: .prepared(sample.content), origin: sample.origin())
        }
    }
}
