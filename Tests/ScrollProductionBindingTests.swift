import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct ProductionBinding {
        @Test func currentBodyActionReplacesOldCaptureWithoutRebuildingContent() async throws {
            let repository = Stage15LongThreadFixtureRepository(threadID: 990_015, totalPostCount: 20, pageSize: 20)
            let snapshot = try await repository.loadPage(.init(threadID: 990_015, pageNumber: 0, postID: 0))
            let post = ThreadReaderPostRowModel(snapshot.posts[1])
            let item = ThreadReaderConfiguredRow(
                row: .init(id: .post(threadID: 990_015, postID: post.source.postID), content: .post(post)),
                readingTextSize: .standard)
            let image = try #require(UIImage(data: TestImageFixtureFactory.png(width: 64, height: 48)))
            let loader = HarnessCapturingImageLoader(payload: .init(
                decodedImage: image, mediaType: "image/png", pixelSize: .init(width: 64, height: 48)))
            let otherLoader = HarnessCapturingImageLoader(payload: .init(data: Data(), mediaType: "image/png"))
            let erased: any ImageLoading = loader
            #expect(erased.renderingIdentity != nil && erased.renderingIdentity == loader.renderingIdentity)
            #expect(erased.renderingIdentity != otherLoader.renderingIdentity)
            #expect(DisabledImageLoader().renderingIdentity == nil)
            var selected = 0
            func list(_ capture: SFCallbackCapture) -> VirtualizedList<ThreadReaderConfiguredRow, ThreadReaderVirtualRow> {
                VirtualizedList(
                    items: [item], backgroundColor: .systemBackground, accessibilityIdentifier: "sf.production",
                    contentVersion: 1, refreshUnchangedContent: { $0.refreshActions(from: $1) }, rowContent: { item in
                        ThreadReaderVirtualRow(ThreadReaderRowView(
                            row: item.row, imageLoader: loader, readingTextSize: .standard,
                            onOpenMedia: { _ in }, onOpenUser: { _ in }, onOpenSubposts: { _ in },
                            onOpenExternalLink: { _ in }, onReply: { _ in selected = capture.number }, requestNextPage: {}),
                            contentActions: nil)
                    })
            }
            var first: SFCallbackCapture? = .init(1)
            weak var oldCapture = first
            let coordinator = list(try #require(first)).makeCoordinator()
            first = nil
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
            let controller = UIViewController(); window.rootViewController = controller
            let table = VirtualizedTableView(frame: .init(x: 0, y: 80, width: 390, height: 600), style: .plain)
            table.rowHeight = UITableView.automaticDimension; table.estimatedRowHeight = 180
            controller.view.addSubview(table); window.makeKeyAndVisible()
            coordinator.install(on: table); coordinator.synchronize()
            defer { coordinator.dismantle(); window.isHidden = true }
            try #require(await VirtualListNativeCondition.wait { text(in: table)?.text.isEmpty == false })
            ScrollWorkMetrics.start()
            coordinator.parent = list(.init(99)); coordinator.synchronize()
            #expect(ScrollWorkMetrics.stop()["cell.hostConfiguration", default: 0] == 0)
            #expect(try #require(text(in: table)).accessibilityActivate())
            #expect(selected == 99)
            #expect(await VirtualListNativeCondition.wait { oldCapture == nil })
            oldCapture = nil
        }
        private func text(in view: UIView) -> TiebaSelectableTextView? {
            if let text = view as? TiebaSelectableTextView, text.window != nil { return text }
            return view.subviews.lazy.compactMap { text(in: $0) }.first
        }
    }
}
@MainActor private final class SFCallbackCapture { let number: Int; init(_ number: Int) { self.number = number } }
