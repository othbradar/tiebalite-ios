import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct Stage14PFRSPageTests {
    @Test
    func nextPageUsesEvidenceLockedPageAndLoadType() throws {
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let request = ForumHomePageRequest(route: route, pageNumber: 2)
        let bytes = try FRSPageProtocol.encodeRequest(request: request)
        let wire = try Tieba_FrsPage_FrsPageRequest(serializedBytes: bytes)

        #expect(wire.data.pn == 2)
        #expect(wire.data.loadType == 2)
        #expect(wire.data.kw == "Swift%E5%BC%80%E5%8F%91")
        #expect(!wire.data.common.hasBduss)
        #expect(!wire.data.common.hasStoken)
    }

    @Test
    func mapperDeduplicatesThreadIDAndMapsMediaKindsBeforePresentation() throws {
        let route = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        var response = try FRSPageProtocol.decode(frsFixtureData())
        var data = response.data
        var threads = data.threadList

        var duplicate = try #require(threads.first)
        duplicate.id = 99_999
        duplicate.title = "迟到的重复主题"
        threads.append(duplicate)

        var media = Tieba_Media()
        media.type = 3
        threads[2].media = [media]
        var video = Tieba_VideoInfo()
        video.videoMd5 = "fixture-video"
        threads[3].videoInfo = video
        data.threadList = threads
        var page = Tieba_Page()
        page.hasMore_p = 1
        data.page = page
        response.data = data

        let snapshot = try FRSPageProtocol.map(
            response,
            request: ForumHomePageRequest(route: route, pageNumber: 2)
        )
        let presentation = ForumHomeListPresentation(
            snapshot: snapshot,
            pagination: .idle
        )

        #expect(snapshot.threads.count == 4)
        #expect(snapshot.threads.map(\.threadID) == [
            140_001,
            140_002,
            140_003,
            140_004
        ])
        #expect(snapshot.currentPage == 2)
        #expect(snapshot.hasMore)
        #expect(presentation.threadRows[2].rowKind == .singleMedia)
        #expect(presentation.threadRows[3].rowKind == .video)
    }

    private func frsFixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("forum-home.frs-page.synthetic"),
            expectedFormat: .protobuf
        )
    }
}
