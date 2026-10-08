import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct U08WriteReceiptTests {
    @MainActor
    @Test(arguments: [TextComposeTarget.Kind.threadReply, .floorReply, .subpostReply])
    func beta3SupportedMIMEReachesComposerAsOneSuccessfulReceipt(_ kind: TextComposeTarget.Kind) async throws {
        let client = HarnessMockHTTPClient()
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let context = auth.context()
        let store = TextComposerStore(target: R09WriteFixture.target(kind),
                                      repository: LiveTextWriteRepository(client: client, authContextProvider: auth),
                                      context: context, currentContext: { auth.context() })
        store.draft.content = "U08 synthetic reply"
        let task = Task { await store.send() }
        defer { task.cancel() }
        try await client.waitForPendingCallCount(1)
        let metadata = try #require(await client.pendingCalls().first)
        try #require(metadata.request.url.path == "/c/s/login")
        try await client.succeed(metadata.id, with: R09WriteFixture.accountResponse)
        try await client.waitForPendingCallCount(1)
        let profile = try #require(await client.pendingCalls().first)
        try #require(profile.request.url.path == "/c/u/user/profile")
        try await client.succeed(profile.id, with: R09WriteFixture.profileResponse())
        try await client.waitForPendingCallCount(1)
        let write = try #require(await client.pendingCalls().first)
        try #require(write.request.url.path == "/c/c/post/add")
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/octet-stream"],
                                    body: try Self.receiptData())
        try await client.succeed(write.id, with: response)
        await task.value
        #expect(store.failure == nil)
        try #require(store.receipt == .init(threadID: 101, postID: 401))
        await store.send()
        #expect(await client.pendingCalls().isEmpty)
        #expect(await client.events().filter { if case .started = $0 { return true }; return false }.count == 3)
    }

    @Test(arguments: ["application/octet-stream", "application/x-protobuf", "application/x-protobuf; charset=UTF-8"])
    func replyMIMETypesStillRequireDecodableServerReceipt(_ mime: String) throws {
        let response = HTTPResponse(statusCode: 200, headers: ["Content-Type": mime], body: try Self.receiptData())
        guard case .success(let receipt) = try Self.map(response) else {
            Issue.record("Valid reply receipt must succeed")
            return
        }
        #expect(receipt == .init(threadID: 101, postID: 401))
    }

    @Test(arguments: ["missing-id", "wrong-thread", "invalid", "verification", "server-error", "html"])
    func MIMECompatibilityDoesNotAcceptUnconfirmedReplies(_ scenario: String) throws {
        var wire = Tieba_AddPost_AddPostResponse()
        wire.data.pid = scenario == "missing-id" ? "" : "401"
        wire.data.tid = scenario == "wrong-thread" ? "102" : "101"
        if scenario == "verification" {
            wire.error.errorCode = 1
            wire.data.info.needVcode = "1"
        }
        if scenario == "server-error" { wire.error.errorCode = 1 }
        let response = HTTPResponse(statusCode: 200,
                                    headers: ["content-type": scenario == "html" ? "text/html" : "application/octet-stream"],
                                    body: scenario == "invalid" ? Data([0xFF]) : try wire.serializedData())
        if scenario == "invalid" {
            #expect(throws: EndpointExecutionError.decode) { try Self.map(response) }
        } else if scenario == "html" {
            #expect(throws: EndpointExecutionError.unsupportedContent(actualMIMEType: "text/html")) { try Self.map(response) }
        } else {
            guard case .failure(let failure) = try Self.map(response) else {
                Issue.record("Unconfirmed response must not succeed")
                return
            }
            let expected: TextWriteFailure = scenario == "verification" ? .verificationRequired
                : scenario == "server-error" ? .server(1) : .resultUnknown
            #expect(failure == expected)
        }
    }

    @Test(arguments: ["zero-type", "type-only", "anti-payload", "info-payload", "need-flag", "access-state"])
    func beta3AntiFieldsKeepOriginalVerificationPrecedence(_ field: String) throws {
        var wire = try Tieba_AddPost_AddPostResponse(serializedBytes: Self.receiptData())
        Self.addAntiMetadata(field, to: &wire)
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/octet-stream"],
                                    body: try wire.serializedData())
        guard case .failure(let failure) = try Self.map(response) else {
            Issue.record("Beta3 checks verification fields before the reply receipt")
            return
        }
        #expect(failure == .verificationRequired)
    }

    @Test(arguments: ["zero-type", "type-only", "anti-payload", "info-payload", "need-flag", "access-state"])
    func antiMetadataCannotCreateSuccessWithoutAReceipt(_ field: String) throws {
        var wire = Tieba_AddPost_AddPostResponse()
        Self.addAntiMetadata(field, to: &wire)
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/octet-stream"],
                                    body: try wire.serializedData())
        guard case .failure(let failure) = try Self.map(response) else {
            Issue.record("No reply ID means no confirmed success")
            return
        }
        #expect(failure == .verificationRequired)
    }

    @Test func beta3RejectsAdditionalMIMEWithoutChangingTheContract() throws {
        let response = HTTPResponse(statusCode: 200, headers: ["content-type": "application/protobuf"],
                                    body: try Self.receiptData())
        #expect(throws: EndpointExecutionError.unsupportedContent(actualMIMEType: "application/protobuf")) {
            try Self.map(response)
        }
    }

    private static func addAntiMetadata(_ field: String, to wire: inout Tieba_AddPost_AddPostResponse) {
        switch field {
        case "zero-type":
            wire.data.anti.vcodeType = "0"
            wire.data.info.needVcode = "0"
            wire.data.info.accessState.type = "0"
        case "type-only": wire.data.anti.vcodeType = "1"
        case "anti-payload":
            wire.data.anti.vcodeMd5 = "fixture-challenge"
            wire.data.anti.vcodePicURL = "https://fixture.test/challenge"
        case "info-payload":
            wire.data.info.vcodeMd5 = "fixture-challenge"
            wire.data.info.vcodePicURL = "https://fixture.test/challenge"
        case "need-flag": wire.data.info.needVcode = "1"
        default: wire.data.info.accessState.type = "1"
        }
    }

    private static func receiptData() throws -> Data {
        var wire = Tieba_AddPost_AddPostResponse()
        wire.data.pid = "401"
        wire.data.tid = "101"
        return try wire.serializedData()
    }

    private static func map(_ response: HTTPResponse) throws -> TextWriteOutcome {
        let target = R09WriteFixture.target(.threadReply)
        let pipeline = EndpointPipeline(decode: { try TextWriteProtocol.decodePost($0, target: target) }, map: { $0 })
        return try pipeline.map(response, for: TextWriteProtocol.descriptor(for: target.kind, userID: "42"))
    }
}
