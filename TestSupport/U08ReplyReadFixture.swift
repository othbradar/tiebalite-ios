import Foundation
#if TEST_SUPPORT
import Testing
@testable import TiebaLite

enum U08ReplyReadFixture {
    static func bytes() throws -> Data {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-reply-read.json"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let responses = try #require(object["responses"] as? [[String: String]])
        let encoded = try #require(responses.first { $0["name"] == "success" }?["wireBase64"])
        return try #require(Data(base64Encoded: encoded))
    }

    static func page(_ number: Int, ids: [Int64], hasMore: Bool) throws -> ThreadReaderSnapshot {
        let base = try #require(NativeReplyReadProtocol.decode(bytes(), threadID: 101, targetPostID: 430001).page)
        let posts = ids.map { id in
            let source = ThreadContentSource(threadID: 101, postID: id, scope: .post)
            return ThreadReaderPost(floorNumber: Int(id), author: base.author, metadata: "Fixture",
                                    document: .init(source: source, availability: .available, nodes: [], poll: nil))
        }
        return .init(threadID: 101, title: base.title, forumName: base.forumName, forumID: 9,
                     author: base.author, replyCount: Int32(ids.last ?? 0), posts: posts,
                     currentPage: number, totalPage: 3, hasMore: hasMore, nextPostID: hasMore ? ids.last : nil)
    }
}

actor U08ReplyPageSource: ThreadReaderRepository {
    private(set) var pages: [Int] = []
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        let page = max(1, request.pageNumber)
        pages.append(page)
        return try U08ReplyReadFixture.page(page, ids: [Int64(page * 10)], hasMore: page < 3)
    }
}

struct U08ReplyLoader: ReplyFollowupLoading {
    let http: HarnessMockHTTPClient
    var nativeResponse = false
    func loadReply(_ request: ReplyFollowupRequest) async throws -> ReplyReadUpdate? {
        let url = try #require(URL(string: "https://fixture.invalid/reply-read"))
        let result = try await http.execute(.init(method: .get, url: url))
        guard result.statusCode == 200 else { throw HTTPClientError.server(statusCode: result.statusCode) }
        if nativeResponse {
            return try NativeReplyReadProtocol.decode(result.body, threadID: request.receipt.threadID,
                                                      targetPostID: request.receipt.postID)
        }
        return .page(try JSONDecoder().decode(ThreadReaderSnapshot.self, from: result.body))
    }
}
#endif
