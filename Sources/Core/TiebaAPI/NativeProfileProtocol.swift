import CoreFoundation
import Foundation
import GeneratedProtobuf
import SwiftProtobuf
#if DEBUG
import OSLog
#endif

/// iOS TBCMyPostAndReplyModel / TBCPersonFavBarsModel / TBCPersonalInfoModel.
/// These adapters share transport primitives only, never the posting runtime.
enum NativeProfileProtocol {
    static func business(_ route: ProfileListRoute, cursor: ProfileCursor?, accountID: Int64?) throws -> [String: String] {
        let page = cursor?.page ?? 1
        guard page > 0 else { throw ProfileContentFailure.invalidData }
        let uid = route.user.userID.rawValue
        if route.section == .replies, accountID != uid { throw ProfileContentFailure.privateContent }
        if route.section == .forums {
            var fields = ["page_no": String(page), "page_size": "50"]
            if let accountID { fields["uid"] = String(accountID) }
            if accountID != uid { fields["friend_uid"] = String(uid); fields["is_guest"] = "1" }
            return fields
        }
        var fields = ["uid": String(uid), "rn": "20", "pn": String(page), "need_content": "1",
                      "is_thread": route.section == .threads ? "1" : "0", "is_view_card": "0"]
        if let time = cursor?.lastThreadTime { fields["last_thread_time"] = String(time) }
        return fields
    }

    static func encode(_ business: [String: String], common: [String: String]) throws -> Data {
        guard common["_client_type"] == "1" else { throw ProfileContentFailure.invalidData }
        var common = common
        for key in ["personalized_rec_switch", "net_type"] where common[key]?.isEmpty == true { common[key] = "0" }
        var fields: [String: Any] = business
        fields["common"] = common
        var options = JSONDecodingOptions(); options.ignoreUnknownFields = true
        var encoding = BinaryEncodingOptions(); encoding.useDeterministicOrdering = true
        return try TiebaNativeProfiles_Request(jsonUTF8Bytes: JSONSerialization.data(withJSONObject: ["data": fields]),
                                               options: options).serializedData(options: encoding)
    }

    static func posts(_ bytes: Data, section: ProfileSection, cursor: ProfileCursor?) throws -> ProfileContentPage {
        guard !bytes.isEmpty else { throw ProfileContentFailure.invalidData }
        let response = try TiebaNativeProfiles_Response(serializedBytes: bytes)
        if response.error.errorno != 0 { throw EndpointWireFailure.server(code: Int(response.error.errorno)) }
        guard response.hasData else { throw ProfileContentFailure.invalidData }
        guard response.data.hidePost != 1 else { throw ProfileContentFailure.privateContent }
        var seen = Set<Int64>()
        let rows = try response.data.postList.compactMap { post -> ProfilePost? in
            guard let tid = Int64(exactly: post.threadID), tid > 0, post.isPostDeleted != 1 else { return nil }
            let pid = Int64(exactly: post.postID).flatMap { $0 > 0 ? $0 : nil }
                ?? post.content.first.flatMap { Int64(exactly: $0.postID) }.flatMap { $0 > 0 ? $0 : nil }
            guard let id = section == .replies ? pid : tid, seen.insert(id).inserted else { return nil }
            let name = post.nameShow.isEmpty ? post.userName.isEmpty ? "未知作者" : post.userName : post.nameShow
            let author = TiebaUserVisuals(rawUserID: post.userID, displayName: name,
                                          portrait: post.userPortrait.isEmpty ? nil : post.userPortrait)
            let abstract = section == .replies ? post.content.flatMap(\.postContent) : post.abstractThread
            var projected = Tieba_ThreadInfo()
            projected.abstract = try abstract.map { try Tieba_Abstract(serializedBytes: $0) }
            projected.media = try post.media.map { try Tieba_Media(serializedBytes: $0) }
            projected.title = post.title
            let details = RecommendationFeedMapper.map(projected, ownerThreadID: tid)
            let images = projected.media.enumerated().compactMap { index, media in
                ThreadListImageResourceMapper.map(bigPicture: media.bigPic, dynamicPicture: media.dynamicPic,
                                                  sourcePicture: media.srcPic, originalPicture: media.originPic,
                                                  ownerResourceID: "profile.p\(id).media.\(index + 1)")
            }
            let summary = ForumThreadSummary(
                itemID: id, threadID: tid, title: post.title.isEmpty ? "无标题" : post.title,
                summary: details.abstractText, forumName: post.forumName, authorName: name,
                replyCount: Int32(clamping: post.replyNum), viewCount: max(0, post.viewNum), isPinned: false,
                mediaCount: details.totalMediaCount, thumbnailResources: images, author: author,
                metadata: .init(timeUnixSeconds: post.createTime > 0 ? post.createTime : nil,
                                agreeCount: Int64(max(0, post.agreeNum)), shareCount: Int64(max(0, post.shareNum))))
            return .init(id: id, postID: pid, summary: summary)
        }
        // Native model continues on a nonempty raw page. Filtering/deletion must
        // never turn that server cursor into an end marker.
        let lastTime = response.data.postList.last.map(\.createTime).flatMap { $0 > 0 ? $0 : nil }
        let next = response.data.postList.isEmpty ? nil : ProfileCursor(page: (cursor?.page ?? 1) + 1,
                                                                        lastThreadTime: lastTime)
        log(section.rawValue, raw: response.data.postList.count, mapped: rows.count, more: next != nil)
        return .init(posts: rows, forums: [], next: next)
    }

    static func forums(_ bytes: Data, cursor: ProfileCursor?) throws -> ProfileContentPage {
        let json = try fields(bytes)
        // A successful metadata-only response provides no viewable list. It does
        // not identify the reason, so do not label it as a confirmed privacy setting.
        if json["forum_list"] == nil && json["has_more"] == nil { throw ProfileContentFailure.contentUnavailable }
        let rows: [[String: Any]]
        if let list = json["forum_list"] as? [[String: Any]] { rows = list } else if let groups = json["forum_list"] as? [String: Any] {
            let lists = try ["gconforum", "non-gconforum"].compactMap { key -> [[String: Any]]? in
                guard let value = groups[key] else { return nil }
                guard let list = value as? [[String: Any]] else { throw ProfileContentFailure.invalidData }
                return list
            }
            guard !lists.isEmpty else { throw ProfileContentFailure.invalidData }
            rows = lists.flatMap { $0 }
        } else { throw ProfileContentFailure.invalidData }
        var seen = Set<Int64>()
        let forums = rows.compactMap { row -> FollowedForum? in
            // TBCLikeBarListDataItem registers TBCBarDataItem for every array.
            guard let id = integer(row["id"]), id > 0, let name = row["name"] as? String,
                  !name.isEmpty, seen.insert(id).inserted else { return nil }
            return .init(forumID: id, name: name, avatarResourceID: row["avatar"] as? String,
                         hotCount: 0, memberCount: Int(integer(row["member_count"]) ?? 0), threadCount: 0,
                         levelID: integer(row["level_id"]).map(Int.init), levelName: nil,
                         isSignedToday: false)
        }
        guard rows.isEmpty || !forums.isEmpty else { throw ProfileContentFailure.invalidData }
        guard let more = integer(json["has_more"]), more == 0 || more == 1 else { throw ProfileContentFailure.invalidData }
        log("forums", raw: rows.count, mapped: forums.count, more: more == 1)
        return .init(posts: [], forums: forums, next: more == 1 ? .init(page: (cursor?.page ?? 1) + 1, lastThreadTime: nil) : nil)
    }

    static func relationship(_ bytes: Data, userID: Int64) throws -> ProfileRelationship {
        let json = try fields(bytes)
        guard let user = json["user"] as? [String: Any], integer(user["id"]) == userID else {
            throw ProfileContentFailure.identityUnavailable
        }
        let value = integer(user["has_concerned"])
        let portrait = (user["portrait"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return .init(userID: userID, portrait: portrait, isFollowed: value.flatMap { $0 == 0 ? false : $0 == 1 ? true : nil })
    }

    private static func log(_ kind: String, raw: Int, mapped: Int, more: Bool) {
        #if DEBUG
        Logger(subsystem: "dev.local.tiebaliteios", category: "profile-read")
            .info("native profile kind=\(kind, privacy: .public) raw=\(raw) mapped=\(mapped) more=\(more)")
        #endif
    }

    static func confirm(_ bytes: Data) throws { _ = try fields(bytes) }

    private static func fields(_ bytes: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            throw ProfileContentFailure.invalidData
        }
        let codes = [json["error_code"], (json["error"] as? [String: Any])?["errno"]].compactMap { $0 }
        guard !codes.isEmpty else { throw ProfileContentFailure.invalidData }
        for value in codes {
            guard let code = integer(value) else { throw ProfileContentFailure.invalidData }
            if code != 0 { throw EndpointWireFailure.server(code: Int(code)) }
        }
        return json
    }

    private static func integer(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            return Int64(number.stringValue)
        }
        return (value as? String).flatMap(Int64.init)
    }
}
