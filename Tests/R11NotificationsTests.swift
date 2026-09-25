import Foundation
import Testing
@testable import TiebaLite

struct R11NotificationsProtocolTests {
    @Test func messageIdentityEmoticonsAndReplyDestinationFollowAndroid() throws {
        let page = try NotificationsProtocol.decodePage(R11NotificationFixture.bytes(kind: .replies, page: 0), kind: .replies, page: 0)
        #expect(page.items.count == 15 && page.nextPage == 2)
        #expect(page.items[0].author.levelID == nil)
        #expect(page.items[0].author.avatarResource != nil)
        #expect(TiebaRichText.parse(page.items[0].content).compactMap(\.emoticonID).count == 2)
        #expect(page.items[1].target == .init(threadID: 8_001, postID: 10_001, isSubpost: true))
        #expect(page.items[1].quote == "被引用的原文 #(微微一笑)")
        let again = try NotificationsProtocol.decodePage(R11NotificationFixture.bytes(kind: .replies, page: 0), kind: .replies, page: 0)
        #expect(page.items.map(\.id) == again.items.map(\.id))
        let mentions = try NotificationsProtocol.decodePage(
            R11NotificationFixture.bytes(kind: .mentions, page: 0), kind: .mentions, page: 0)
        #expect(mentions.items[0].quote == "一段可以返回的主题")
        #expect(mentions.items[0].id != page.items[0].id)
    }

    @Test func emptyPrimitiveCountsAndMalformedResponses() throws {
        for value in ["null", "\"\"", "[]", "0"] {
            let data = Data("{\"error_code\":0,\"reply_list\":\(value)}".utf8)
            let page = try NotificationsProtocol.decodePage(data, kind: .replies, page: 0)
            #expect(page.items.isEmpty && page.nextPage == nil)
        }
        #expect(try NotificationsProtocol.decodeCounts(Data(#"{"error_code":0,"message":{"replyme":"2","atme":3}}"#.utf8)).total == 5)
        #expect(throws: (any Error).self) { try NotificationsProtocol.decodeCounts(Data("{}".utf8)) }
        #expect(throws: (any Error).self) {
            try NotificationsProtocol.decodePage(Data(#"{"error_code":"4"}"#.utf8), kind: .replies, page: 0)
        }
        #expect(throws: (any Error).self) {
            try NotificationsProtocol.decodePage(Data(#"{"error_code":0,"reply_list":{}}"#.utf8), kind: .replies, page: 0)
        }
    }
}

@MainActor
struct R11NotificationsRepositoryTests {
    @Test func protectedRequestUsesHTTPSAndExpiredLeaseCannotReturnMessages() async throws {
        let client = HarnessMockHTTPClient()
        let provider = SessionAuthContextProvider()
        provider.install(try #require(SessionCredential(bduss: "fx-msg-b", stoken: "fx-msg-s")))
        let context = provider.context()
        let repository = LiveNotificationsRepository(client: client, authContextProvider: provider)
        let task = Task { try await repository.load(kind: .replies, page: 0, context: context) }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(call.request.url.absoluteString == "https://c.tieba.baidu.com/c/u/feed/replyme")
        #expect(call.request.headers["Cookie"] == "ka=open")
        provider.revoke()
        try await client.succeed(call.id, with: .init(
            statusCode: 200, headers: ["Content-Type": "application/json"],
            body: R11NotificationFixture.bytes(kind: .replies, page: 0)))
        await #expect(throws: RequestAuthorizationError.self) { try await task.value }
        #expect(await client.pendingCalls().isEmpty)
    }

    @Test func liveLegacyJSONMIMEIsDecodedAsJSONWithoutExecutingScript() throws {
        let descriptor = try NotificationsProtocol.descriptor(kind: .replies)
        let pipeline = EndpointPipeline<NotificationPage, NotificationPage>(
            decode: { try NotificationsProtocol.decodePage($0, kind: .replies, page: 0) }, map: { $0 })
        let response = HTTPResponse(statusCode: 200, headers: ["Content-Type": "application/x-javascript; charset=utf-8"],
                                    body: R11NotificationFixture.bytes(kind: .replies, page: 0))
        #expect(try pipeline.map(response, for: descriptor).items.count == 15)
        #expect(throws: (any Error).self) {
            try pipeline.map(.init(statusCode: 200, headers: response.headers, body: Data("callback({});".utf8)), for: descriptor)
        }
    }

    @Test func wireFailuresRemainTypedAndNeverLookLikeEmptySuccess() async throws {
        let responses: [(HTTPResponse, EndpointExecutionError)] = [
            (.init(statusCode: 503, body: Data()), .http(statusCode: 503)),
            (.init(statusCode: 200, headers: ["Content-Type": "application/json"], body: Data("bad".utf8)), .decode),
            (.init(statusCode: 200, headers: ["Content-Type": "application/json"],
                   body: Data(#"{"error_code":"4"}"#.utf8)), .server(code: 4)),
            (.init(statusCode: 200, headers: ["Content-Type": "image/png"], body: Data()),
             .unsupportedContent(actualMIMEType: "image/png"))
        ]
        for (response, expected) in responses {
            let client = HarnessMockHTTPClient()
            let provider = SessionAuthContextProvider()
            provider.install(try #require(SessionCredential(bduss: "fx-msg-b", stoken: "fx-msg-s")))
            let repository = LiveNotificationsRepository(client: client, authContextProvider: provider)
            let context = provider.context()
            let task = Task { try await repository.load(kind: .mentions, page: 0, context: context) }
            try await client.waitForPendingCallCount(1)
            let call = try #require(await client.pendingCalls().first)
            try await client.succeed(call.id, with: response)
            do {
                _ = try await task.value
                Issue.record("Expected typed failure")
            } catch { #expect(error as? EndpointExecutionError == expected) }
        }
    }
}
