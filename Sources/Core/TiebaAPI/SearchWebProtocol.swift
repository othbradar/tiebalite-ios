import Foundation

enum SearchWebProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case invalidStaticConfiguration
    case missingData
    case pageMismatch(expected: Int, actual: Int)
}

struct SearchWireInspection: Equatable, Sendable {
    let decoded: Bool
    let hasServerError: Bool
    let itemCount: Int
}

enum SearchWebProtocol {
    static let responseMIMEType = "application/json"
    static let defaultThreadSort = 5
    static let androidClientVersion = "12.35.1.0"

    private static let commonHeaders = [
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "User-Agent":
            "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Version/4.0 Chrome/135.0.0.0 " +
            "Mobile Safari/537.36 tieba/12.35.1.0 skin/default",
        "X-Requested-With": "com.baidu.tieba"
    ]

    static func makeForumDescriptor(
        host: String,
        keyword: SearchKeyword
    ) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("search.web.forum") else {
            throw SearchWebProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier,
            method: .get,
            host: host,
            path: "/mo/q/search/forum",
            queryItems: [
                EndpointField(name: "word", value: keyword.rawValue)
            ],
            fixedHeaders: commonHeaders,
            bodyCodec: .none,
            responseFamily: .json,
            allowedResponseMIMETypes: [responseMIMEType],
            authentication: .anonymous,
            timeout: 30,
            responseBodyLimit: 4 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func makeThreadDescriptor(
        host: String,
        request: SearchThreadPageRequest
    ) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("search.web.thread") else {
            throw SearchWebProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier,
            method: .get,
            host: host,
            path: "/mo/q/search/thread",
            queryItems: [
                EndpointField(name: "word", value: request.keyword.rawValue),
                EndpointField(name: "pn", value: String(request.page)),
                EndpointField(
                    name: "st",
                    value: String(defaultThreadSort)
                ),
                EndpointField(name: "tt", value: "1"),
                EndpointField(name: "ct", value: "1"),
                EndpointField(name: "is_use_zonghe", value: "1"),
                EndpointField(name: "cv", value: "99.9.101")
            ],
            fixedHeaders: commonHeaders,
            bodyCodec: .none,
            responseFamily: .json,
            allowedResponseMIMETypes: [responseMIMEType],
            authentication: .anonymous,
            timeout: 30,
            responseBodyLimit: 4 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func forumPipeline() -> EndpointPipeline<
        SearchForumEnvelope,
        [ForumSearchResult]
    > {
        EndpointPipeline(
            decode: decodeForum,
            map: mapForums
        )
    }

    static func threadPipeline(
        request: SearchThreadPageRequest
    ) -> EndpointPipeline<SearchThreadEnvelope, ThreadSearchPage> {
        EndpointPipeline(
            decode: decodeThread,
            map: { envelope in
                try mapThreads(envelope, request: request)
            }
        )
    }

    static func mapForumFixture(_ data: Data) throws -> [ForumSearchResult] {
        guard let keyword = SearchKeyword("fixture") else {
            throw SearchWebProtocolError.invalidStaticConfiguration
        }
        let endpoint = try makeForumDescriptor(
            host: "fixture.invalid",
            keyword: keyword
        )
        return try FixtureEndpointAdapter(
            endpoint: endpoint,
            pipeline: forumPipeline()
        ).map(data, mimeType: responseMIMEType)
    }

    static func mapThreadFixture(
        _ data: Data,
        keyword: SearchKeyword,
        requestedPage: Int
    ) throws -> ThreadSearchPage {
        guard let request = SearchThreadPageRequest(
            keyword: keyword,
            page: requestedPage
        ) else {
            throw SearchWebProtocolError.invalidStaticConfiguration
        }
        let endpoint = try makeThreadDescriptor(
            host: "fixture.invalid",
            request: request
        )
        return try FixtureEndpointAdapter(
            endpoint: endpoint,
            pipeline: threadPipeline(request: request)
        ).map(data, mimeType: responseMIMEType)
    }

    static func inspectForumForDiagnostics(
        _ data: Data
    ) -> SearchWireInspection {
        guard let envelope = try? JSONDecoder().decode(
            SearchForumEnvelope.self,
            from: data
        ) else {
            return SearchWireInspection(
                decoded: false,
                hasServerError: false,
                itemCount: 0
            )
        }
        return SearchWireInspection(
            decoded: true,
            hasServerError: (envelope.errorCode ?? 0) != 0,
            itemCount: envelope.data?.candidateCount ?? 0
        )
    }

    static func inspectThreadForDiagnostics(
        _ data: Data
    ) -> SearchWireInspection {
        guard let envelope = try? JSONDecoder().decode(
            SearchThreadEnvelope.self,
            from: data
        ) else {
            return SearchWireInspection(
                decoded: false,
                hasServerError: false,
                itemCount: 0
            )
        }
        return SearchWireInspection(
            decoded: true,
            hasServerError: (envelope.errorCode ?? 0) != 0,
            itemCount: envelope.data?.postList.count ?? 0
        )
    }

    private static func decodeForum(
        _ data: Data
    ) throws -> SearchForumEnvelope {
        guard !data.isEmpty else {
            throw SearchWebProtocolError.emptyBody
        }
        let envelope = try JSONDecoder().decode(
            SearchForumEnvelope.self,
            from: data
        )
        if let errorCode = envelope.errorCode, errorCode != 0 {
            throw EndpointWireFailure.server(code: errorCode)
        }
        return envelope
    }

    private static func decodeThread(
        _ data: Data
    ) throws -> SearchThreadEnvelope {
        guard !data.isEmpty else {
            throw SearchWebProtocolError.emptyBody
        }
        let envelope = try JSONDecoder().decode(
            SearchThreadEnvelope.self,
            from: data
        )
        if let errorCode = envelope.errorCode, errorCode != 0 {
            throw EndpointWireFailure.server(code: errorCode)
        }
        return envelope
    }

    private static func mapForums(
        _ envelope: SearchForumEnvelope
    ) throws -> [ForumSearchResult] {
        guard let data = envelope.data else {
            throw SearchWebProtocolError.missingData
        }
        var seenForumIDs: Set<Int64> = []
        return data.candidates.compactMap { candidate in
            guard let forumID = candidate.forumID,
                  forumID > 0,
                  seenForumIDs.insert(forumID).inserted,
                  let name = nonempty(candidate.forumName) else {
                return nil
            }
            return ForumSearchResult(
                forumID: forumID,
                name: name,
                displayName: nonempty(candidate.forumNameShow) ?? name,
                summary: nonempty(candidate.intro)
                    ?? nonempty(candidate.slogan),
                memberCountText: nonempty(candidate.concernCount),
                postCountText: nonempty(candidate.postCount)
            )
        }
    }

    private static func mapThreads(
        _ envelope: SearchThreadEnvelope,
        request: SearchThreadPageRequest
    ) throws -> ThreadSearchPage {
        guard let data = envelope.data else {
            throw SearchWebProtocolError.missingData
        }
        guard data.currentPage == request.page else {
            throw SearchWebProtocolError.pageMismatch(
                expected: request.page,
                actual: data.currentPage
            )
        }
        let items = data.postList.compactMap { item -> ThreadSearchResult? in
            guard let threadID = Int64(item.threadID), threadID > 0 else {
                return nil
            }
            let content = nonempty(item.content)
            let title = nonempty(item.title) ?? content ?? "无标题"
            let forumID = item.forumID.flatMap { value in
                value > 0 ? value : nil
            }
            let authorName = nonempty(item.user?.displayName)
                ?? nonempty(item.user?.userName)
                ?? "未知作者"
            return ThreadSearchResult(
                threadID: threadID,
                title: title,
                summary: content == title ? nil : content,
                forumID: forumID,
                forumName: nonempty(item.forumName) ?? "未知吧",
                authorName: authorName,
                replyCount: max(0, item.replyCount ?? 0)
            )
        }
        return ThreadSearchPage(
            items: items,
            currentPage: data.currentPage,
            hasMore: data.hasMore == 1
        )
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SearchForumEnvelope: Decodable, Sendable {
    let errorCode: Int?
    let errorMessage: String?
    let data: SearchForumData?

    private enum CodingKeys: String, CodingKey {
        case data
        case errorMessage = "error"
        case errorCode = "no"
    }
}

struct SearchForumData: Decodable, Sendable {
    let exactMatch: SearchForumExactMatch?
    let fuzzyMatch: SearchForumFuzzyMatch?

    var candidates: [SearchForumCandidate] {
        (exactMatch?.item.map { [$0] } ?? []) + (fuzzyMatch?.items ?? [])
    }

    var candidateCount: Int {
        candidates.count
    }
}

struct SearchForumExactMatch: Decodable, Sendable {
    let item: SearchForumCandidate?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let item = try? container.decode(SearchForumCandidate.self) {
            self.item = item
        } else {
            _ = try container.decode([SearchForumCandidate].self)
            item = nil
        }
    }
}

struct SearchForumFuzzyMatch: Decodable, Sendable {
    let items: [SearchForumCandidate]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([SearchForumCandidate].self) {
            items = array
        } else {
            let object = try container.decode(
                [String: SearchForumCandidate].self
            )
            items = object.keys.sorted().compactMap { object[$0] }
        }
    }
}

struct SearchForumCandidate: Decodable, Sendable {
    let forumID: Int64?
    let forumName: String?
    let forumNameShow: String?
    let postCount: String?
    let concernCount: String?
    let intro: String?
    let slogan: String?

    private enum CodingKeys: String, CodingKey {
        case concernCount = "concern_num"
        case forumID = "forum_id"
        case forumName = "forum_name"
        case forumNameShow = "forum_name_show"
        case intro
        case postCount = "post_num"
        case slogan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        forumID = try container.decodeIfPresent(
            Int64.self,
            forKey: .forumID
        )
        forumName = try container.decodeIfPresent(
            String.self,
            forKey: .forumName
        )
        forumNameShow = try container.decodeIfPresent(
            String.self,
            forKey: .forumNameShow
        )
        postCount = try container.decodeSearchCount(forKey: .postCount)
        concernCount = try container.decodeSearchCount(
            forKey: .concernCount
        )
        intro = try container.decodeIfPresent(String.self, forKey: .intro)
        slogan = try container.decodeIfPresent(String.self, forKey: .slogan)
    }
}

private extension KeyedDecodingContainer {
    func decodeSearchCount(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else {
            return nil
        }
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int64.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected a search count string or integer"
            )
        )
    }
}

struct SearchThreadEnvelope: Decodable, Sendable {
    let errorCode: Int?
    let errorMessage: String?
    let data: SearchThreadData?

    private enum CodingKeys: String, CodingKey {
        case data
        case errorMessage = "error"
        case errorCode = "no"
    }
}

struct SearchThreadData: Decodable, Sendable {
    let hasMore: Int
    let currentPage: Int
    let postList: [SearchThreadCandidate]

    private enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case hasMore = "has_more"
        case postList = "post_list"
    }
}

struct SearchThreadCandidate: Decodable, Sendable {
    let threadID: String
    let title: String?
    let content: String?
    let replyCount: Int?
    let forumID: Int64?
    let forumName: String?
    let user: SearchThreadUser?

    private enum CodingKeys: String, CodingKey {
        case content
        case forumID = "forum_id"
        case forumName = "forum_name"
        case replyCount = "post_num"
        case threadID = "tid"
        case title
        case user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        threadID = try container.decode(String.self, forKey: .threadID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        replyCount = try container.decodeSearchInt(forKey: .replyCount)
        forumID = try container.decodeSearchInt64(forKey: .forumID)
        forumName = try container.decodeIfPresent(
            String.self,
            forKey: .forumName
        )
        user = try container.decodeIfPresent(
            SearchThreadUser.self,
            forKey: .user
        )
    }
}

private extension KeyedDecodingContainer {
    func decodeSearchInt(forKey key: Key) throws -> Int? {
        guard let value = try decodeSearchInt64(forKey: key) else {
            return nil
        }
        return Int(exactly: value)
    }

    func decodeSearchInt64(forKey key: Key) throws -> Int64? {
        guard contains(key), try !decodeNil(forKey: key) else {
            return nil
        }
        if let value = try? decode(Int64.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key) {
            return Int64(value)
        }
        throw DecodingError.typeMismatch(
            Int64.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected a search integer or numeric string"
            )
        )
    }
}

struct SearchThreadUser: Decodable, Sendable {
    let userName: String?
    let displayName: String?

    private enum CodingKeys: String, CodingKey {
        case displayName = "show_nickname"
        case userName = "user_name"
    }
}
