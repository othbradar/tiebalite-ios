import Foundation

#if TEST_SUPPORT
@testable import TiebaLite
#endif
import UIKit

#if UITESTING || TEST_SUPPORT
/// Deterministic non-square bitmaps exercise intrinsic image sizing that 1x1 fixtures miss.
struct HarnessMixedSizeImageLoader: ImageLoading {
    private let loader: ProductionImageLoader

    private struct Sample {
        let resource: String
        let size: CGSize
        let color: UIColor
    }

    @MainActor
    init() {
        let samples = [
            Sample(resource: FixtureReadingImageResource.blue,
                   size: CGSize(width: 800, height: 1200), color: .systemBlue),
            Sample(resource: FixtureReadingImageResource.orange,
                   size: CGSize(width: 1200, height: 600), color: .systemOrange),
            Sample(resource: FixtureReadingImageResource.green,
                   size: CGSize(width: 450, height: 600), color: .systemGreen)
        ]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let images = Dictionary(uniqueKeysWithValues: samples.map { sample in
            let data = UIGraphicsImageRenderer(size: sample.size, format: format).pngData { context in
                sample.color.setFill()
                context.fill(CGRect(origin: .zero, size: sample.size))
            }
            return (sample.resource, data)
        })
        loader = ProductionImageLoader(loader: HarnessMixedMediaTransport(images: images))
    }

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        try await loader.load(ImageRequest(
            resourceID: request.resourceID,
            candidateURLs: ["https://root.fixture.invalid/\(request.resourceID)"],
            targetPixelSize: request.targetPixelSize,
            purpose: request.purpose,
            resizeMode: request.resizeMode
        ))
    }
}

private struct HarnessMixedMediaTransport: HTTPDataLoading {
    let images: [String: Data]

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = request.url, url.host == "root.fixture.invalid",
              let data = images[url.lastPathComponent], data.count <= maximumByteCount,
              let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
              ) else {
            throw ImageLoadingError.unavailable
        }
        return (data, response)
    }
}

struct HarnessMixedMetadataRecommendations: RecommendationRepository {
    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await loadPage(.initial).items
    }

    func loadPage(_ request: RecommendationPageRequest) async throws -> RecommendationRepositoryPage {
        let page = try await FixtureRecommendationRepository().loadPage(request)
        return RecommendationRepositoryPage(
            items: page.items.map { item in
                RecommendationSummary(
                    threadID: item.threadID,
                    title: item.title,
                    forumName: item.threadID.isMultiple(of: 2) ? "固定长名称排版测试讨论区" : item.forumName,
                    authorName: item.threadID.isMultiple(of: 3)
                        ? "固定排版测试用户_LongName123456" : item.authorName,
                    replyCount: item.threadID.isMultiple(of: 2) ? 123_456 : item.replyCount,
                    thumbnail: item.thumbnail
                )
            },
            requestedPage: page.requestedPage,
            nextPageCandidate: page.nextPageCandidate
        )
    }
}
#endif
