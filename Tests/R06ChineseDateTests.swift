import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct R06ChineseDateTests {
    @Test
    func postDatesAreChineseEvenWhenDeviceLanguageIsEnglish() throws {
        var response = Tieba_PbPage_PbPageResponse()
        response.data.thread.id = 42
        response.data.page.currentPage = 1
        response.data.firstFloorPost.id = 100
        response.data.firstFloorPost.floor = 1
        response.data.firstFloorPost.time = 1_789_880_340
        response.data.firstFloorPost.timeEx = "Sep 20, 2026 at 12:59 PM"
        let snapshot = try PBPageDomainMapper.map(response, request: .initial(threadID: 42))
        let metadata = try #require(snapshot.posts.first?.metadata)
        #expect(metadata.contains("年") && metadata.contains("月") && metadata.contains("日"))
        #expect(!metadata.contains("AM") && !metadata.contains("PM"))
    }

    @Test
    func chineseDateUsesGregorianCalendarAndKeepsTheLocalTimeZone() throws {
        let date = Date(timeIntervalSince1970: 1_789_880_340)
        let beijing = try #require(TimeZone(secondsFromGMT: 28_800))
        let utc = try #require(TimeZone(secondsFromGMT: 0))
        #expect(TiebaDateText.date(date, timeZone: beijing) == "2026年9月20日 12:59")
        #expect(TiebaDateText.date(date, timeZone: utc) == "2026年9月20日 4:59")
        #expect(TiebaDateText.date(date, includesTime: false, timeZone: beijing) == "2026年9月20日")
    }

    @Test
    func olderFeedDatesUseChineseCalendarLabels() {
        let timestamp: UInt32 = 1_789_880_340
        let now = Date(timeIntervalSince1970: Double(timestamp) + 864_000)
        for text in [ForumFeedText.time(timestamp, now: now),
                     RecommendationFeedText.relativeTime(timestamp, now: now)] {
            #expect(text?.contains("月") == true && text?.contains("日") == true)
        }
    }
}
