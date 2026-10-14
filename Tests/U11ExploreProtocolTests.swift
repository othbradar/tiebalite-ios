import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct U11ExploreProtocolTests {
    @Test func requestsAndResponseTypesMatchNativeIOSDescriptors() throws {
        let fixture = try fixture()
        for sample in fixture.requests {
            let bytes = try ExploreFeedProtocol.encode(sample.feed, business: sample.business, common: sample.common)
            #expect(bytes == Data(base64Encoded: sample.wireBase64))
            let cursor: ExploreCursor? = sample.business["load_type"] == "2" ? .init(pageTag: "page-two", requestUnix: 1234) : nil
            #expect(try ExploreFeedProtocol.business(sample.feed, cursor: cursor) == sample.business)
            let context = NativeWriteHTTPContext(
                userAgent: "FixtureIOSAgent", acceptLanguage: "zh-Hans", clientLogID: 42, timeout: 10,
                responseState: nil, cookies: .init(
                    networkStatus: 1, wifiKeepAlive: false, cellularKeepAlive: false, smallFlow: false, smallFlowValue: nil))
            let request = try ExploreFeedProtocol.request(sample.feed, business: sample.business, common: sample.common,
                                                          context: context, boundary: "FixtureBoundary")
            #expect(request.url.query == "cmd=\(sample.feed == .following ? 309474 : 309661)&format=protobuf")
            #expect(request.headers["User-Agent"] == "FixtureIOSAgent" && request.headers["Retry-Count"] == "0")
            #expect(request.headers["client_type"] == nil && request.headers["Accept"] == nil)
            let body = try #require(request.body)
            #expect(body.range(of: Data("name=\"data\"; filename=\"data\"".utf8)) != nil)
            #expect(body.range(of: Data("Content-Type: image/jpeg".utf8)) != nil)
            #expect(body.range(of: Data("name=\"sign\"".utf8)) == nil)
        }
        let following = try ExploreFeedProtocol.decode(fixture.responses[0].bytes, feed: .following)
        let hot = try ExploreFeedProtocol.decode(fixture.responses[1].bytes, feed: .hot)
        #expect(following.items.map(\.threadID) == [110])
        #expect(following.next == .init(pageTag: "page-two", requestUnix: 1234))
        #expect(following.items[0].authorName == "Author" && following.items[0].replyCount == 5)
        #expect(hot.items.map(\.threadID) == [210, 211] && hot.next == nil)
        #expect(hot.items[1].feed.agreeCount == nil)
    }

    @Test func emptyMalformedAndServerFailureAreNotMixedUp() throws {
        let samples = try fixture().responses
        #expect(try ExploreFeedProtocol.decode(samples[2].bytes, feed: .following).items.isEmpty)
        var layoutOnly = TiebaNativeExplore_FollowingResponse()
        layoutOnly.data.pageData.feedList = [Data()]
        #expect(throws: ExploreFailure.invalidData) {
            try ExploreFeedProtocol.decode(layoutOnly.serializedData(), feed: .following)
        }
        #expect(throws: EndpointWireFailure.server(code: 4)) {
            try ExploreFeedProtocol.decode(samples[3].bytes, feed: .hot)
        }
        for feed in ExploreFeed.allCases {
            for bytes in [Data(), Data([0xff]), Data([0x0a, 0x00]), Data("{\"error_code\":0}".utf8)] {
                #expect(throws: (any Error).self) { try ExploreFeedProtocol.decode(bytes, feed: feed) }
            }
        }
    }

    @MainActor @Test(arguments: [false, true])
    func nativeReadRejectsCancelledOrOldAccountResponse(changesAccount: Bool) async throws {
        let auth = SessionAuthContextProvider(), client = NativeTBSGateClient()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        let source = LiveExploreFeedSource(client: client, auth: auth, prepare: { _, _, _ in
            try HTTPRequest(method: .post, url: #require(URL(string: "https://fixture.invalid/read")))
        })
        let bytes = try fixture().responses[0].bytes
        let operation = Task { try await source.load(.following, cursor: nil) }
        await client.waitForRequest()
        if changesAccount { auth.revoke() } else { operation.cancel() }
        await client.complete(.success(.init(statusCode: 200, headers: ["Content-Type": "application/protobuf"], body: bytes)))
        await #expect(throws: CancellationError.self) { try await operation.value }
        #expect(await client.requestCount == 1)
    }

    @MainActor @Test func nativeReadIsSingleRequestAndAnonymousFollowingDoesNotStart() async throws {
        let auth = SessionAuthContextProvider(), client = NativeTBSGateClient()
        let source = LiveExploreFeedSource(client: client, auth: auth, prepare: { _, _, _ in
            try HTTPRequest(method: .post, url: #require(URL(string: "https://fixture.invalid/read")))
        })
        await #expect(throws: ExploreFailure.loginRequired) { try await source.load(.following, cursor: nil) }
        #expect(await client.requestCount == 0)
        let operation = Task { try await source.load(.hot, cursor: nil) }
        await client.waitForRequest()
        await client.complete(.success(.init(statusCode: 200, headers: ["Content-Type": "application/protobuf"],
                                             body: try fixture().responses[1].bytes)))
        #expect(try await operation.value.items.map(\.threadID) == [210, 211])
        #expect(await client.requestCount == 1)
    }

    private func fixture() throws -> Fixture {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: root.appendingPathComponent("API/Explore/native-ios.json")))
    }
    private struct Fixture: Decodable {
        let requests: [Request]
        let responses: [Response]
    }
    private struct Request: Decodable {
        let feed: ExploreFeed
        let business: [String: String]
        let common: [String: String]
        let wireBase64: String
    }
    private struct Response: Decodable {
        let wireBase64: String
        var bytes: Data { get throws { try #require(Data(base64Encoded: wireBase64)) } }
    }
}
