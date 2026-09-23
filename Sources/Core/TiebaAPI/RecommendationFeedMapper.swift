import Foundation
import GeneratedProtobuf

/// Android UI c5f1125 FeedCard and Extensions.abstractText; wire schema stays pinned.
enum RecommendationFeedMapper {
    static func map(_ thread: Tieba_ThreadInfo, ownerThreadID: Int64) -> RecommendationFeedDetails {
        let media = thread.media.enumerated().compactMap { index, media in
            ThreadListImageResourceMapper.map(
                bigPicture: media.bigPic,
                dynamicPicture: media.dynamicPic,
                sourcePicture: media.srcPic,
                originalPicture: media.originPic,
                ownerResourceID: "recommendation.t\(ownerThreadID).media.\(index + 1)"
            )
        }
        return RecommendationFeedDetails(
            abstractText: abstractText(thread),
            showsTitle: thread.isNoTitle != 1 && !thread.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            timeUnixSeconds: thread.lastTimeInt > 0 ? UInt32(thread.lastTimeInt) : nil,
            media: media,
            totalMediaCount: thread.media.count,
            agreeCount: thread.agreeNum > 0 ? Int64(thread.agreeNum) : nil,
            shareCount: thread.shareNum > 0 ? thread.shareNum : nil
        )
    }

    private static func abstractText(_ thread: Tieba_ThreadInfo) -> String {
        if !thread.richAbstract.isEmpty {
            return thread.richAbstract.map { content in
                switch content.type {
                case 0, 40: compactSpaces(content.text)
                case 2: content.c.isEmpty ? "" : "#(\(content.c))"
                default: ""
                }
            }.joined()
        }
        return thread.abstract.map { content in
            switch content.type {
            case 0: compactSpaces(content.text)
            case 4: content.text
            default: ""
            }
        }.joined()
    }

    private static func compactSpaces(_ value: String) -> String {
        value.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    }
}
