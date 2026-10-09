import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeReplyReadTests {
    @Test func singleReadRejectsConcurrentAndLateAccountResultsWithoutAnyWrite() async throws {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let http = HarnessMockHTTPClient()
        let client = NativeReplyReadClient(
            auth: auth, context: auth.context(), http: URLSessionHTTPClient(loader: NativeClientHarnessBridge(client: http)))
        let business = ["kz": "101", "last_pid": "430001", "mark_type": "2"]
        let common = ["_client_type": "1", "BDUSS": "fx", "stoken": "fy"]
        let task = Task {
            try await client.load(business: business, common: common, httpContext: httpContext, boundary: "FixtureBoundary")
        }
        try await http.waitForPendingCallCount(1)
        let call = try #require(await http.pendingCalls().first)
        #expect(call.request.url.path == "/c/f/pb/getmypost")
        await #expect(throws: NativeReplyReadError.alreadyLoading) {
            try await client.load(business: business, common: common, httpContext: httpContext, boundary: "FixtureBoundary")
        }
        auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
        let sample = try #require(fixtures().responses.first { $0.name == "success" })
        try await http.succeed(call.id, with: .init(statusCode: 200, body: try #require(Data(base64Encoded: sample.wireBase64))))
        await #expect(throws: RequestAuthorizationError.contextMismatch) { try await task.value }
        #expect(await http.pendingCalls().isEmpty)
        #expect(await http.events().count == 2)
    }

    @Test func failedOrCancelledReadNeverResendsReplyAndNextExplicitReadCanSucceed() async throws {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let http = HarnessMockHTTPClient()
        let client = NativeReplyReadClient(
            auth: auth, context: auth.context(), http: URLSessionHTTPClient(loader: NativeClientHarnessBridge(client: http)))
        let business = ["kz": "101", "last_pid": "430001", "mark_type": "2"]
        let common = ["_client_type": "1", "BDUSS": "fx", "stoken": "fy"]
        let cancelled = Task {
            try await client.load(business: business, common: common, httpContext: httpContext, boundary: "FixtureBoundary")
        }
        try await http.waitForPendingCallCount(1)
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(await http.pendingCalls().isEmpty)
        let failed = Task {
            try await client.load(business: business, common: common, httpContext: httpContext, boundary: "FixtureBoundary")
        }
        try await http.waitForPendingCallCount(1)
        let failureCall = try #require(await http.pendingCalls().first)
        try await http.succeed(failureCall.id, with: .init(statusCode: 503))
        await #expect(throws: HTTPClientError.server(statusCode: 503)) { try await failed.value }
        #expect(await http.pendingCalls().isEmpty)
        let success = Task {
            try await client.load(business: business, common: common, httpContext: httpContext, boundary: "FixtureBoundary")
        }
        try await http.waitForPendingCallCount(1)
        let successCall = try #require(await http.pendingCalls().first)
        #expect(successCall.request.url.path == "/c/f/pb/getmypost")
        let sample = try #require(fixtures().responses.first { $0.name == "success" })
        try await http.succeed(successCall.id, with: .init(
            statusCode: 200, body: try #require(Data(base64Encoded: sample.wireBase64))))
        #expect(try await success.value.posts.map(\.id.postID) == [430001])
        #expect(await http.events().count == 6)
    }

    @Test func wrongAccountOrAndroidCommonNeverStartsRead() async throws {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let http = HarnessMockHTTPClient()
        let client = NativeReplyReadClient(
            auth: auth, context: auth.context(), http: URLSessionHTTPClient(loader: NativeClientHarnessBridge(client: http)))
        for common in [["_client_type": "2", "BDUSS": "fx", "stoken": "fy"],
                       ["_client_type": "1", "BDUSS": "old", "stoken": "fy"]] {
            await #expect(throws: NativeReplyReadError.invalidContext) {
                try await client.load(business: ["kz": "101", "last_pid": "430001", "mark_type": "2"],
                                      common: common, httpContext: httpContext, boundary: "FixtureBoundary")
            }
        }
        #expect(await http.events().isEmpty)
    }

    @Test func getMyPostUsesNativePbListDescriptorAndReceiptID() throws {
        for sample in try fixtures().requests {
            let bytes = try NativeReplyReadProtocol.encode(business: sample.business, common: sample.common)
            #expect(bytes == Data(base64Encoded: sample.wireBase64), "\(sample.name)")
            let request = try NativeReplyReadProtocol.request(
                business: sample.business, common: sample.common, context: httpContext, boundary: "FixtureBoundary")
            #expect(request.url.absoluteString == "https://tiebac.baidu.com/c/f/pb/getmypost?cmd=309751&format=protobuf")
            #expect(request.headers["x_bd_data_type"] == "protobuf")
            #expect(request.headers["Retry-Count"] == "0")
            #expect(request.body?.range(of: bytes) != nil)
            #expect(request.timeout == 10)
        }
    }

    @Test func successfulReplyWithoutPageNumberIsAnUpdateNotARefreshFailure() throws {
        let sample = try #require(fixtures().responses.first { $0.name == "success" })
        var response = try TiebaNativeWrite_ReplyReadResponse(serializedBytes: #require(Data(base64Encoded: sample.wireBase64)))
        // The real read returned success, a matching thread and one target post,
        // with page.current_page=0. No user bytes or identifiers are retained.
        for total in [0, 1, 3] {
            var page = Tieba_Page()
            page.totalPage = Int32(total)
            response.data.page = try page.serializedData()
            let bytes = try response.serializedData()
            #expect(throws: Never.self) {
                let update = try NativeReplyReadProtocol.decode(bytes, threadID: 101, targetPostID: 430001)
                #expect(update.posts.map(\.id.postID) == [430001])
                #expect(update.page == nil)
            }
            #expect(throws: NativeReplyReadError.missingTarget) {
                try NativeReplyReadProtocol.decode(bytes, threadID: 101, targetPostID: 999)
            }
        }
    }

    @Test(arguments: [0, 2, 13])
    func replyFloorMetadataDoesNotChangeReplyIdentity(floor: UInt32) throws {
        var response = try TiebaNativeWrite_ReplyReadResponse(serializedBytes: U08ReplyReadFixture.bytes())
        response.data.page = Data()
        var post = try Tieba_Post(serializedBytes: #require(response.data.postList.first))
        post.floor = floor
        response.data.postList = [try post.serializedData()]
        let update = try NativeReplyReadProtocol.decode(response.serializedData(), threadID: 101, targetPostID: 430001)
        let reply = try #require(update.posts.first)
        #expect(reply.floorNumber == Int(floor))
        #expect(reply.document.source.scope == .post)
        let row = ThreadReaderPostRowModel(reply, title: "Fixture title", replyCount: 9)
        #expect(row.title == nil && row.replyCount == nil)
        #expect(row.source.scope == .post)
    }

    @Test func responseRequiresMatchingThreadAndActualReturnedTarget() throws {
        let samples = try fixtures().responses
        let success = try #require(samples.first { $0.name == "success" })
        let result = try NativeReplyReadProtocol.decode(
            try #require(Data(base64Encoded: success.wireBase64)), threadID: 101, targetPostID: 430001)
        #expect(result.threadID == 101 && result.page?.currentPage == 3)
        #expect(result.posts.map(\.id.postID) == [430001])
        #expect(result.posts.first?.floorNumber == 61)
        #expect(result.posts.first?.agreeCount == 3)
        #expect(result.page?.replyCount == 61 && result.page?.hasMore == false)
        let first = try #require(samples.first { $0.name == "success-first-floor" })
        let firstPage = try NativeReplyReadProtocol.decode(
            try #require(Data(base64Encoded: first.wireBase64)), threadID: 101, targetPostID: 301)
        #expect(firstPage.posts.map(\.id.postID) == [301, 430001])
        #expect(firstPage.posts.map(\.floorNumber) == [1, 2])
        for sample in samples where !sample.name.hasPrefix("success") {
            let bytes = try #require(Data(base64Encoded: sample.wireBase64))
            #expect(throws: (any Error).self) {
                try NativeReplyReadProtocol.decode(bytes, threadID: 101, targetPostID: 430001)
            }
        }
    }

    @Test func missingContextCannotFallBackToPageOneOrSendMalformedRequest() throws {
        for fields in [[String: String](), ["kz": "101", "last_pid": "0", "mark_type": "2"],
                       ["kz": "101", "last_pid": "430001", "mark_type": "0"],
                       ["kz": "101", "last_pid": "430001", "mark_type": "2", "ad_param": "unknown"]] {
            #expect(throws: (any Error).self) {
                try NativeReplyReadProtocol.request(business: fields, common: [:], context: httpContext, boundary: "FixtureBoundary")
            }
        }
        #expect(throws: (any Error).self) {
            try NativeReplyReadProtocol.decode(Data(), threadID: 101, targetPostID: 430001)
        }
    }

    private var httpContext: NativeWriteHTTPContext {
        .init(userAgent: "FixtureAgent", acceptLanguage: "zh-Hans;q=1", clientLogID: 42,
              timeout: 10, responseState: nil,
              cookies: .init(networkStatus: 1, wifiKeepAlive: false, cellularKeepAlive: false,
                             smallFlow: false, smallFlowValue: nil))
    }

    private func fixtures() throws -> Samples {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        return try JSONDecoder().decode(Samples.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-reply-read.json")))
    }

    private struct Samples: Decodable {
        let requests: [RequestSample]
        let responses: [ResponseSample]
    }
    private struct RequestSample: Decodable {
        let name: String
        let business: [String: String]
        let common: [String: String]
        let wireBase64: String
    }
    private struct ResponseSample: Decodable {
        let name: String
        let wireBase64: String
    }
}
