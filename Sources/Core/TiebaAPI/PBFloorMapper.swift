import Foundation
import GeneratedProtobuf

enum PBFloorMapper {
    static func map(_ response: Tieba_PbFloor_PbFloorResponse, route: SubpostsRoute, page: Int) throws -> SubpostsPage {
        guard route.threadID > 0, route.postID > 0, page > 0 else { throw PBFloorProtocolError.invalidRequest }
        guard response.hasData, response.data.hasPage else { throw PBFloorProtocolError.missingData }
        let data = response.data
        guard data.page.currentPage == page, data.page.totalPage >= 0 else { throw PBFloorProtocolError.invalidPage }
        if data.hasThread {
            let id = data.thread.threadID > 0 ? data.thread.threadID : data.thread.id
            guard id == route.threadID else { throw PBFloorProtocolError.identityMismatch }
        }
        if data.hasPost, data.post.id != UInt64(route.postID) { throw PBFloorProtocolError.identityMismatch }
        guard page > 1 || (data.hasPost && data.hasThread) else { throw PBFloorProtocolError.missingData }
        var seen = Set<Int64>()
        let items = data.subpostList.compactMap { item -> Subpost? in
            guard let id = Int64(exactly: item.id), id > 0, seen.insert(id).inserted else { return nil }
            return Subpost(
                author: author(item.hasAuthor ? item.author : nil, fallbackID: item.authorID),
                document: ThreadContentProtoMapper.map(
                    postContent: item.content,
                    source: .init(threadID: route.threadID, postID: id, scope: .subPost), availability: .available, poll: nil),
                createdAt: item.time > 0 ? item.time : nil,
                agreeCount: item.hasAgree ? max(0, item.agree.diffAgreeNum) : nil
            )
        }
        return SubpostsPage(
            route: route, parent: data.hasPost ? parent(data.post, route: route) : nil,
            threadAuthorID: data.thread.author.id, forumID: data.forum.id, forumName: data.forum.name,
            items: items, pageNumber: page, totalPages: Int(data.page.totalPage), totalCount: max(0, Int(data.page.totalCount)))
    }

    private static func parent(_ post: Tieba_Post, route: SubpostsRoute) -> ThreadReaderPost {
        let source = ThreadContentSource(threadID: route.threadID, postID: route.postID, scope: .post)
        let availability: ThreadContentAvailability =
            post.isFold == 0
            ? .available : .unavailable(.folded(message: post.foldTip.isEmpty ? nil : post.foldTip))
        return ThreadReaderPost(
            floorNumber: Int(post.floor), author: author(post.hasAuthor ? post.author : nil, fallbackID: post.authorID),
            metadata: post.time > 0 ? TiebaDateText.date(Date(timeIntervalSince1970: TimeInterval(post.time))) : "",
            createdAtUnixSeconds: post.time > 0 ? post.time : nil,
            document: ThreadContentProtoMapper.map(postContent: post.content, source: source, availability: availability, poll: nil),
            agreeCount: post.hasAgree ? max(0, post.agree.diffAgreeNum) : nil)
    }

    private static func author(_ user: Tieba_User?, fallbackID: Int64) -> TiebaUserVisuals {
        user.map(TiebaUserVisualMapper.map) ?? .init(rawUserID: max(0, fallbackID), displayName: "未知作者")
    }
}
