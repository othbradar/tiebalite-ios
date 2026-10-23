import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct Controls {
        @Test func forumControlUsesProductionFeed() async throws {
            let repository = DebugStage14PLongForumFixtureRepository()
            let snapshot = try await repository.loadForumHomePage(.init(route: try #require(ForumRoute("Stage14P表格")), pageNumber: 1))
            let presentation = ForumHomeListPresentation(snapshot: snapshot, pagination: .idle)
            let list = VirtualizedList(items: presentation.rows, backgroundColor: .systemBackground,
                                       accessibilityIdentifier: "sf.forum", contentVersion: 1) { row in
                ForumHomeRowView(row: row, onOpenThread: { _ in }, requestReload: {}, requestNextPage: {})
            }
            try await window(list, name: "forum-control", step: 8)
        }
        @Test func playingVoiceAndIdleVoicesUseProductionViews() async throws {
            let url = try #require(Bundle(for: SFControlMarker.self).resourceURL?.appendingPathComponent("Fixtures/Media/voice.m4a"))
            let source = MediaPlaybackSource(url: url)
            let list = VirtualizedList(items: (0..<20).map { SFVoiceItem(id: $0) }, backgroundColor: .systemBackground,
                                       accessibilityIdentifier: "sf.voices", contentVersion: 1) { row in
                ThreadVoicePlayerView(owner: "sf-voice-\(row.id)", source: source)
                    .frame(height: row.id == 0 ? 320 : 80)
            }
            MediaPlaybackController.shared.play(owner: "sf-voice-0", source: source)
            defer { MediaPlaybackController.shared.stop(owner: "sf-voice-0") }
            try await window(list, name: "voice-playback", step: 1)
        }
        private func window<Item, Row>(_ list: VirtualizedList<Item, Row>, name: String, step: CGFloat) async throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
            let controller = UIViewController(); window.rootViewController = controller
            let table = VirtualizedTableView(frame: .init(x: 0, y: 80, width: 390, height: 600), style: .plain)
            table.contentInsetAdjustmentBehavior = .never; table.rowHeight = UITableView.automaticDimension; table.estimatedRowHeight = 180
            controller.view.addSubview(table); window.makeKeyAndVisible()
            let coordinator = list.makeCoordinator(); coordinator.install(on: table); coordinator.synchronize()
            defer { coordinator.dismantle(); window.isHidden = true }
            try #require(await VirtualListNativeCondition.wait { !coordinator.isApplyingSnapshot && !table.visibleCells.isEmpty })
            coordinator.scrollViewWillBeginDragging(table)
            let move: (Int) -> CGFloat = { index in
                guard let path = table.indexPathForRow(at: .init(x: table.bounds.midX, y: table.bounds.midY)),
                      let id = coordinator.dataSource?.itemIdentifier(for: path),
                      let geometry = coordinator.displayedGeometry(for: id, in: table) else { return 0 }
                let before = geometry.minY - table.contentOffset.y
                let delta = index < 90 ? step : -step
                table.contentOffset.y += delta; table.layoutIfNeeded()
                return abs(table.rectForRow(at: path).minY - table.contentOffset.y - (before - delta))
            }
            let recorder = ScrollFrameWindow()
            _ = await recorder.run(frames: 180, step: move)
            ScrollWorkMetrics.start()
            let result = await recorder.run(frames: 180, step: move)
            let counts = ScrollWorkMetrics.stop()
            Attachment.record("\(result.report()) counts=\(counts)", named: "SF00-\(name).txt")
            #expect(result.drift <= 2 && table.virtualListDiagnostics.viewportAdjustmentCount == 0)
            if name == "voice-playback" {
                #expect(MediaPlaybackController.shared.status.phase == .playing)
                #expect(MediaPlaybackController.shared.progress.elapsed > 0)
            }
        }
    }
}
private struct SFVoiceItem: Identifiable, Equatable, Sendable { let id: Int }
private final class SFControlMarker: NSObject {}
