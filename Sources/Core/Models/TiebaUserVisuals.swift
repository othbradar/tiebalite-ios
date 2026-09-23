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
        httpsResource(id: "user.\(userID).avatar", value: portrait)
    }

    static func forum(forumID: Int64?, avatar: String?) -> ImageResourceDescriptor? {
        httpsResource(id: "forum.\(forumID ?? 0).avatar", value: avatar)
    }

    private static func httpsResource(id: String, value: String?) -> ImageResourceDescriptor? {
        guard let value else { return nil }
        // Android accepts complete URLs unchanged. Bare portrait only has an
        // HTTP synthesis rule: preserve it in the model, never guess HTTPS.
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
