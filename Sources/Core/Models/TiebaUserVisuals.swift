import Foundation

/// Public display fields only. Identity belongs to the existing business model.
struct TiebaUserVisuals: Equatable, Sendable {
    let rawUserID: Int64
    let displayName: String
    let portrait: String?
    let levelID: Int?
    let isBawu: Bool
    let bawuType: String?

    init(
        rawUserID: Int64,
        displayName: String,
        portrait: String? = nil,
        levelID: Int? = nil,
        isBawu: Bool = false,
        bawuType: String? = nil
    ) {
        self.rawUserID = rawUserID
        self.displayName = displayName
        self.portrait = portrait
        self.levelID = levelID.flatMap { $0 > 0 ? $0 : nil }
        self.isBawu = isBawu
        self.bawuType = bawuType
    }

    var avatarResource: ImageResourceDescriptor? {
        TiebaAvatarResource.user(userID: rawUserID, portrait: portrait)
    }

    var moderatorLabel: String? {
        isBawu ? (bawuType == "manager" ? "吧主" : "小吧主") : nil
    }

    func isThreadAuthor(_ threadAuthorID: Int64) -> Bool {
        rawUserID > 0 && threadAuthorID > 0 && rawUserID == threadAuthorID
    }
}

enum TiebaAvatarResource {
    static func user(userID: Int64, portrait: String?) -> ImageResourceDescriptor? {
        imageResource(id: "user.\(userID).avatar", value: portrait.flatMap(LegacyPortraitURL.candidate))
    }

    static func forum(forumID: Int64?, avatar: String?) -> ImageResourceDescriptor? {
        imageResource(id: "forum.\(forumID ?? 0).avatar", value: forumHTTPSCandidate(avatar))
    }

    private static func forumHTTPSCandidate(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URLComponents(string: trimmed), url.scheme?.lowercased() == "http" else {
            return value
        }
        // R03 runtime evidence: the same ForumGuide CDN resource supports TLS.
        // Preserve the API's complete path/query; never synthesize a portrait URL.
        let host = url.host?.lowercased()
        let verifiedCDN = (host == "tiebapic.baidu.com" && url.path.hasPrefix("/forum/w=120;h=120/"))
            || (host == "imgsrc.baidu.com" && url.path.hasPrefix("/forum/pic/"))
        guard verifiedCDN,
              url.user == nil, url.password == nil, url.port == nil, url.fragment == nil else { return nil }
        return "https:" + trimmed.dropFirst(5)
    }

    private static func imageResource(id: String, value: String?) -> ImageResourceDescriptor? {
        guard let value else { return nil }
        let resource = ImageResourceDescriptor(resourceID: id, candidateURLs: [value])
        return resource.isNetworkLoadable ? resource : nil
    }
}

extension ForumSummary {
    var avatarResource: ImageResourceDescriptor? {
        TiebaAvatarResource.forum(forumID: forumID, avatar: avatarResourceID)
    }
}

extension UserProfile {
    var avatarResource: ImageResourceDescriptor? {
        TiebaAvatarResource.user(userID: userID.rawValue, portrait: portraitResourceID)
    }
}
