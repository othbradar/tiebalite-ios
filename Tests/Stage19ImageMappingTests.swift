import GeneratedProtobuf
import Testing
@testable import TiebaLite

@Suite("Stage 19A image candidate mapping")
struct Stage19ImageMappingTests {
    @Test
    func threadListMediaUsesEvidenceOrderHTTPSFilteringAndStableIdentity() {
        var media = Tieba_Media()
        media.bigPic = "https://images.fixture.invalid/big.jpg"
        media.dynamicPic = "https://images.fixture.invalid/dynamic.gif"
        media.srcPic = "http://images.fixture.invalid/insecure.jpg"
        media.originPic = "https://images.fixture.invalid/origin.jpg"

        let resource = ThreadListImageResourceMapper.map(
            bigPicture: media.bigPic,
            dynamicPicture: media.dynamicPic,
            sourcePicture: media.srcPic,
            originalPicture: media.originPic,
            ownerResourceID: "recommendation.t1001.media.1"
        )

        #expect(resource?.resourceID == "recommendation.t1001.media.1")
        #expect(resource?.candidateURLs == [
            "https://images.fixture.invalid/big.jpg",
            "https://images.fixture.invalid/dynamic.gif",
            "https://images.fixture.invalid/origin.jpg"
        ])
    }

    @Test
    func personalizedMapperPreservesFirstLoadableThumbnail() throws {
        var media = Tieba_Media()
        media.bigPic = "https://images.fixture.invalid/recommendation-big.jpg"
        media.srcPic = "https://images.fixture.invalid/recommendation-src.jpg"
        var thread = Tieba_ThreadInfo()
        thread.id = 1_001
        thread.threadID = 1_001
        thread.title = "Fixture"
        thread.forumName = "Fixture吧"
        thread.media = [media]
        var data = Tieba_PersonalizedResponseData()
        data.threadList = [thread]
        var response = Tieba_PersonalizedResponse()
        response.data = data

        let page = try PersonalizedProtocol.map(response, requestedPage: 1)
        let thumbnail = try #require(page.items.first?.thumbnailResource)

        #expect(thumbnail.resourceID == "recommendation.t1001.media.1")
        #expect(thumbnail.candidateURLs == [
            "https://images.fixture.invalid/recommendation-big.jpg",
            "https://images.fixture.invalid/recommendation-src.jpg"
        ])
    }

    @Test
    func threadPreviewAndViewerUseDifferentEvidenceBackedCandidateOrder() {
        let descriptor = ThreadImageRequestDescriptor(
            resourceID: "t9001.p9101.spost.n2",
            candidates: [
                candidate(.original, "origin"),
                candidate(.bigCDN, "big-cdn"),
                candidate(.big, "big"),
                candidate(.dynamic, "dynamic"),
                candidate(.cdn, "cdn"),
                candidate(.activeCDN, "active"),
                candidate(.source, "source")
            ]
        )
        let target = ImageTargetPixelSize(width: 600, height: 900)

        let preview = descriptor.imageRequest(
            purpose: .threadContent,
            targetPixelSize: target
        )
        let viewer = descriptor.imageRequest(
            purpose: .mediaViewer,
            targetPixelSize: target
        )

        #expect(preview.candidateURLs.map(lastPathComponent) == [
            "big-cdn", "big", "dynamic", "cdn", "active", "source", "origin"
        ])
        #expect(viewer.candidateURLs.map(lastPathComponent) == [
            "origin", "big-cdn", "big", "dynamic", "cdn", "active", "source"
        ])
        #expect(preview.purpose == .threadContent)
        #expect(viewer.purpose == .mediaViewer)
    }

    @Test
    func forumRowRetainsActualResourcesWithoutChangingThreadIdentity() {
        let resources = [
            ImageResourceDescriptor(
                resourceID: "forum.t2001.media.1",
                candidateURLs: ["https://images.fixture.invalid/one.jpg"]
            ),
            ImageResourceDescriptor(
                resourceID: "forum.t2001.media.2",
                candidateURLs: ["https://images.fixture.invalid/two.jpg"]
            )
        ]
        let summary = ForumThreadSummary(
            itemID: 1_901,
            threadID: 2_001,
            title: "Fixture",
            forumName: "Fixture吧",
            authorName: "作者",
            replyCount: 3,
            viewCount: 9,
            isPinned: false,
            mediaCount: 2,
            thumbnailResources: resources
        )

        let row = ForumThreadRowModel(thread: summary, forumID: 88)

        #expect(row.threadID == 2_001)
        #expect(row.thumbnailDescriptions.map(\.resource) == resources)
        #expect(row.sourceSummary.thumbnailResources == resources)
    }

    private func candidate(
        _ role: ThreadImageCandidateRole,
        _ path: String
    ) -> ThreadImageCandidate {
        ThreadImageCandidate(
            role: role,
            destination: ValidatedWebDestination(
                absoluteString: "https://images.fixture.invalid/\(path)",
                scheme: .https
            )
        )
    }

    private func lastPathComponent(_ rawValue: String) -> String {
        rawValue.split(separator: "/").last.map(String.init) ?? ""
    }
}
