import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct R09WriteProtocolTests {
    private let authorization = SessionAuthorization(bduss: "fixture-session", stoken: "fixture-token")
    private let account = TextWriteAccount(userID: "42", tbs: "fixture-tbs")

    @Test func replyMultipartIncludesAndroidInterceptorFieldsAndSignature() throws {
        let request = TextWriteRequest(target: R09WriteFixture.target(.threadReply), draft: .init(content: "固定文字"))
        guard case let .multipartBinary(_, fields, part) = try TextWriteProtocol.body(
            request, authorization: authorization, account: account) else {
            Issue.record("Expected AddPost multipart")
            return
        }
        let values = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.value) })
        #expect(values["_client_version"] == "12.35.1.0")
        #expect(values["_client_type"] == "2")
        #expect(values["BDUSS"] == "fixture-session")
        #expect(values["from"] == "tieba")
        #expect(values["stoken"] == "fixture-token")
        let expected = TextWriteProtocol.signedFields(values.filter { $0.key != "sign" })
        #expect(values["sign"] == expected.first { $0.name == "sign" }?.value)
        #expect(!fields.contains { $0.name == "data" })
        #expect(part.name == "data" && part.filename == "file")
        let headers = try TextWriteProtocol.descriptor(for: .threadReply, userID: "42").fixedHeaders
        #expect(headers["x_bd_data_type"] == "protobuf")
        #expect(headers["Charset"] == "UTF-8")
    }

    @Test func allReplyTargetsRetainExactIdentifiersAndInlineRecipient() throws {
        for kind in [TextComposeTarget.Kind.threadReply, .floorReply, .subpostReply] {
            let target = R09WriteFixture.target(kind)
            let request = TextWriteRequest(target: target, draft: .init(content: "正文 #滑稽"))
            let data = TextWriteProtocol.postRequest(request, authorization: authorization, account: account).data
            #expect(data.tid == "101")
            #expect(data.fid == "90")
            #expect(data.common.tbs == "fixture-tbs")
            #expect(data.common.clientVersion == "12.35.1.0")
            #expect(data.hasQuoteID == (kind != .threadReply))
            #expect(data.hasSubPostID == (kind == .subpostReply))
            if kind == .threadReply { #expect(data.postFrom == "13") }
            if kind == .floorReply { #expect(data.postFrom == "0") }
            if kind == .subpostReply {
                #expect(data.quoteID == "202" && data.repostid == "202" && data.subPostID == "303")
                #expect(data.replyUid == "44")
                #expect(data.content == "回复 #(reply, fixture-portrait, 样本作者) :正文 #滑稽")
                #expect(!data.hasPostFrom)
            }
            let endpoint = try TextWriteProtocol.descriptor(for: kind, userID: "42")
            #expect(endpoint.authentication == .active && endpoint.retryPolicy == .never)
            #expect(endpoint.path == "/c/c/post/add")
        }
    }

    @Test func threadFormSigningUsesDecodedSortedValuesAndOptionalTitle() throws {
        let target = R09WriteFixture.target(.thread)
        let request = TextWriteRequest(target: target, draft: .init(title: "标题", content: "正文 + & ="))
        let fields = TextWriteProtocol.threadFields(request, authorization: authorization, account: account)
        let values = Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.value) })
        #expect(values["is_ntitle"] == "0" && values["is_hide"] == "1")
        #expect(values["content"] == "正文 + & =")
        let signed = TextWriteProtocol.signedFields(["b": "two", "a": "one"])
        #expect(signed.first { $0.name == "sign" }?.value == "5b486b68f22cf877a0075c72f956338e")
        let noTitle = TextWriteProtocol.threadFields(
            .init(target: target, draft: .init(content: "文字")), authorization: authorization, account: account)
        #expect(noTitle.first { $0.name == "is_ntitle" }?.value == "1")
    }

    @Test func serverReceiptsRejectMissingIDsAndRecognizeVerification() throws {
        let endpoint = try TextWriteProtocol.descriptor(for: .thread, userID: "42")
        let pipeline = EndpointPipeline(decode: TextWriteProtocol.decodeThread, map: { $0 })
        let threadResponse = HTTPResponse(statusCode: 200,
                                          headers: ["content-type": "application/x-javascript; charset=utf-8"],
                                          body: Data(#"{"error_code":"0","tid":"501","pid":"502"}"#.utf8))
        if case .success(let receipt) = try pipeline.map(threadResponse, for: endpoint) {
            #expect(receipt == .init(threadID: 501, postID: 502))
        } else { Issue.record("Expected server receipt") }
        let missing = try TextWriteProtocol.decodeThread(Data(#"{"error_code":0}"#.utf8))
        if case .failure(.resultUnknown) = missing {} else { Issue.record("Missing IDs must not succeed") }
        let captcha = try TextWriteProtocol.decodeThread(Data(#"{"error_code":40,"info":{"need_vcode":"1"}}"#.utf8))
        if case .failure(.verificationRequired) = captcha {} else { Issue.record("Expected verification status") }
        var response = Tieba_AddPost_AddPostResponse()
        response.data.pid = "999"
        response.data.tid = "101"
        response.data.anti = Tieba_VcodeInfo()
        let target = R09WriteFixture.target(.floorReply)
        if case .success(let receipt) = try TextWriteProtocol.decodePost(response.serializedData(), target: target) {
            #expect(receipt.postID == 999)
        } else { Issue.record("Expected post receipt") }
        response.data.info.needVcode = "1"
        if case .failure(.verificationRequired) = try TextWriteProtocol.decodePost(response.serializedData(), target: target) {
        } else { Issue.record("Expected verification status") }
    }
}

@MainActor
struct R09WriteRepositoryTests {
    @Test func accountMetadataJavaScriptMIMEReportsServerFailureWithoutPublishing() async throws {
        let client = HarnessMockHTTPClient()
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let repository = LiveTextWriteRepository(client: client, authContextProvider: auth)
        let request = TextWriteRequest(target: R09WriteFixture.target(.threadReply), draft: .init(content: "固定文字"))
        let task = Task { try await repository.send(request, context: auth.context()) }
        try await client.waitForPendingCallCount(1)
        let metadata = try #require(await client.pendingCalls().first)
        #expect(metadata.request.url.path == "/c/s/login")
        try await client.succeed(metadata.id, with: .init(
            statusCode: 200, headers: ["content-type": "application/x-javascript; charset=utf-8"],
            body: Data(#"{"error_code":"1"}"#.utf8)))
        await #expect(throws: TextWriteFailure.server(1)) { try await task.value }
        #expect(await client.pendingCalls().isEmpty)
    }

    @Test func pipelineGetsMetadataThenMakesOneWriteWithoutCookiesOrRetries() async throws {
        let client = HarnessMockHTTPClient()
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let repository = LiveTextWriteRepository(client: client, authContextProvider: auth)
        let context = auth.context()
        let request = TextWriteRequest(target: R09WriteFixture.target(.threadReply), draft: .init(content: "固定文字"))
        let task = Task { try await repository.send(request, context: context) }
        try await client.waitForPendingCallCount(1)
        let metadata = try #require(await client.pendingCalls().first)
        #expect(metadata.request.url.absoluteString == "https://c.tieba.baidu.com/c/s/login")
        let metadataResponse = HTTPResponse(statusCode: 200,
                                            headers: ["content-type": "application/x-javascript; charset=UTF-8"],
                                            body: R09WriteFixture.accountResponse.body)
        try await client.succeed(metadata.id, with: metadataResponse)
        try await client.waitForPendingCallCount(1)
        let write = try #require(await client.pendingCalls().first)
        #expect(write.request.url.path == "/c/c/post/add")
        #expect(write.request.url.scheme == "https")
        #expect(write.request.headers["Cookie"] == nil)
        #expect(write.request.headers["client_user_token"] == "42")
        var result = Tieba_AddPost_AddPostResponse()
        result.data.pid = "401"
        result.data.tid = "101"
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/octet-stream"],
                                    body: try result.serializedData())
        try await client.succeed(write.id, with: response)
        #expect(try await task.value == .init(threadID: 101, postID: 401))
        #expect(await client.pendingCalls().isEmpty)
    }

    @Test func changedLeaseAfterMetadataStopsBeforeWrite() async throws {
        let client = HarnessMockHTTPClient()
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let repository = LiveTextWriteRepository(client: client, authContextProvider: auth)
        let context = auth.context()
        let request = TextWriteRequest(target: R09WriteFixture.target(.thread), draft: .init(content: "固定文字"))
        let task = Task { try await repository.send(request, context: context) }
        try await client.waitForPendingCallCount(1)
        let metadata = try #require(await client.pendingCalls().first)
        auth.revoke()
        try await client.succeed(metadata.id, with: R09WriteFixture.accountResponse)
        await #expect(throws: TextWriteFailure.authentication) { try await task.value }
        #expect(await client.pendingCalls().isEmpty)
    }
}

enum R09WriteFixture {
    static func target(_ kind: TextComposeTarget.Kind) -> TextComposeTarget {
        .init(kind: kind, forumID: 90, forumName: "样本", threadID: kind == .thread ? 0 : 101,
              postID: [.floorReply, .subpostReply].contains(kind) ? 202 : 0,
              subpostID: kind == .subpostReply ? 303 : 0,
              recipient: kind == .floorReply || kind == .subpostReply
                ? .init(rawUserID: 44, displayName: "样本作者", portrait: "fixture-portrait") : nil)
    }
    static var accountResponse: HTTPResponse {
        .init(statusCode: 200, headers: ["content-type": "application/json"],
              body: Data(#"{"error_code":"0","anti":{"tbs":"fixture-tbs"},"user":{"id":"42"}}"#.utf8))
    }
}
