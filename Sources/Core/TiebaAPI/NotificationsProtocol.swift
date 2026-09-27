import Foundation

enum NotificationsProtocol {
    static func descriptor(kind: NotificationKind?) throws -> EndpointDescriptor {
        guard let id = EndpointID("notifications.\(kind?.rawValue ?? "unread")") else { throw EndpointExecutionError.mapping }
        return try EndpointDescriptor(
            id: id, method: .post, host: "c.tieba.baidu.com", path: kind?.path ?? "/c/s/msg",
            fixedHeaders: ["User-Agent": "bdtb for Android 8.2.2", "Cookie": "ka=open", "Pragma": "no-cache"],
            bodyCodec: .formURLEncoded, responseFamily: .json,
            allowedResponseMIMETypes: ["application/json", "application/x-javascript", "text/json", "text/html", "text/plain"],
            authentication: .active, timeout: 30, responseBodyLimit: 4 * 1_024 * 1_024,
            redirectPolicy: .reject, retryPolicy: .never)
    }

    static func body(kind: NotificationKind?, page: Int, authorization: SessionAuthorization) throws -> EndpointRequestBody {
        guard page >= 0 else { throw EndpointExecutionError.mapping }
        var fields = ["BDUSS": authorization.bduss, "_client_type": "2", "_client_version": "8.2.2", "from": "baidu_appstore"]
        fields[kind == nil ? "bookmark" : "pn"] = kind == nil ? "1" : String(page)
        return .formURLEncoded(TextWriteProtocol.signedFields(fields))
    }

    static func decodePage(_ data: Data, kind: NotificationKind, page: Int) throws -> NotificationPage {
        let response = try decodeResponse(data)
        try validate(response)
        let rows = kind == .replies ? response.replyList : response.atList
        let expected = page == 0 ? 1 : page
        if let actual = response.page?.currentPage, actual != expected { throw EndpointExecutionError.mapping }
        var seen = Set<String>()
        let items = rows.compactMap { row -> TiebaNotification? in
            guard let threadID = row.threadID, threadID > 0, let postID = row.postID, postID > 0 else { return nil }
            let id = "\(kind.rawValue).\(postID).\(row.author.id).\(row.time ?? 0)"
            guard seen.insert(id).inserted else { return nil }
            return TiebaNotification(
                id: id, author: .init(rawUserID: row.author.id, displayName: row.author.name, portrait: row.author.portrait),
                createdAt: row.time.map { Date(timeIntervalSince1970: TimeInterval($0)) }, content: row.content,
                quote: kind == .mentions ? row.title : (row.isFloor ? row.quote : "回复我的主题：\(row.title)"),
                target: .init(threadID: threadID, postID: postID, isSubpost: row.isFloor))
        }
        guard rows.isEmpty || !items.isEmpty else { throw EndpointExecutionError.mapping }
        return .init(items: items, nextPage: response.page?.hasMore == true && !items.isEmpty ? expected + 1 : nil)
    }

    static func decodeCounts(_ data: Data) throws -> NotificationCounts {
        let response = try decodeResponse(data)
        try validate(response)
        guard let counts = response.message else { throw EndpointExecutionError.mapping }
        return counts
    }

    private static func decodeResponse(_ data: Data) throws -> NotificationResponse {
        try JSONDecoder().decode(NotificationResponse.self, from: data)
    }

    private static func validate(_ response: NotificationResponse) throws {
        guard let code = response.errorCode else { throw EndpointExecutionError.decode }
        guard code == 0 else { throw EndpointWireFailure.server(code: code) }
    }
}

private struct NotificationResponse: Decodable {
    let errorCode: Int?
    let replyList: [NotificationWireRow]
    let atList: [NotificationWireRow]
    let page: NotificationWirePage?
    let message: NotificationCounts?
    enum CodingKeys: String, CodingKey { case errorCode = "error_code", replyList = "reply_list", atList = "at_list", page, message }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = try values.flexibleString(forKey: .errorCode).flatMap(Int.init)
        replyList = try Self.rows(values, .replyList)
        atList = try Self.rows(values, .atList)
        page = try values.decodeIfPresent(NotificationWirePage.self, forKey: .page)
        message = try values.decodeIfPresent(NotificationWireCounts.self, forKey: .message)?.value
    }
    private static func rows(_ values: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> [NotificationWireRow] {
        guard values.contains(key), try !values.decodeNil(forKey: key) else { return [] }
        // Android MessageListAdapter treats any JSON primitive as an empty list.
        if (try? values.decode(String.self, forKey: key)) != nil || (try? values.decode(Double.self, forKey: key)) != nil
            || (try? values.decode(Bool.self, forKey: key)) != nil { return [] }
        return try values.decode([NotificationWireRow].self, forKey: key)
    }
}

private struct NotificationWireRow: Decodable {
    let threadID: Int64?
    let postID: Int64?
    let time: Int64?
    let isFloor: Bool
    let title: String
    let content: String
    let quote: String
    let author: NotificationWireAuthor
    enum CodingKeys: String, CodingKey {
        case threadID = "thread_id", postID = "post_id", time, isFloor = "is_floor", title, content, quote = "quote_content", replyer
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        threadID = try values.flexibleString(forKey: .threadID).flatMap(Int64.init)
        postID = try values.flexibleString(forKey: .postID).flatMap(Int64.init)
        time = try values.flexibleString(forKey: .time).flatMap(Int64.init)
        isFloor = try values.flexibleString(forKey: .isFloor) == "1"
        title = try values.flexibleString(forKey: .title) ?? ""
        content = try values.flexibleString(forKey: .content) ?? ""
        quote = try values.flexibleString(forKey: .quote) ?? ""
        author = try values.decodeIfPresent(NotificationWireAuthor.self, forKey: .replyer) ?? .unknown
    }
}

private struct NotificationWirePage: Decodable {
    let currentPage: Int?
    let hasMore: Bool
    enum CodingKeys: String, CodingKey { case currentPage = "current_page", hasMore = "has_more" }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = try values.flexibleString(forKey: .currentPage).flatMap(Int.init)
        hasMore = try values.flexibleString(forKey: .hasMore) == "1"
    }
}

private struct NotificationWireCounts: Decodable {
    let value: NotificationCounts
    enum CodingKeys: String, CodingKey { case replyme, atme }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard let replies = try values.flexibleString(forKey: .replyme).flatMap(Int.init),
              let mentions = try values.flexibleString(forKey: .atme).flatMap(Int.init), replies >= 0, mentions >= 0
        else { throw EndpointExecutionError.mapping }
        value = .init(replies: replies, mentions: mentions)
    }
}

private struct NotificationWireAuthor: Decodable {
    let id: Int64
    let name: String
    let portrait: String?
    enum CodingKeys: String, CodingKey { case id, name, nameShow = "name_show", portrait }
    static let unknown = NotificationWireAuthor(id: 0, name: "未知用户", portrait: nil)
    private init(id: Int64, name: String, portrait: String?) { self.id = id; self.name = name; self.portrait = portrait }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.flexibleString(forKey: .id).flatMap(Int64.init) ?? 0
        let display = try values.flexibleString(forKey: .nameShow)
        let raw = try values.flexibleString(forKey: .name)
        name = [display, raw].compactMap { $0 }.first { !$0.isEmpty } ?? "未知用户"
        portrait = try values.flexibleString(forKey: .portrait)
    }
}
