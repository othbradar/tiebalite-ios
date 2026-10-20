import Foundation

/// Read-only Hybrid contract: AppHybridTiebaApi.searchUserFlow and SearchUserBean/adapters.
enum SearchUserWebProtocol {
    static func makeDescriptor(host: String, keyword: SearchKeyword) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("search.web.user") else {
            throw SearchWebProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier, method: .get, host: host, path: "/mo/q/search/user",
            queryItems: [EndpointField(name: "word", value: keyword.rawValue)],
            fixedHeaders: SearchWebProtocol.commonHeaders, bodyCodec: .none, responseFamily: .json,
            allowedResponseMIMETypes: [SearchWebProtocol.responseMIMEType], authentication: .anonymous,
            timeout: 30, responseBodyLimit: 4 * 1_024 * 1_024, redirectPolicy: .reject, retryPolicy: .never
        )
    }

    static func pipeline() -> EndpointPipeline<SearchUserEnvelope, [UserSearchResult]> {
        EndpointPipeline(decode: { data in
            guard !data.isEmpty else { throw SearchWebProtocolError.emptyBody }
            let envelope = try JSONDecoder().decode(SearchUserEnvelope.self, from: data)
            if let code = envelope.no, code != 0 { throw EndpointWireFailure.server(code: code) }
            return envelope
        }, map: { envelope in
            guard let data = envelope.data else { throw SearchWebProtocolError.missingData }
            let exact = data.exactMatch?.item
            let candidates = (exact.map { [$0] } ?? []) + (data.fuzzyMatch?.items ?? [])
            var seen: Set<Int64> = []
            return candidates.compactMap { candidate in
                guard let identifier = candidate.id.flatMap(Int64.init), identifier > 0,
                      seen.insert(identifier).inserted,
                      let route = UserProfileRoute(userID: identifier,
                                                   fallbackDisplayName: nonempty(candidate.showNickname)
                                                       ?? nonempty(candidate.name) ?? "未知用户",
                                                   portraitResourceID: candidate.portrait) else { return nil }
                return UserSearchResult(route: route, introduction: nonempty(candidate.intro),
                                        isExactMatch: exact?.id.flatMap(Int64.init) == identifier)
            }
        })
    }

    static func mapFixture(_ data: Data) throws -> [UserSearchResult] {
        guard let keyword = SearchKeyword("fixture") else { throw SearchWebProtocolError.invalidStaticConfiguration }
        return try FixtureEndpointAdapter(endpoint: makeDescriptor(host: "fixture.invalid", keyword: keyword),
                                          pipeline: pipeline()).map(data, mimeType: SearchWebProtocol.responseMIMEType)
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

struct SearchUserEnvelope: Decodable, Sendable {
    let no: Int?
    let data: SearchUserData?
}

struct SearchUserData: Decodable, Sendable {
    let exactMatch: SearchUserExactMatch?
    let fuzzyMatch: SearchUserFuzzyMatch?
}

struct SearchUserExactMatch: Decodable, Sendable {
    let item: SearchUserCandidate?

    init(from decoder: Decoder) throws {
        if (try? decoder.unkeyedContainer()) != nil {
            item = nil
        } else {
            item = try SearchUserCandidate(from: decoder)
        }
    }
}

struct SearchUserFuzzyMatch: Decodable, Sendable {
    let items: [SearchUserCandidate]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([SearchUserObject].self) {
            items = array.compactMap(\.item)
        } else {
            let object = try container.decode([String: SearchUserObject].self)
            items = object.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.compactMap { object[$0]?.item }
        }
    }
}

/// The reference skips non-object fuzzy members, but malformed fields in a user still fail decoding.
private struct SearchUserObject: Decodable, Sendable {
    let item: SearchUserCandidate?

    init(from decoder: Decoder) throws {
        if (try? decoder.container(keyedBy: SearchUserCandidate.CodingKeys.self)) != nil {
            item = try SearchUserCandidate(from: decoder)
        } else {
            item = nil
        }
    }
}

struct SearchUserCandidate: Decodable, Sendable {
    let id: String?
    let name: String?
    let showNickname: String?
    let intro: String?
    let portrait: String?

    enum CodingKeys: String, CodingKey {
        case id, name, intro, portrait
        case showNickname = "show_nickname"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? container.decode(Int64.self, forKey: .id) {
            id = String(number)
        } else {
            id = try container.decodeIfPresent(String.self, forKey: .id)
        }
        name = try container.decodeIfPresent(String.self, forKey: .name)
        showNickname = try container.decodeIfPresent(String.self, forKey: .showNickname)
        intro = try container.decodeIfPresent(String.self, forKey: .intro)
        portrait = try container.decodeIfPresent(String.self, forKey: .portrait)
    }
}
