import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct ThreadScrollFluencyTests {
        @Test(arguments: ["plain", "previews", "images", "gif"])
        func warmedFixedStepWindow(kind: String) async throws {
            let repository = Stage15LongThreadFixtureRepository(threadID: 990_015, totalPostCount: 80, pageSize: 80)
            let snapshot = try await repository.loadPage(.init(threadID: 990_015, pageNumber: 0, postID: 0))
            let rows = snapshot.posts.map { post -> ThreadReaderConfiguredRow in
                let text = ThreadContentNode(id: .init(source: post.id, ordinal: 0), rawType: 0,
                                             payload: .text(.init(value: String(repeating: "固定慢滑样本 #滑稽 正文。", count: 12))))
                let subposts = (1...3).map { index in
                    let source = ThreadContentSource(threadID: post.id.threadID, postID: post.id.postID + Int64(index), scope: .subPost)
                    return ThreadReaderSubpost(
                        parentPostID: post.id.postID, author: .init(rawUserID: Int64(index), displayName: "作者\(index)"),
                        replyToDisplayName: "引用作者", metadata: "10-23", document: .init(
                            source: source, availability: .available,
                            nodes: [.init(id: .init(source: source, ordinal: 0), rawType: 0,
                                          payload: .text(.init(value: String(repeating: "楼中楼预览 #滑稽 内容。", count: 8))))], poll: nil))
                }
                let imageNodes = ["images", "gif"].contains(kind) ? snapshot.posts[36].document.nodes.filter {
                    if case .image = $0.payload { return true }; return false
                } : []
                let model = ThreadReaderPostRowModel(.init(
                    floorNumber: post.floorNumber, author: post.author, metadata: "10-23",
                    document: .init(source: post.id, availability: .available, nodes: [text] + imageNodes, poll: nil),
                    subposts: kind == "plain" ? [] : subposts))
                return .init(row: .init(id: .post(threadID: post.id.threadID, postID: post.id.postID), content: .post(model)),
                             readingTextSize: .standard)
            }
            let image = try #require(UIImage(data: TestImageFixtureFactory.png(width: 64, height: 48)))
            let gifURL = try #require(Bundle(for: SFFrameMarker.self).resourceURL?.appendingPathComponent("Fixtures/Media/bounded.gif"))
            let animation = kind == "gif" ? AnimatedImageResource.inspect(data: try Data(contentsOf: gifURL)) : nil
            let loader = HarnessCapturingImageLoader(payload: .init(
                decodedImage: image, mediaType: "image/png",
                pixelSize: .init(width: 64, height: 48), animation: animation))
            let list = VirtualizedList(items: rows, backgroundColor: .systemBackground,
                                       accessibilityIdentifier: "sf.window", contentVersion: 1) { configured in
                ThreadReaderRowView(
                    row: configured.row, imageLoader: loader, readingTextSize: .standard,
                    onOpenMedia: { _ in }, onOpenUser: { _ in }, onOpenSubposts: { _ in },
                    onOpenExternalLink: { _ in }, requestNextPage: {})
                    .environment(\.scenePhase, .active)
            }
            let coordinator = list.makeCoordinator()
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.frame = scene.coordinateSpace.bounds
            let controller = UIViewController(); window.rootViewController = controller
            let table = VirtualizedTableView(frame: .init(x: 0, y: 80, width: 390, height: 600), style: .plain)
            table.contentInsetAdjustmentBehavior = .never
            table.rowHeight = UITableView.automaticDimension; table.estimatedRowHeight = 180
            controller.view.addSubview(table); window.makeKeyAndVisible()
            coordinator.install(on: table); coordinator.synchronize()
            defer { coordinator.dismantle(); window.isHidden = true }
            try #require(await VirtualListNativeCondition.wait { !coordinator.isApplyingSnapshot && !table.visibleCells.isEmpty })
            try #require(await VirtualListNativeCondition.wait { coordinator.readingRestoration?.isActive != true })
            coordinator.scrollViewWillBeginDragging(table)
            let recorder = ScrollFrameWindow()
            let step: (Int) -> CGFloat = { index in
                let delta: CGFloat = index < 240 ? 8 : -8
                guard let path = table.indexPathForRow(at: .init(x: table.bounds.midX, y: table.bounds.midY)),
                      let id = coordinator.dataSource?.itemIdentifier(for: path),
                      let geometry = coordinator.displayedGeometry(for: id, in: table) else { return 0 }
                let before = geometry.minY - table.contentOffset.y
                table.contentOffset.y += delta; table.layoutIfNeeded()
                return abs(table.rectForRow(at: path).minY - table.contentOffset.y - (before - delta))
            }
            _ = await recorder.run(frames: 480, step: step)
            let before = table.virtualListDiagnostics.viewportAdjustmentCount
            ScrollWorkMetrics.start()
            let result = await recorder.run(frames: 480, step: step)
            let counts = ScrollWorkMetrics.stop()
            Attachment.record("\(result.report()) counts=\(counts)", named: "SF00-\(kind).txt")
            if kind == "gif" { #expect(counts["gif.frame", default: 0] > 0) }
            #expect(result.drift <= 2)
            #expect(table.virtualListDiagnostics.viewportAdjustmentCount == before)
        }
    }
}

private final class SFFrameMarker: NSObject {}
