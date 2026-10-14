import Foundation
import GeneratedProtobuf
import SwiftProtobuf
#if DEBUG
import OSLog
#endif

enum ExploreFeedProtocol {
    static func endpoint(_ feed: ExploreFeed) -> (path: String, command: Int) {
        feed == .following ? ("/c/f/concern/userlike", 309474) : ("/c/f/forum/hotThreadList", 309661)
    }

    static func business(_ feed: ExploreFeed, cursor: ExploreCursor?) throws -> [String: String] {
        switch feed {
        case .following:
            return ["follow_type": "1", "load_type": cursor?.pageTag.isEmpty != false ? "1" : "2",
                    "page_tag": cursor?.pageTag ?? "", "last_req_unix": String(cursor?.requestUnix ?? 0)]
        case .hot:
            guard cursor == nil else { throw ExploreFailure.invalidData }
            return ["tab_id": "1", "tab_code": "all"]
        }
    }

    static func encode(_ feed: ExploreFeed, business: [String: String], common: [String: String]) throws -> Data {
        guard common["_client_type"] == "1" else { throw ExploreFailure.invalidData }
        var common = common
        for key in ["personalized_rec_switch", "net_type"] where common[key]?.isEmpty == true { common[key] = "0" }
        var fields: [String: Any] = business
        fields["common"] = common
        let json = try JSONSerialization.data(withJSONObject: ["data": fields], options: [.sortedKeys])
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true // Native IDL drops Common annotations absent from its descriptor.
        var encoding = BinaryEncodingOptions()
        encoding.useDeterministicOrdering = true
        switch feed {
        case .following:
            return try TiebaNativeExplore_FollowingRequest(jsonUTF8Bytes: json, options: options).serializedData(options: encoding)
        case .hot:
            return try TiebaNativeExplore_HotRequest(jsonUTF8Bytes: json, options: options).serializedData(options: encoding)
        }
    }

    static func request(_ feed: ExploreFeed, business: [String: String], common: [String: String],
                        context: NativeWriteHTTPContext, boundary: String) throws -> HTTPRequest {
        try NativeWriteHTTPRequest.protobufRequest(
            endpoint: endpoint(feed), bytes: encode(feed, business: business, common: common), context: context,
            boundary: boundary, responseBodyLimit: 8 * 1_024 * 1_024)
    }

    static func decode(_ bytes: Data, feed: ExploreFeed) throws -> ExplorePage {
        guard !bytes.isEmpty else { throw ExploreFailure.invalidData }
        let payloads: [Data]
        let next: ExploreCursor?
        let requestUnix: UInt64
        switch feed {
        case .following:
            let response = try TiebaNativeExplore_FollowingResponse(serializedBytes: bytes)
            if response.error.errorno != 0 { throw EndpointWireFailure.server(code: Int(response.error.errorno)) }
            guard response.hasData else { throw ExploreFailure.invalidData }
            requestUnix = response.data.reqUnix
            payloads = response.data.threadInfo.filter { $0.recomType == 1 && $0.hasThreadList }.map(\.threadList)
#if DEBUG
            let logger = Logger(subsystem: "dev.local.tiebaliteios", category: "explore-read")
            let rows = response.data.threadInfo.count, layouts = response.data.pageData.feedList.count
            logger.info("native following rows=\(rows) threadRows=\(payloads.count) layoutRows=\(layouts)")
#endif
            // A native server-driven layout is not an empty legacy thread page.
            guard !payloads.isEmpty || response.data.pageData.feedList.isEmpty else { throw ExploreFailure.invalidData }
            next = response.data.hasMore_p == 1 && !response.data.pageTag.isEmpty
                ? .init(pageTag: response.data.pageTag, requestUnix: requestUnix) : nil
        case .hot:
            let response = try TiebaNativeExplore_HotResponse(serializedBytes: bytes)
            if response.error.errorno != 0 { throw EndpointWireFailure.server(code: Int(response.error.errorno)) }
            guard response.hasData else { throw ExploreFailure.invalidData }
            payloads = response.data.threadInfo
            next = nil; requestUnix = 0
        }
        // Only display DTOs whose wire fields were checked against native client.proto.
        let threads = try payloads.map { try Tieba_ThreadInfo(serializedBytes: $0) }
        var seen = Set<Int64>()
        return .init(items: threads.compactMap { thread in
            let id = thread.threadID > 0 ? thread.threadID : thread.id
            guard id > 0, thread.isDeleted != 1, seen.insert(id).inserted else { return nil }
            let author = thread.hasAuthor ? TiebaUserVisualMapper.map(thread.author) : nil
            let title = thread.title.isEmpty ? "无标题" : thread.title
            let details = RecommendationFeedMapper.map(thread, ownerThreadID: id)
            return RecommendationSummary(threadID: id, title: title, forumName: thread.forumName,
                                         authorName: author?.displayName ?? "未知作者", replyCount: max(0, thread.replyNum),
                                         thumbnail: details.media.first.map { .init(resource: $0, alternativeText: title) },
                                         author: author, forumID: thread.forumID > 0 ? thread.forumID : nil,
                                         feed: details)
        }, next: next, requestUnix: requestUnix)
    }
}
