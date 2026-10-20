struct SearchThreadMedia: Decodable, Sendable {
    let type: String?
    let smallPicture: String?
    let bigPicture: String?
    let waterPicture: String?
    private enum CodingKeys: String, CodingKey {
        case type
        case smallPicture = "small_pic"
        case bigPicture = "big_pic"
        case waterPicture = "water_pic"
    }
}

extension SearchThreadCandidate {
    var quotes: [SearchQuotedPost] {
        guard destinationPostID != nil else { return [] }
        let sources = type == 3 ? [postInfo, mainPost] : [mainPost]
        return sources.compactMap { source in
            guard let source else { return nil }
            let text = [source.title, source.content].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            guard !text.isEmpty else { return nil }
            return SearchQuotedPost(authorName: source.user?.displayName ?? source.user?.userName ?? "",
                                    text: text)
        }
    }

    var thumbnails: [ImageResourceDescriptor] {
        Array((media ?? []).prefix(3).enumerated().compactMap { index, image in
            guard image.type == "pic" else { return nil }
            return ThreadListImageResourceMapper.map(
                bigPicture: image.bigPicture ?? "", dynamicPicture: "", sourcePicture: image.smallPicture ?? "",
                originalPicture: image.waterPicture ?? "", ownerResourceID: "search.\(threadID).\(postID ?? 0).\(index)")
        })
    }
}

struct SearchThreadPostInfo: Decodable, Sendable {
    let postID: Int64?
    let title: String?
    let content: String?
    let user: SearchThreadUser?
    private enum CodingKeys: String, CodingKey { case postID = "pid", title, content, user }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postID = try container.decodeSearchInt64(forKey: .postID)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        user = try container.decodeIfPresent(SearchThreadUser.self, forKey: .user)
    }
}
