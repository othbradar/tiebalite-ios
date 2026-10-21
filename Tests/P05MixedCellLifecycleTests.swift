import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
@Suite(.serialized)
struct P05MixedCellLifecycleTests {
    @Test(arguments: [false, true])
    func loadedMixedImagesDoNotJumpDuringSmallScrollSteps(restoringImageRow: Bool) async throws {
        let repository = Stage15LongThreadFixtureRepository(threadID: 990_015, totalPostCount: 80, pageSize: 80)
        let store = ThreadReaderStore(threadID: 990_015, repository: repository)
        await store.loadIfNeeded()
        let bytes = try TestImageFixtureFactory.png(width: 64, height: 48)
        let image = try #require(UIImage(data: bytes))
        let images = HarnessCapturingImageLoader(payload: ImagePayload(
            decodedImage: image, mediaType: "image/png", pixelSize: .init(width: 64, height: 48)))
        let rows = store.configuredRows(textSize: .standard)
        let makeList = { (items: [ThreadReaderConfiguredRow]) in
            VirtualizedList(items: items, backgroundColor: .systemBackground,
                            accessibilityIdentifier: "p05.mixed",
                            restoredAnchor: restoringImageRow ? rows[37].id : nil,
                            contentVersion: items.count, initialRestorationScope: "p05.geometry") { configured in
            ThreadReaderRowView(row: configured.row, imageLoader: images,
                                readingTextSize: configured.readingTextSize,
                                onOpenMedia: { _ in }, onOpenUser: { _ in }, onOpenSubposts: { _ in },
                                onOpenExternalLink: { _ in }, requestNextPage: {})
        }
        }
        let list = makeList(restoringImageRow ? Array(rows.prefix(55)) : rows)
        let coordinator = list.makeCoordinator()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = UIViewController()
        window.rootViewController = controller
        let table = VirtualizedTableView(frame: CGRect(x: 0, y: 80, width: 390, height: 600), style: .plain)
        table.contentInsetAdjustmentBehavior = .never
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        controller.view.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        defer { coordinator.dismantle(); store.cancel(); window.isHidden = true }
        try #require(await VirtualListNativeCondition.wait { !coordinator.isApplyingSnapshot && !table.visibleCells.isEmpty })
        try #require(await VirtualListNativeCondition.wait { coordinator.readingRestoration?.isActive != true })
        coordinator.scrollViewWillBeginDragging(table)
        var worstDrift: CGFloat = 0
        var jumps: [String] = []
        var visitedRows: Set<Int> = []
        // Frame-driven offset steps exercise reuse without scrollToRow resetting
        // the target each time. This is a geometry test, not a natural-pan FPS test.
        let stepsPerDirection = restoringImageRow ? 300 : 600
        for step in 0..<(stepsPerDirection * 2) {
            let delta: CGFloat = step < stepsPerDirection ? 8 : -8
            guard table.contentOffset.y + delta >= 0 else { continue }
            let middle = CGPoint(x: table.bounds.midX, y: table.bounds.midY)
            let path = try #require(table.indexPathForRow(at: middle))
            visitedRows.insert(path.row)
            let id = try #require(coordinator.dataSource?.itemIdentifier(for: path))
            let before = try #require(coordinator.displayedGeometry(for: id, in: table)).minY - table.contentOffset.y
            table.setContentOffset(CGPoint(x: 0, y: table.contentOffset.y + delta), animated: false)
            if restoringImageRow && step == 30 {
                coordinator.parent = makeList(rows)
                coordinator.synchronize()
            }
            table.layoutIfNeeded()
            _ = await VirtualListNativeCondition.wait { true }
            table.layoutIfNeeded()
            let after = table.rectForRow(at: path).minY - table.contentOffset.y
            let drift = abs(after - (before - delta))
            worstDrift = max(worstDrift, drift)
            if drift > 2, jumps.count < 8 {
                jumps.append("step=\(step) row=\(path.row) drift=\(drift) before=\(before) after=\(after)")
            }
        }
        print("P05 small-step geometry: restored=\(restoringImageRow) worst=\(worstDrift) jumps=\(jumps)")
        #expect(visitedRows.contains(37))
        #expect(restoringImageRow || visitedRows.contains(17))
        #expect(await !images.recordedRequests().isEmpty)
        #expect(table.virtualListDiagnostics.reuseCount > 10)
        #expect(worstDrift <= 2, "Visible content must follow the requested scroll delta: \(jumps)")
    }

    @Test
    func mixedRowsReuseBoundedContainersAndReleaseTheirBindings() async throws {
        let repository = Stage15LongThreadFixtureRepository(threadID: 990_015, totalPostCount: 80, pageSize: 80)
        let store = ThreadReaderStore(threadID: 990_015, repository: repository)
        await store.loadIfNeeded()
        let bytes = try TestImageFixtureFactory.png(width: 64, height: 48)
        let image = try #require(UIImage(data: bytes))
        let images = HarnessCapturingImageLoader(payload: ImagePayload(
            decodedImage: image, mediaType: "image/png", pixelSize: .init(width: 64, height: 48)))
        let rows = store.configuredRows(textSize: .standard)
        let list = VirtualizedList(items: rows, backgroundColor: .systemBackground,
                                   accessibilityIdentifier: "p05.mixed", contentVersion: 1) { configured in
            ThreadReaderRowView(row: configured.row, imageLoader: images,
                                readingTextSize: configured.readingTextSize,
                                onOpenMedia: { _ in }, onOpenUser: { _ in }, onOpenSubposts: { _ in },
                                onOpenExternalLink: { _ in }, requestNextPage: {})
        }
        let coordinator = list.makeCoordinator()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = UIViewController()
        window.rootViewController = controller
        let table = VirtualizedTableView(frame: CGRect(x: 0, y: 80, width: 390, height: 600), style: .plain)
        table.contentInsetAdjustmentBehavior = .never
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        controller.view.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        defer { coordinator.dismantle(); store.cancel(); window.isHidden = true }
        try #require(await VirtualListNativeCondition.wait { !coordinator.isApplyingSnapshot && !table.visibleCells.isEmpty })
        // Two passes over the same mixed content. The first warms local images and
        // text; the second also covers reverse reuse and return to the first row.
        var peakResidents = 0
        for _ in 0..<2 {
            for row in Array(1...78) + Array((0...77).reversed()) {
                _ = await VirtualListNativeCondition.wait { true }
                table.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: false)
                table.layoutIfNeeded()
                peakResidents = max(peakResidents, coordinator.retainedHostedCellCount)
            }
        }
        _ = await VirtualListNativeCondition.wait { true }
        let counts = table.virtualListDiagnostics
        #expect(counts.reuseCount > 100)
        // Cumulative creation includes cells UIKit has evicted. Bound the live
        // pool, not the lifetime allocation total across hundreds of jumps.
        #expect(peakResidents <= counts.peakVisibleCellCount * 4)
        #expect(counts.activeHostedCellCount <= counts.createdCellCount)
        let visible = table.visibleCells.compactMap { $0 as? VirtualListHostingCell }
        #expect(!visible.isEmpty && visible.allSatisfy { $0.rowID != nil })
        weak var lastHolder = visible.first?.hostedContent
        coordinator.dismantle()
        #expect(visible.allSatisfy { $0.hostedContent == nil && $0.contentConfiguration == nil })
        #expect(table.dataSource == nil && table.delegate == nil)
        #expect(table.virtualListDiagnostics.activeHostedCellCount == 0)
        #expect(await VirtualListNativeCondition.wait { lastHolder == nil })
        lastHolder = nil
    }
}
