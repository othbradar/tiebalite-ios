import Foundation

struct ForumID: Codable, Hashable, Sendable {
    let rawValue: Int64

    init?(_ value: Int64) {
        guard value > 0 else {
            return nil
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid forum ID"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ForumName: Codable, Hashable, Sendable {
    static let maximumUTF8Length = 256

    let rawValue: String

    init?(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= Self.maximumUTF8Length,
              trimmed.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        rawValue = trimmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid forum name"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ForumRoute: Codable, Hashable, Sendable {
    let forumID: ForumID?
    let forumName: ForumName

    init?(forumID: Int64?, forumName: String) {
        guard let validatedName = ForumName(forumName) else {
            return nil
        }
        if let forumID {
            guard let validatedID = ForumID(forumID) else {
                return nil
            }
            self.forumID = validatedID
        } else {
            self.forumID = nil
        }
        self.forumName = validatedName
    }

    init?(_ forumName: String) {
        self.init(forumID: nil, forumName: forumName)
    }
}

struct ForumSummary: Equatable, Sendable {
    let forumID: Int64?
    let name: String
    let slogan: String?
    let avatarResourceID: String?
    let memberCount: Int
    let threadCount: Int
    let postCount: Int
}

struct ForumThreadSummary: Identifiable, Equatable, Sendable {
    let itemID: Int64
    let threadID: Int64
    let title: String
    let forumName: String
    let authorName: String
    let replyCount: Int32
    let viewCount: Int32
    let isPinned: Bool

    var id: Int64 {
        itemID
    }
}

struct ForumHomeSnapshot: Equatable, Sendable {
    let forum: ForumSummary
    let threads: [ForumThreadSummary]

    var pinnedThreads: [ForumThreadSummary] {
        threads.filter(\.isPinned)
    }

    var regularThreads: [ForumThreadSummary] {
        threads.filter { !$0.isPinned }
    }
}

protocol ForumHomeRepository: Sendable {
    func loadForumHome(route: ForumRoute) async throws -> ForumHomeSnapshot
}
