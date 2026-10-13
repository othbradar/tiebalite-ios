import CoreFoundation
import Foundation

/// TBCMarkListItem.threads <- store_thread, TBCMarkItem's explicit mapping.
/// Reject missing/malformed business results instead of treating HTTP 200 as success.
enum NativeFavoriteResponse {
    static func confirm(_ response: HTTPResponse) throws { _ = try fields(response) }

    static func page(_ response: HTTPResponse, offset: Int) throws -> FavoritePage {
        let json = try fields(response)
        guard let rows = json["store_thread"] as? [[String: Any]] else { throw FavoriteFailure.invalidData }
        let values = try rows.map { row -> ThreadFavorite in
            guard let id = integer(row["thread_id"]), id > 0 else { throw FavoriteFailure.invalidData }
            let pid = integer(row["mark_pid"])
            let title = row["title"] as? String ?? "帖子暂不可用", forum = row["forum_name"] as? String ?? ""
            return ThreadFavorite(target: .init(threadID: id, postID: pid.flatMap { $0 > 0 ? $0 : nil }),
                                  title: title, forumName: forum,
                                  status: Int(integer(row["mark_status"]) ?? 1), isDeleted: integer(row["is_deleted"]) == 1,
                                  feed: feed(row, id: id, title: title, forum: forum))
        }
        return .init(entries: values, nextOffset: rows.count >= 20 ? offset + rows.count : nil)
    }

    /// TBCMarkAuthorItem + TBCFrsMediaItem, as consumed by TBCMarkCell.bindData:.
    /// The favorite response does not promise a body excerpt, timestamps or like counts.
    private static func feed(_ row: [String: Any], id: Int64, title: String, forum: String) -> ForumThreadSummary {
        let author = (row["author"] as? [String: Any]).map { value in
            TiebaUserVisuals(
                rawUserID: integer(value["lz_uid"]) ?? 0,
                displayName: nonempty(value["name_show"]) ?? nonempty(value["name"]) ?? "未知作者",
                portrait: nonempty(value["user_portrait"]))
        }
        let media = row["media"] as? [[String: Any]] ?? []
        let images = media.enumerated().compactMap { index, value -> ImageResourceDescriptor? in
            guard let url = nonempty(value["small_pic"]) ?? nonempty(value["vpic"]) else { return nil }
            return ImageResourceDescriptor(resourceID: "favorite.t\(id).media.\(index + 1)", candidateURLs: [url])
        }
        return ForumThreadSummary(itemID: id, threadID: id, title: title, forumName: forum,
                                  authorName: author?.displayName ?? "未知作者",
                                  replyCount: Int32(clamping: max(0, integer(row["reply_num"]) ?? 0)), viewCount: 0,
                                  isPinned: false, mediaCount: images.count, thumbnailResources: images,
                                  hasVideo: media.contains { nonempty($0["vpic"]) != nil }, author: author)
    }

    private static func nonempty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private static func fields(_ response: HTTPResponse) throws -> [String: Any] {
        guard (200..<300).contains(response.statusCode) else { throw HTTPClientError.server(statusCode: response.statusCode) }
        guard let json = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any] else {
            throw FavoriteFailure.invalidData
        }
        let rawCodes = [json["error_code"], (json["error"] as? [String: Any])?["errno"]].compactMap { $0 }
        guard !rawCodes.isEmpty else { throw FavoriteFailure.invalidData }
        for value in rawCodes {
            guard let code = integer(value) else { throw FavoriteFailure.invalidData }
            guard code == 0 else { throw FavoriteFailure.rejected(code) }
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

struct NativeFavoriteRepository: FavoriteRepositoryProtocol {
    let execute: @Sendable (NativeFavoriteRequest.Operation, String) async throws -> HTTPResponse
    func page(offset: Int, account: String) async throws -> FavoritePage {
        try NativeFavoriteResponse.page(await execute(.list(offset), account), offset: offset)
    }
    func save(_ entry: ThreadFavorite, account: String) async throws { try await write(.save(entry), account: account) }
    func remove(_ threadID: Int64, account: String) async throws { try await write(.remove(threadID), account: account) }
    private func write(_ operation: NativeFavoriteRequest.Operation, account: String) async throws {
        // One submission only. A transport failure may have happened after server
        // acceptance; preserve the old UI and reconcile on an explicit refresh.
        let response: HTTPResponse
        do { response = try await execute(operation, account) } catch is CancellationError {
            throw CancellationError()
        } catch let failure as FavoriteFailure {
            throw failure
        } catch { throw FavoriteFailure.outcomeUnknown }
        do { try NativeFavoriteResponse.confirm(response) } catch let failure as FavoriteFailure {
            if case .rejected = failure { throw failure }
            throw FavoriteFailure.outcomeUnknown
        } catch { throw FavoriteFailure.outcomeUnknown }
    }
}
