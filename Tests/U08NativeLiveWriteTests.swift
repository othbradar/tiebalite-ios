import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeLiveWriteTests {
    @Test func composerUsesIOSAccountPreparationAndOneNativeWriteThenReusesSession() async throws {
        let setup = try makeSetup()
        let store = composer(setup)
        let task = Task { await store.send() }
        let account = try await next(setup.http)
        #expect(account.request.url.absoluteString == "https://tiebac.baidu.com/c/s/login")
        let form = try #require(String(data: account.request.body ?? Data(), encoding: .utf8))
        #expect(form.contains("bdusstoken=fx") && !form.contains("%7Cnull") && !form.contains("Android"))
        #expect(form.contains("first_login=1"))
        try await setup.http.succeed(account.id, with: accountResponse)
        let write = try await next(setup.http)
        let fields = try post(write.request)
        #expect(fields.common.clientType == 1)
        #expect(fields.anonymous == "0" && fields.tbs == "fixture-tbs")
        #expect(fields.content == "Native reply" && fields.tid == "101")
        #expect(write.request.headers["x_bd_data_type"] == "protobuf")
        #expect(write.request.url.query == "cmd=309731&format=protobuf")
        try await setup.http.succeed(write.id, with: .init(
            statusCode: 200, headers: ["content-type": "application/protobuf"],
            body: NativeClientFixture.response("post-metadata-success")))
        await task.value
        #expect(store.receipt == .init(threadID: 101, postID: 401) && store.failure == nil)
        let second = composer(setup)
        let repeatTask = Task { await second.send() }
        let repeatWrite = try await next(setup.http)
        #expect(repeatWrite.request.url.path == "/c/c/post/add")
        #expect(repeatWrite.request.url.query == "cmd=309731&format=protobuf")
        try await setup.http.succeed(repeatWrite.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await repeatTask.value
        #expect(second.receipt != nil)
        #expect(await setup.http.events().filter { if case .started = $0 { return true }; return false }.count == 3)
    }

    @Test func failedPreparationNeverWritesAndStaleAccountNeverPublishes() async throws {
        let setup = try makeSetup()
        let store = composer(setup)
        let task = Task { await store.send() }
        let account = try await next(setup.http)
        setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
        try await setup.http.succeed(account.id, with: accountResponse)
        await task.value
        #expect(store.receipt == nil)
        #expect(store.draft.content == "Native reply")
        #expect(await setup.http.pendingCalls().isEmpty)
    }

    @Test func cachedPhotoCannotSlipThroughTheTextOnlyPreflight() async throws {
        let setup = try makeSetup()
        let store = composer(setup)
        store.draft.photos = [.init(
            id: "fixture", file: .init(url: URL(fileURLWithPath: "/fixture-unused"), removesOnRelease: false),
            width: 1, height: 1, byteCount: 1, uploaded: .init(picID: "old-upload", width: 1, height: 1))]
        await store.send()
        #expect(store.failure == .nativeImagesUnavailable)
        #expect(store.draft.photos.count == 1 && store.receipt == nil)
        #expect(await setup.http.events().isEmpty)
    }

    @Test func actualVerificationAndAmbiguousReplyPreserveDraftWithoutRetry() async throws {
        for sample in ["verification", "empty-payload"] {
            let setup = try makeSetup()
            let store = composer(setup)
            let task = Task { await store.send() }
            let account = try await next(setup.http)
            try await setup.http.succeed(account.id, with: accountResponse)
            let write = try await next(setup.http)
            var rejected = TiebaNativeWrite_Response()
            rejected.error.errorno = 5
            rejected.data.tid = "101"
            rejected.data.pid = "401"
            let bytes = sample == "empty-payload" ? Data() : try rejected.serializedData()
            try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: bytes))
            await task.value
            #expect(store.receipt == nil)
            #expect(store.failure == (sample == "verification" ? .verificationRequired : .resultUnknown))
            #expect(store.draft.content == "Native reply")
            #expect(await setup.http.pendingCalls().isEmpty)
        }
    }

    @Test func localRuntimeUsesSystemUAAndNeverFabricatesMissingSDKIdentity() async throws {
        let runtime = NativeWriteAppRuntime()
        try await runtime.prepare()
        let result = try runtime.context(for: .reply, authorization: .init(bduss: "fx", stoken: "fy"),
                                         account: .init(userID: "42", tbs: "fixture-tbs"))
        #expect(result.http.userAgent.contains("AppleWebKit"))
        #expect(result.http.userAgent.contains("tieba/22.11.1"))
        #expect(!result.http.userAgent.contains("Android"))
        #expect(result.common.staticValues.cuid == nil && result.common.dynamicValues.opaqueSDKValue == nil)
        #expect(result.common.staticValues.clientVersion == "22.11.1")
    }

    @Test func productionRuntimeCanEncodeReplyBeforeAnyWrite() async throws {
        let runtime = NativeWriteAppRuntime()
        try await runtime.prepare()
        let account = TextWriteAccount(userID: "42", tbs: "fixture-tbs")
        let values = try runtime.context(for: .reply, authorization: .init(bduss: "fx", stoken: "fy"), account: account)
        let request = TextWriteRequest(target: R09WriteFixture.target(.threadReply), draft: .init(content: "Fixture"))
        let business = try NativeTextWriteParameters.reply(
            request, preparedContent: "Fixture", account: account,
            context: .init(container: .threadPage, pageEntryType: 0, floorNumber: "0", replyCount: nil))
        var common = NativeWriteCommonParameters()
        var metrics = runtime.requestMetrics
        let fields = common.prepare(values.common, business: business, metrics: &metrics)
        #expect(fields["personalized_rec_switch"]?.isEmpty == true)
        let bytes = try NativeWriteRequestEncoder.encode(kind: .threadReply, business: business, common: fields)
        let encoded = try TiebaNativeWrite_PostRequest(serializedBytes: bytes)
        #expect(encoded.data.content == "Fixture")
        #expect(encoded.data.common.clientType == 1)
        #expect(encoded.data.common.hasPersonalizedRecSwitch && encoded.data.common.personalizedRecSwitch == 0)
        #expect(fields["personalized_rec_switch"]?.isEmpty == true)
        #expect(encoded.data.common.sign == fields["sign"])
    }

    @Test func productionRuntimeReachesOneMockWriteAndComposerSuccess() async throws {
        let setup = try makeSetup(runtime: NativeWriteAppRuntime())
        let store = composer(setup)
        let task = Task { await store.send() }
        let account = try await next(setup.http)
        try await setup.http.succeed(account.id, with: accountResponse)
        let write = try await next(setup.http)
        #expect(write.request.url.path == "/c/c/post/add")
        #expect(write.request.url.query == "cmd=309731&format=protobuf")
        let encoded = try post(write.request)
        #expect(encoded.content == "Native reply" && encoded.tbs == "fixture-tbs")
        #expect(encoded.common.personalizedRecSwitch == 0 && encoded.common.hasPersonalizedRecSwitch)
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await task.value
        #expect(store.receipt != nil && store.failure == nil)
        #expect(await setup.http.events().filter { if case .started = $0 { return true }; return false }.count == 2)
    }

    @Test func preWriteRuntimeFailureIsNotReportedAsAccountResponseFailure() async throws {
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        runtime.mismatchedAccount = true
        let setup = try makeSetup(runtime: runtime)
        let store = composer(setup)
        let task = Task { await store.send() }
        let account = try await next(setup.http)
        try await setup.http.succeed(account.id, with: accountResponse)
        await task.value
        #expect(store.failure == .requestPreparation && store.receipt == nil)
        #expect(store.draft.content == "Native reply")
        #expect(await setup.http.pendingCalls().isEmpty)
    }

    @Test func liveAdapterKeepsNewThreadFloorAndSubpostTargetsDistinct() async throws {
        for kind in [TextComposeTarget.Kind.thread, .floorReply, .subpostReply] {
            let setup = try makeSetup()
            let target = R09WriteFixture.target(kind)
            let operation = Task {
                try await setup.repository.send(.init(target: target, draft: .init(content: "Native target")),
                                                context: setup.auth.context())
            }
            let account = try await next(setup.http)
            try await setup.http.succeed(account.id, with: accountResponse)
            let write = try await next(setup.http)
            #expect(write.request.url.path == (kind == .thread ? "/c/c/thread/add" : "/c/c/post/add"))
            if kind != .thread {
                let fields = try post(write.request)
                #expect(fields.quoteID == String(target.postID) && fields.repostid == String(target.postID))
                #expect(fields.replyUid == String(target.recipient?.rawUserID ?? 0))
                if kind == .subpostReply {
                    #expect(fields.subPostID == String(target.subpostID))
                    #expect(fields.content.hasPrefix("回复 #(reply, "))
                }
            }
            try await setup.http.succeed(write.id, with: .init(
                statusCode: 200, body: NativeClientFixture.response(kind == .thread ? "thread-success" : "post-success")))
            let receipt = try await operation.value
            #expect(receipt.postID > 0 && receipt.threadID > 0)
            #expect(await setup.http.pendingCalls().isEmpty)
        }
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let http: HarnessMockHTTPClient
        let repository: NativeLiveTextWriteRepository
    }

    private func makeSetup(runtime: (any NativeWriteRuntimeProviding)? = nil) throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let http = HarnessMockHTTPClient()
        return Setup(auth: auth, http: http, repository: NativeLiveTextWriteRepository(
            auth: auth, loader: NativeClientHarnessBridge(client: http),
            runtime: runtime ?? NativeClientFixtureRuntime(fixture: fixture, sample: sample),
            firstLogin: { true }, didPrepareAccount: {}))
    }

    private func composer(_ setup: Setup) -> TextComposerStore {
        let store = TextComposerStore(target: .init(kind: .threadReply, forumID: 9, forumName: "FixtureForum", threadID: 101),
                                      repository: setup.repository, context: setup.auth.context(), currentContext: { setup.auth.context() })
        store.draft.content = "Native reply"
        return store
    }

    private var accountResponse: HTTPResponse {
        .init(statusCode: 200, body: Data(#"{"error_code":0,"user":{"id":"42","name":"Fixture"},"anti":{"tbs":"fixture-tbs"}}"#.utf8))
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }

    private func post(_ request: HTTPRequest) throws -> TiebaNativeWrite_PostData {
        let body = try #require(request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let contentType = try #require(request.headers.first { $0.key.lowercased() == "content-type" }?.value)
        let boundary = try #require(contentType.components(separatedBy: "boundary=").last)
        let end = try #require(body.range(of: Data("\r\n--\(boundary)--\r\n".utf8))).lowerBound
        return try TiebaNativeWrite_PostRequest(serializedBytes: body[start..<end]).data
    }
}
