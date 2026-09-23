import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct R04FeedMappingTests {
    @Test
    func feedKeepsAllMediaOriginalOrdinalsAndAndroidDisplayFields() throws {
        var thread = Tieba_ThreadInfo()
        thread.id = 101
        thread.threadID = 201
        thread.title = "标题"
        thread.isNoTitle = 1
        thread.lastTimeInt = 1_700_000_000
        thread.createTime = 1_600_000_000
        thread.shareNum = 12
        thread.agreeNum = 34
        var text = Tieba_PbContent()
        text.type = 0
        text.text = "正文  摘要"
        var mention = Tieba_PbContent()
        mention.type = 40
        mention.text = "@用户"
        var image = Tieba_PbContent()
        image.type = 3
        image.text = "https://fixture.invalid/not-text.jpg"
        thread.richAbstract = [text, image, mention]
        thread.media = (0..<8).map { index in
            var media = Tieba_Media()
            if index != 1 {
                media.bigPic = "https://images.fixture.invalid/\(index)-big.jpg"
                media.originPic = "https://images.fixture.invalid/\(index)-original.jpg"
            }
            return media
        }
        var response = Tieba_PersonalizedResponse()
        response.data.threadList = [thread]
        let item = try #require(PersonalizedProtocol.map(response, requestedPage: 2).items.first)
        #expect(item.rawFeedID == 101)
        #expect(item.rawThreadID == 201)
        #expect(item.feed.abstractText == "正文 摘要@用户")
        #expect(!item.feed.showsTitle)
        #expect(item.feed.timeUnixSeconds == 1_700_000_000)
        #expect(item.feed.shareCount == 12)
        #expect(item.feed.agreeCount == 34)
        #expect(item.feed.totalMediaCount == 8)
        #expect(item.feed.media.count == 7)
        #expect(item.feed.media[1].resourceID == "recommendation.t201.media.3")
        #expect(item.feed.media[1].candidateURLs == [
            "https://images.fixture.invalid/2-big.jpg", "https://images.fixture.invalid/2-original.jpg"
        ])
        #expect(item.thumbnailResource == item.feed.media.first)
    }

    @Test
    func missingTimeCountsAndContentStayAbsentAndLegacyTextRemainsReadable() throws {
        var thread = Tieba_ThreadInfo()
        thread.id = 102
        thread.lastTimeInt = -1
        thread.agreeNum = -3
        thread.shareNum = -4
        var text = Tieba_Abstract()
        text.type = 0
        text.text = "旧  摘要"
        var link = Tieba_Abstract()
        link.type = 4
        link.text = "链接文字"
        var unknown = Tieba_Abstract()
        unknown.type = 99
        unknown.text = "不应展示"
        thread.abstract = [text, link, unknown]
        var response = Tieba_PersonalizedResponse()
        response.data.threadList = [thread]
        let feed = try #require(PersonalizedProtocol.map(response, requestedPage: 1).items.first?.feed)
        #expect(feed.abstractText == "旧 摘要链接文字")
        #expect(feed.timeUnixSeconds == nil)
        #expect(feed.agreeCount == nil)
        #expect(feed.shareCount == nil)
        #expect(feed.media.isEmpty)
        #expect(!feed.showsTitle)
    }

    @Test
    func summaryKeepsCompleteMediaAndLegacyThumbnailWithoutChangingID() {
        let resources = (1...8).map { ImageResourceDescriptor(resourceID: "fixture.\($0)") }
        let item = RecommendationSummary(
            threadID: 101, title: "样本", forumName: "样本吧", authorName: "作者", replyCount: 4,
            thumbnail: nil, feed: RecommendationFeedDetails(media: resources, totalMediaCount: 8)
        )
        #expect(item.id == 101)
        #expect(item.mediaResources == resources)
        #expect(item.previewMediaResources == Array(resources.prefix(3)))
        #expect(item.mediaCount == 8)
        let legacy = RecommendationSummary(
            threadID: 102, title: "旧样本", forumName: "样本吧", authorName: "作者", replyCount: 0,
            thumbnail: RecommendationThumbnail(resource: resources[0], alternativeText: "样本")
        )
        #expect(legacy.mediaResources == [resources[0]])
        #expect(legacy.mediaCount == 1)
    }

    @Test
    func relativeTimeUsesAnInjectedClockAndNoFakeTimestamp() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(RecommendationFeedText.relativeTime(nil, now: now) == nil)
        #expect(RecommendationFeedText.relativeTime(1_699_998_260, now: now) == "29 分钟前")
        #expect(RecommendationFeedText.relativeTime(1_699_992_800, now: now) == "2 小时前")
        #expect(RecommendationFeedText.relativeTime(1_700_000_030, now: now) == "刚刚")
    }
}
