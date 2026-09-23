#if DEBUG
import Foundation
import UIKit

/// Synthetic public display data, reachable only through a debug flag or isolated UI scenario.
struct R06ThreadFixtureRepository: ThreadReaderRepository {
    func loadPage(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot {
        try Task.checkCancellation()
        let posts = [4, 5, 1, 2, 3, 8].enumerated().map {
            Self.post(threadID: request.threadID, floor: $0.offset + 1, imageCount: $0.element)
        }
        return ThreadReaderSnapshot(
            threadID: request.threadID, title: "R06 固定样本 · 多图与楼中楼", forumName: "组件验收",
            forumAvatarResource: .init(resourceID: "r06.image.0", candidateURLs: ["https://fixture.invalid/forum"]),
            author: posts[0].author, replyCount: 5, posts: posts,
            currentPage: 1, totalPage: 1, hasMore: false, nextPostID: nil
        )
    }

    static func post(threadID: Int64, floor: Int, imageCount: Int) -> ThreadReaderPost {
        let source = ThreadContentSource(threadID: threadID, postID: Int64(60_000 + floor),
                                         scope: floor == 1 ? .firstPost : .post)
        var nodes = [ThreadContentNode(
            id: .init(source: source, ordinal: 0), rawType: 0,
            payload: .text(.init(value: "\(imageCount) 张图片 · 按原比例紧凑排列"))
        )]
        nodes += (0..<imageCount).map { index in
            let id = ThreadContentNodeID(source: source, ordinal: index + 1)
            return ThreadContentNode(id: id, rawType: 3, payload: .image(.init(
                rawType: 3, mediaID: .init(sourceNodeID: id),
                request: .init(resourceID: "r06.image.\(index)", candidates: [
                    .init(role: .source, destination: .init(
                        absoluteString: "https://fixture.invalid/r06/\(index)", scheme: .https
                    ))
                ]),
                dimensions: .known(width: index.isMultiple(of: 2) ? 1_200 : 900, height: 800),
                alternativeText: "固定图片 \(index + 1)", originalByteCount: nil, showsOriginalControlHint: false
            )))
        }
        let replies = (0..<(floor == 1 ? 5 : 3)).map { index in
            Self.subpost(source: source, index: index)
        }
        return ThreadReaderPost(
            floorNumber: floor,
            author: .init(rawUserID: Int64(floor), displayName: floor == 1 ? "固定楼主" : "读者\(floor)",
                          portrait: "https://fixture.invalid/avatar/\(floor)",
                          levelID: [14, 8, 18, 1, 14, 8][floor - 1],
                          isBawu: floor == 3, bawuType: floor == 3 ? "manager" : nil, ipLocation: "辽宁"),
            metadata: "今天 16:35", document: .init(source: source, availability: .available, nodes: nodes, poll: nil),
            subposts: replies, subpostTotal: floor == 1 ? 7 : 3, agreeCount: 12
        )
    }

    private static func subpost(source: ThreadContentSource, index: Int) -> ThreadReaderSubpost {
        let replySource = ThreadContentSource(
            threadID: source.threadID, postID: source.postID * 10 + Int64(index), scope: .subPost
        )
        let node = ThreadContentNode(
            id: .init(source: replySource, ordinal: 0), rawType: 0,
            payload: .text(.init(value: "服务端顺序中的第 \(index + 1) 条回复。"))
        )
        return ThreadReaderSubpost(
            parentPostID: source.postID,
            author: .init(rawUserID: Int64(80 + index), displayName: "回复者\(index + 1)", levelID: 8),
            metadata: "今天 16:36",
            document: .init(source: replySource, availability: .available, nodes: [node], poll: nil)
        )
    }

}

struct R06ThreadFixtureImages: ImageLoading {
    private let loader: ProductionImageLoader

    @MainActor
    init() {
        loader = Self.sharedLoader
    }

    @MainActor
    private static let sharedLoader: ProductionImageLoader = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let samples = Dictionary(uniqueKeysWithValues: (0..<8).map { index in
            let size = CGSize(width: index.isMultiple(of: 2) ? 360 : 270, height: 240)
            let data = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
                let colors: [UIColor] = [.systemTeal, .systemOrange, .systemIndigo, .systemGreen]
                colors[index % colors.count].setFill()
                context.fill(CGRect(origin: .zero, size: size))
                let label = "R06 • \(index + 1)" as NSString
                label.draw(at: CGPoint(x: 20, y: 92), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 40), .foregroundColor: UIColor.white
                ])
            }
            return ("r06.image.\(index)", data)
        })
        return ProductionImageLoader(loader: R06FixtureImageTransport(images: samples))
    }()

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        let resource = request.resourceID.hasPrefix("user.") ? "r06.image.0" : request.resourceID
        return try await loader.load(ImageRequest(
            resourceID: resource, candidateURLs: ["https://r06.fixture.invalid/\(resource)"],
            targetPixelSize: request.targetPixelSize, purpose: request.purpose, resizeMode: request.resizeMode
        ))
    }
}

private struct R06FixtureImageTransport: HTTPDataLoading {
    let images: [String: Data]

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = request.url, url.host == "r06.fixture.invalid",
              let data = images[url.lastPathComponent], data.count <= maximumByteCount,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "image/png"]) else {
            throw ImageLoadingError.missingFixture
        }
        return (data, response)
    }
}
#endif
