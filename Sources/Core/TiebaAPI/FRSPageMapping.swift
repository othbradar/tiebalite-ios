import Foundation
import GeneratedProtobuf

extension FRSPageProtocol {
    static func map(
        _ response: Tieba_FrsPage_FrsPageResponse,
        requestedRoute: ForumRoute
    ) throws -> ForumHomeSnapshot {
        try map(
            response,
            request: ForumHomePageRequest(route: requestedRoute)
        )
    }

    static func map(
        _ response: Tieba_FrsPage_FrsPageResponse,
        request: ForumHomePageRequest
    ) throws -> ForumHomeSnapshot {
        guard response.hasData else {
            throw FRSPageProtocolError.missingData
        }
        let data = response.data
        guard data.hasForum else {
            throw FRSPageProtocolError.missingForum
        }
        let forum = data.forum
        let requestedRoute = request.route
        if let requestedID = requestedRoute.forumID,
           forum.id > 0,
           forum.id != requestedID.rawValue {
            throw FRSPageProtocolError.forumIdentityMismatch
        }

        let forumName = nonempty(
            forum.name,
            fallback: requestedRoute.forumName.rawValue
        )
        let threads = try mapThreads(data.threadList, userList: data.userList, forumName: forumName)

        return ForumHomeSnapshot(
            forum: ForumSummary(
                forumID: forum.id > 0
                    ? forum.id
                    : requestedRoute.forumID?.rawValue,
                name: forumName,
                slogan: nonempty(forum.slogan),
                avatarResourceID: nonempty(forum.avatar),
                memberCount: Int(max(0, forum.memberNum)),
                threadCount: Int(max(0, forum.threadNum)),
                postCount: Int(max(0, forum.postNum)),
                levelID: forum.userLevel > 0 ? Int(forum.userLevel) : nil,
                levelName: nonempty(forum.levelName),
                navigation: mapNavigation(data),
                membership: membership(forum)
            ),
            threads: threads,
            currentPage: request.pageNumber,
            hasMore: data.hasPage && data.page.hasMore_p != 0
        )
    }

    static func mapThreads(
        _ threadList: [Tieba_ThreadInfo], userList: [Tieba_User], forumName: String
    ) throws -> [ForumThreadSummary] {
        let users = Dictionary(
            userList.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var seenThreadIDs: Set<Int64> = []
        let threads = threadList.compactMap { thread -> ForumThreadSummary? in
            guard thread.id > 0,
                  thread.threadID > 0,
                  seenThreadIDs.insert(thread.threadID).inserted else {
                return nil
            }
            let title = threadTitle(thread)
            let author = mapAuthor(thread, users: users)
            return ForumThreadSummary(
                itemID: thread.id,
                threadID: thread.threadID,
                title: title,
                summary: threadSummary(thread, excluding: title),
                forumName: nonempty(thread.forumName, fallback: forumName),
                authorName: author?.displayName ?? "未知作者",
                replyCount: max(0, thread.replyNum),
                viewCount: max(0, thread.viewNum),
                isPinned: thread.isTop == 1,
                mediaCount: thread.media.count,
                thumbnailResources: Array(
                    thread.media.enumerated().lazy.compactMap { index, media in
                        ThreadListImageResourceMapper.map(
                            bigPicture: media.bigPic,
                            dynamicPicture: media.dynamicPic,
                            sourcePicture: media.srcPic,
                            originalPicture: media.originPic,
                            ownerResourceID:
                                "forum.t\(thread.threadID).media.\(index + 1)"
                        )
                    }
                ),
                hasVideo: thread.hasVideoInfo,
                author: author,
                metadata: ForumThreadMetadata(
                    showsTitle: thread.isNoTitle != 1,
                    timeUnixSeconds: thread.lastTimeInt > 0 ? UInt32(thread.lastTimeInt) : nil,
                    agreeCount: thread.agreeNum > 0 ? Int64(thread.agreeNum) : nil,
                    shareCount: thread.shareNum > 0 ? thread.shareNum : nil
                )
            )
        }
        guard threadList.isEmpty || !threads.isEmpty else {
            throw FRSPageProtocolError.invalidItems
        }

        return threads
    }

    private static func mapNavigation(_ data: Tieba_FrsPage_FrsPageResponseData) -> ForumNavigation {
        var seen: Set<Int32> = []
        let categories = data.navTabInfo.tab.compactMap { tab -> ForumCategory? in
            guard tab.isGeneralTab == 1, tab.tabType == 15, tab.tabID > 0,
                  let title = nonempty(tab.tabName), seen.insert(tab.tabID).inserted else { return nil }
            var sortIDs: Set<Int32> = []
            let sorts = tab.sortMenu.compactMap { item -> ForumCategorySort? in
                guard let title = nonempty(item.text), sortIDs.insert(item.sourceID).inserted else { return nil }
                return ForumCategorySort(id: item.sourceID, title: title)
            }
            return ForumCategory(id: tab.tabID, title: title, isDefault: tab.isDefault, sorts: sorts)
        }
        var goodIDs: Set<Int32> = []
        let good = data.forum.goodClassify.compactMap { item -> ForumGoodCategory? in
            guard item.classID >= 0, let title = nonempty(item.className),
                  goodIDs.insert(item.classID).inserted else { return nil }
            return ForumGoodCategory(id: item.classID, title: title)
        }
        return ForumNavigation(categories: categories, goodCategories: good,
                               ruleTitle: data.forumRule.hasForumRule_p == 1 ? nonempty(data.forumRule.title) : nil)
    }

    private static func membership(_ forum: Tieba_FrsPage_ForumInfo) -> ForumMembership? {
        guard forum.isLike == 1 else { return nil }
        let user = forum.signInInfo.userInfo
        return ForumMembership(currentScore: Int(forum.curScore), levelUpScore: Int(forum.levelupScore),
                               isFollowed: true, signedDays: user.isSignIn == 1 ? Int(max(0, user.contSignNum)) : nil)
    }

    private static func mapAuthor(
        _ thread: Tieba_ThreadInfo,
        users: [Int64: Tieba_User]
    ) -> TiebaUserVisuals? {
        if let user = users[thread.authorID] {
            return TiebaUserVisualMapper.map(user)
        }
        if thread.hasAuthor {
            return TiebaUserVisualMapper.map(thread.author)
        }
        return thread.authorID > 0 ? TiebaUserVisuals(
            rawUserID: thread.authorID, displayName: "未知作者"
        ) : nil
    }

    private static func threadTitle(_ thread: Tieba_ThreadInfo) -> String {
        let title = thread.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !title.isEmpty {
            return title
        }
        let richAbstract = thread.richAbstract
            .filter { $0.type == 0 || $0.type == 40 }
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return richAbstract.isEmpty ? "无标题" : richAbstract
    }

    private static func threadSummary(
        _ thread: Tieba_ThreadInfo,
        excluding title: String
    ) -> String? {
        let rich = thread.richAbstract
            .filter { $0.type == 0 || $0.type == 40 }
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let legacy = thread.abstract
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = rich.isEmpty ? legacy : rich
        guard !summary.isEmpty, summary != title else {
            return nil
        }
        return summary
    }

    private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonempty(
        _ value: String,
        fallback: String
    ) -> String {
        nonempty(value) ?? fallback
    }

}
