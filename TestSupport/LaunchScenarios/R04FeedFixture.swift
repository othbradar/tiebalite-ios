import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif

#if UITESTING || TEST_SUPPORT
/// Synthetic visual cases only; never installed in the production composition root.
struct R04FeedFixture: RecommendationRepository {
    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await loadPage(.initial).items
    }

    func loadPage(_ request: RecommendationPageRequest) async throws -> RecommendationRepositoryPage {
        let page = try await FixtureRecommendationRepository().loadPage(request)
        return RecommendationRepositoryPage(
            items: page.items.map { item in
                let count: Int = switch item.threadID {
                case 100_002: 1
                case 100_003: 8
                case 100_010: 2
                default: 0
                }
                let resources = (0..<count).map { index in
                    ImageResourceDescriptor(resourceID: "r04.t\(item.threadID).media.\(index)")
                }
                return RecommendationSummary(
                    threadID: item.threadID, title: item.title, forumName: item.forumName,
                    authorName: item.authorName, replyCount: item.replyCount, thumbnail: nil,
                    author: TiebaUserVisuals(
                        rawUserID: item.threadID, displayName: item.authorName,
                        portrait: "r04.fixture.\(item.threadID)", levelID: 8
                    ),
                    forumAvatarResource: ImageResourceDescriptor(resourceID: "r04.forum"),
                    feed: RecommendationFeedDetails(
                        abstractText: item.threadID == 100_004
                            ? String(repeating: "这是完整保留而按五行显示的固定长摘要。", count: 12) : "",
                        showsTitle: true, timeUnixSeconds: 1_700_000_000,
                        media: resources, totalMediaCount: count, agreeCount: 46, shareCount: 1
                    )
                )
            },
            requestedPage: page.requestedPage, nextPageCandidate: page.nextPageCandidate
        )
    }
}

struct R04FeedFixtureImages: ImageLoading {
    private let loader: HarnessMixedSizeImageLoader

    @MainActor
    init() {
        loader = HarnessMixedSizeImageLoader()
    }

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        if request.resourceID == "user.100009.avatar" { throw ImageLoadingError.unavailable }
        let ordinal = Int(request.resourceID.split(separator: ".").last ?? "") ?? 0
        let samples = [FixtureReadingImageResource.blue, FixtureReadingImageResource.orange, FixtureReadingImageResource.green]
        return try await loader.load(ImageRequest(
            resourceID: samples[ordinal % samples.count],
            targetPixelSize: request.targetPixelSize, purpose: request.purpose, resizeMode: request.resizeMode
        ))
    }
}
#endif
