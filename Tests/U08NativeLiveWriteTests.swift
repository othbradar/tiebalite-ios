import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeLiveWriteTests {
    @Test func nativeImagePreflightAcceptsUnuploadedPhotoWithoutStartingRequests() throws {
        let setup = try makeSetup()
        let photo = ComposerPhoto(id: "fixture", file: .init(url: URL(fileURLWithPath: "/fixture-unused"), removesOnRelease: false),
                                  width: 640, height: 480, byteCount: 100)
        let request = TextWriteRequest(target: R09WriteFixture.target(.threadReply), draft: .init(content: "Image", photos: [photo]))
        #expect(throws: Never.self) { try setup.repository.validateForSending(request) }
    }
    @Test func pageOriginReachesNativeReplyWithoutChangingTargetOrRequestCount() async throws {
        let origins: [(ThreadReadingEntry, String)] = [
            (.recommendations, "2"), (.forum, "3"), (.history, "11"), (.universalLink, "5"),
            (.search, "8"), (.contentLink, "7"), (.unspecified, "0"),
            (.notification(.replies, opensQuotedThread: false), "12"),
            (.notification(.replies, opensQuotedThread: true), "4"),
            (.notification(.mentions, opensQuotedThread: false), "13"),
            (.notification(.mentions, opensQuotedThread: true), "13")
        ]
        for (entry, expected) in origins {
            let setup = try makeSetup()
            var target = R09WriteFixture.target(.threadReply)
            let identity = target.id
            target.readingEntry = entry
            #expect(target.id == identity)
            let frozenTarget = target
            let task = Task { try await setup.repository.send(.init(target: frozenTarget, draft: .init(content: "Fixture")),
                                                              context: setup.auth.context()) }
            let account = try await next(setup.http)
            try await setup.http.succeed(account.id, with: accountResponse)
            let write = try await next(setup.http)
            let fields = try post(write.request)
            #expect(fields.postFrom == expected)
            #expect(fields.tid == String(target.threadID) && fields.content == "Fixture")
            try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
            #expect(try await task.value.postID == 401)
            #expect(await setup.http.events().count == 4)
        }
    }

    @Test func newAccountCannotSendPreviousAccountsTransferStatistics() async throws {
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first { $0.kind == "threadReply" }))
        let setup = try makeSetup(runtime: runtime)
        for changingAccount in [false, true] {
            if changingAccount {
                runtime.requestMetrics = .init(api: "c/c/post/add", logID: 42, cost: 100, result: 0, uploadBytes: 123, downloadBytes: 456)
                setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
            }
            let store = composer(setup)
            let task = Task { await store.send() }
            let account = try await next(setup.http)
            if changingAccount {
                let form = try #require(String(data: account.request.body ?? Data(), encoding: .utf8))
                #expect(!form.contains("m_api=") && !form.contains("m_logid="))
            }
            try await setup.http.succeed(account.id, with: accountResponse)
            let write = try await next(setup.http)
            #expect(try !post(write.request).common.hasMApi)
            try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
            await task.value
            #expect(store.receipt != nil)
        }
        #expect(await setup.http.events().count == 8)
    }

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

    @Test func legacyImageReceiptCannotSlipThroughNativePreflight() async throws {
        let setup = try makeSetup()
        let store = composer(setup)
        store.draft.photos = [.init(
            id: "fixture", file: .init(url: URL(fileURLWithPath: "/fixture-unused"), removesOnRelease: false),
            width: 1, height: 1, byteCount: 1, uploaded: .init(picID: "old-upload", width: 1, height: 1))]
        await store.send()
        #expect(store.mediaFailure == ImageUploadFailure.invalidImage.message)
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
        let runtime = NativeWriteAppRuntime(readNetworkType: { "1" })
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
        let runtime = NativeWriteAppRuntime(readNetworkType: { "1" })
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
        let setup = try makeSetup(runtime: NativeWriteAppRuntime(readNetworkType: { "1" }))
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

    @Test func acceptedReplyReadsOnceWithNativeParametersAndDoesNotPrepareOrWriteAgain() async throws {
        let setup = try makeSetup()
        let store = composer(setup, entry: .search)
        let send = Task { await store.send() }
        try await setup.http.succeed(try await next(setup.http).id, with: accountResponse)
        try await setup.http.succeed(try await next(setup.http).id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await send.value
        let receipt = try #require(store.receipt)
        let request = ReplyFollowupRequest(receipt: receipt, entry: .search, page: 2)
        let read = Task { try await setup.repository.loadReply(request) }
        let call = try await next(setup.http)
        #expect(call.request.url.path == "/c/f/pb/getmypost" && call.request.url.query == "cmd=309751&format=protobuf")
        let body = try #require(call.request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(body.range(of: Data("\r\n--Boundary+0123456789ABCDEF--\r\n".utf8))).lowerBound
        let fields = try TiebaNativeWrite_ReplyReadRequest(serializedBytes: body[start..<end]).data
        #expect(fields.kz == 101 && fields.lastPid == 401 && fields.markType == 2 && !fields.hasPn)
        #expect(fields.fr == "search_page" && fields.common.clientType == 1 && !fields.common.sign.isEmpty)
        #expect(fields.requestTimes == 2 && fields.sessionRequestTimes == 0)
        #expect(fields.adParam.loadCount == 1 && fields.adParam.refreshCount == 0 && fields.adParam.isReqAd == 0)
        #expect(try await setup.repository.loadReply(request) == nil)
        var response = try TiebaNativeWrite_ReplyReadResponse(serializedBytes: U08ReplyReadFixture.bytes())
        var post = try Tieba_Post(serializedBytes: try #require(response.data.postList.first))
        post.id = UInt64(receipt.postID)
        response.data.postList = [try post.serializedData()]
        try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: try response.serializedData()))
        #expect(try await read.value?.posts.map(\.id.postID) == [401])
        #expect(store.receipt == receipt && store.failure == nil)
        #expect(await setup.http.events().count == 6) // account + write + one read, each start/finish
    }

    @Test func disabledReplySwitchDoesNotDispatchAReadOrChangeSuccessfulReceipt() async throws {
        let setup = try makeSetup(replyReadSwitch: { 0 })
        let store = composer(setup, entry: .search)
        let send = Task { await store.send() }
        try await setup.http.succeed(try await next(setup.http).id, with: accountResponse)
        try await setup.http.succeed(try await next(setup.http).id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await send.value
        let receipt = try #require(store.receipt)
        #expect(try await setup.repository.loadReply(.init(receipt: receipt, entry: .forum, page: 1)) == nil)
        #expect(await setup.http.events().count == 4)
        #expect(store.receipt == receipt && store.failure == nil)
    }

    @Test func nativeFollowupRejectsAccountChangedWhileReadIsInFlight() async throws {
        let setup = try makeSetup()
        let store = composer(setup)
        let send = Task { await store.send() }
        try await setup.http.succeed(try await next(setup.http).id, with: accountResponse)
        try await setup.http.succeed(try await next(setup.http).id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await send.value
        let receipt = try #require(store.receipt)
        let request = ReplyFollowupRequest(receipt: receipt, entry: .forum, page: 1)
        let read = Task { try await setup.repository.loadReply(request) }
        let call = try await next(setup.http)
        setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
        try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: U08ReplyReadFixture.bytes()))
        await #expect(throws: RequestAuthorizationError.contextMismatch) { try await read.value }
        #expect(store.receipt == receipt)
        #expect(await setup.http.events().count == 6)
        #expect(try await setup.repository.loadReply(request) == nil)
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let http: HarnessMockHTTPClient
        let repository: NativeLiveTextWriteRepository
    }

    private func makeSetup(runtime: (any NativeWriteRuntimeProviding)? = nil,
                           replyReadSwitch: @escaping () -> Int? = { nil }) throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let http = HarnessMockHTTPClient()
        return Setup(auth: auth, http: http, repository: NativeLiveTextWriteRepository(
            auth: auth, loader: NativeClientHarnessBridge(client: http),
            runtime: runtime ?? NativeClientFixtureRuntime(fixture: fixture, sample: sample),
            firstLogin: { true }, didPrepareAccount: {}, replyReadSwitch: replyReadSwitch))
    }

    private func composer(_ setup: Setup, entry: ThreadReadingEntry = .unspecified) -> TextComposerStore {
        let target = TextComposeTarget(kind: .threadReply, forumID: 9, forumName: "FixtureForum",
                                       threadID: 101, readingEntry: entry)
        let store = TextComposerStore(target: target, repository: setup.repository, context: setup.auth.context(),
                                      currentContext: { setup.auth.context() })
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
