import Foundation
import GeneratedProtobuf

enum PBPageDomainMapper {
    private struct PostMappingContext {
        let threadID: Int64
        let scope: ThreadContentSource.Scope
        let fallbackAuthor: ThreadReaderAuthor?
        let users: [Tieba_User]
        let poll: Tieba_PollInfo?
    }

    static func map(
        _ response: Tieba_PbPage_PbPageResponse,
        request: ThreadReaderPageRequest
    ) throws -> ThreadReaderSnapshot {
        let data = try validatedData(response, request: request)
        let posts = try mappedPosts(data, request: request)
        let currentPage = Int(data.page.currentPage)
        let totalPage = firstPositive(
            data.page.newTotalPage,
            data.page.totalPage
        )
        let hasMore = data.page.hasMore_p != 0
        let nextPostID = hasMore
            ? nextPagePostID(
                from: data.thread.pids,
                excluding: request.loadedPostIDs.union(
                    posts.map(\.id.postID)
                )
            ) ?? 0
            : nil
        return ThreadReaderSnapshot(
            threadID: request.threadID,
            title: nonempty(data.thread.title, fallback: "无标题"),
            forumName: forumName(data),
            author: mapAuthor(data.thread.author),
            replyCount: max(0, data.thread.replyNum),
            posts: posts,
            currentPage: currentPage,
            totalPage: totalPage > 0 ? Int(totalPage) : nil,
            hasMore: hasMore,
            nextPostID: nextPostID
        )
    }

    private static func validatedData(
        _ response: Tieba_PbPage_PbPageResponse,
        request: ThreadReaderPageRequest
    ) throws -> Tieba_PbPage_PbPageResponseData {
        guard response.hasData else {
            throw PBPageProtocolError.missingData
        }
        let data = response.data
        guard data.hasThread else {
            throw PBPageProtocolError.missingThread
        }
        guard data.hasPage else {
            throw PBPageProtocolError.missingPage
        }
        let expectedPage = request.pageNumber == 0 ? 1 : request.pageNumber
        guard Int(data.page.currentPage) == expectedPage else {
            throw PBPageProtocolError.pageIdentityMismatch(
                requested: expectedPage,
                received: Int(data.page.currentPage)
            )
        }
        let receivedThreadID = firstPositive(
            data.thread.threadID,
            data.thread.id
        )
        if receivedThreadID > 0, receivedThreadID != request.threadID {
            throw PBPageProtocolError.threadIdentityMismatch(
                requested: request.threadID,
                received: receivedThreadID
            )
        }
        return data
    }

    private static func mappedPosts(
        _ data: Tieba_PbPage_PbPageResponseData,
        request: ThreadReaderPageRequest
    ) throws -> [ThreadReaderPost] {
        var seenPostIDs: Set<Int64> = []
        var posts: [ThreadReaderPost] = []
        if request.pageNumber == 0 {
            let firstPost = data.postList.first { $0.floor == 1 }
                ?? (data.hasFirstFloorPost ? data.firstFloorPost : nil)
            guard let firstPost,
                  let mapped = makePost(
                      firstPost,
                      context: context(
                          data,
                          threadID: request.threadID,
                          isFirstPost: true
                      )
                  ) else {
                throw PBPageProtocolError.missingFirstPost
            }
            seenPostIDs.insert(mapped.id.postID)
            posts.append(mapped)
        }

        for post in data.postList {
            guard request.pageNumber == 0 || post.floor != 1 else {
                continue
            }
            let isFirstPost = post.floor == 1
            guard let mapped = makePost(
                post,
                context: context(
                    data,
                    threadID: request.threadID,
                    isFirstPost: isFirstPost
                )
            ), seenPostIDs.insert(mapped.id.postID).inserted else {
                continue
            }
            posts.append(mapped)
        }
        return posts
    }

    private static func context(
        _ data: Tieba_PbPage_PbPageResponseData,
        threadID: Int64,
        isFirstPost: Bool
    ) -> PostMappingContext {
        PostMappingContext(
            threadID: threadID,
            scope: isFirstPost ? .firstPost : .post,
            fallbackAuthor: isFirstPost ? mapAuthor(data.thread.author) : nil,
            users: data.userList,
            poll: isFirstPost && data.thread.hasPollInfo
                ? data.thread.pollInfo
                : nil
        )
    }

    private static func makePost(
        _ post: Tieba_Post,
        context: PostMappingContext
    ) -> ThreadReaderPost? {
        guard post.id > 0, post.id <= UInt64(Int64.max) else {
            return nil
        }
        let postID = Int64(post.id)
        let source = ThreadContentSource(
            threadID: context.threadID,
            postID: postID,
            scope: context.scope
        )
        let availability: ThreadContentAvailability = post.isFold == 0
            ? .available
            : .unavailable(.folded(
                message: post.foldTip.isEmpty ? nil : post.foldTip
            ))
        let createdAt = post.time > 0 ? post.time : nil
        return ThreadReaderPost(
            floorNumber: context.scope == .firstPost
                ? max(1, Int(post.floor))
                : Int(post.floor),
            author: postAuthor(
                post,
                fallback: context.fallbackAuthor,
                users: context.users
            ),
            metadata: nonempty(
                post.timeEx,
                fallback: timestampMetadata(createdAt, fallback: "公开帖子")
            ),
            createdAtUnixSeconds: createdAt,
            document: ThreadContentProtoMapper.map(
                postContent: post.content,
                source: source,
                availability: availability,
                poll: context.poll
            ),
            subposts: makeSubposts(
                post,
                parentPostID: postID,
                threadID: context.threadID,
                users: context.users
            ),
            subpostTotal: Int(exactly: post.subPostNumber) ?? Int.max
        )
    }

    private static func makeSubposts(
        _ post: Tieba_Post,
        parentPostID: Int64,
        threadID: Int64,
        users: [Tieba_User]
    ) -> [ThreadReaderSubpost] {
        guard post.hasSubPostList else {
            return []
        }
        var seen: Set<Int64> = []
        return post.subPostList.subPostList.compactMap { subpost in
            guard subpost.id > 0, subpost.id <= UInt64(Int64.max) else {
                return nil
            }
            let subPostID = Int64(subpost.id)
            guard seen.insert(subPostID).inserted else {
                return nil
            }
            let source = ThreadContentSource(
                threadID: threadID,
                postID: subPostID,
                scope: .subPost
            )
            let createdAt = subpost.time > 0 ? subpost.time : nil
            return ThreadReaderSubpost(
                parentPostID: parentPostID,
                author: subpostAuthor(subpost, users: users),
                replyToDisplayName: nil,
                metadata: timestampMetadata(
                    createdAt,
                    fallback: "楼中楼回复"
                ),
                createdAtUnixSeconds: createdAt,
                document: ThreadContentProtoMapper.map(
                    postContent: subpost.content,
                    source: source,
                    availability: .available,
                    poll: nil
                )
            )
        }
    }

    private static func postAuthor(
        _ post: Tieba_Post,
        fallback: ThreadReaderAuthor?,
        users: [Tieba_User]
    ) -> ThreadReaderAuthor {
        if post.hasAuthor {
            return mapAuthor(post.author)
        }
        if let user = users.first(where: {
            post.authorID > 0 && $0.id == post.authorID
        }) {
            return mapAuthor(user)
        }
        return fallback ?? unknownAuthor(rawUserID: post.authorID)
    }

    private static func subpostAuthor(
        _ subpost: Tieba_SubPostList,
        users: [Tieba_User]
    ) -> ThreadReaderAuthor {
        if subpost.hasAuthor {
            return mapAuthor(subpost.author)
        }
        if let user = users.first(where: {
            subpost.authorID > 0 && $0.id == subpost.authorID
        }) {
            return mapAuthor(user)
        }
        return unknownAuthor(rawUserID: subpost.authorID)
    }

    private static func nextPagePostID(
        from rawPIDs: String,
        excluding postIDs: Set<Int64>
    ) -> Int64? {
        return rawPIDs
            .split(separator: ",")
            .compactMap { Int64(String($0).trimmingCharacters(in: .whitespaces)) }
            .last(where: { $0 > 0 && !postIDs.contains($0) })
    }

    private static func timestampMetadata(
        _ seconds: UInt32?,
        fallback: String
    ) -> String {
        guard let seconds else {
            return fallback
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds)).formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    private static func mapAuthor(_ user: Tieba_User) -> ThreadReaderAuthor {
        let name = nonempty(user.nameShow, fallback: user.name)
        return ThreadReaderAuthor(
            rawUserID: max(0, user.id),
            displayName: nonempty(name, fallback: "未知作者")
        )
    }

    private static func unknownAuthor(rawUserID: Int64) -> ThreadReaderAuthor {
        ThreadReaderAuthor(
            rawUserID: max(0, rawUserID),
            displayName: "未知作者"
        )
    }

    private static func forumName(
        _ data: Tieba_PbPage_PbPageResponseData
    ) -> String {
        if data.hasForum, !data.forum.name.isEmpty {
            return data.forum.name
        }
        return nonempty(data.thread.forumName, fallback: "未知吧")
    }

    private static func firstPositive(_ values: Int64...) -> Int64 {
        values.first(where: { $0 > 0 }) ?? 0
    }

    private static func firstPositive(_ values: Int32...) -> Int32 {
        values.first(where: { $0 > 0 }) ?? 0
    }

    private static func nonempty(
        _ value: String,
        fallback: String
    ) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
