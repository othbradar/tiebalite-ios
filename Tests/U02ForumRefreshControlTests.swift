import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct U02ForumRefreshControlTests {
    @Test(arguments: [false, true])
    func dismantleReportsPositionOnlyWithARealViewport(hasViewport: Bool) async throws {
        var reported: [Int?] = []
        let list = VirtualizedList(items: (1...4).map(Row.init), backgroundColor: .systemBackground,
                                   accessibilityIdentifier: "u02.position", restoredAnchor: 3,
                                   onScrollSettled: { reported.append($0) }, rowContent: { Text(String($0.id)) })
        let coordinator = list.makeCoordinator()
        let frame = hasViewport ? CGRect(x: 0, y: 0, width: 390, height: 200) : .zero
        let table = VirtualizedTableView(frame: frame, style: .plain)
        coordinator.install(on: table)
        coordinator.synchronize()
        for _ in 0..<100 where !coordinator.hasAppliedSnapshot { await Task.yield() }
        #expect(coordinator.hasAppliedSnapshot)
        table.layoutIfNeeded()
        // UIKit can expose a first row even before the table ever receives a viewport.
        #expect(table.indexPathsForVisibleRows?.first == IndexPath(row: 0, section: 0))
        #expect(table.window == nil)
        coordinator.dismantle()
        #expect(reported == (hasViewport ? [1] : []))
    }

    @Test
    func optionalRefreshCoalescesAndCancelsOnDismantleWithoutChangingRows() async throws {
        let started = HarnessContinuationGate<Void>()
        let release = HarnessContinuationGate<Void>()
        let finished = HarnessContinuationGate<Bool>()
        var requests = 0
        let rows = (1...4).map(Row.init)
        let list = VirtualizedList(items: rows, backgroundColor: .systemBackground, accessibilityIdentifier: "u02.refresh",
                                   onRefresh: {
            requests += 1
            started.succeed(())
            _ = try? await release.wait()
            finished.succeed(Task.isCancelled)
        }, rowContent: { Text(String($0.id)) })
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(frame: .zero, style: .plain)
        coordinator.install(on: table)
        coordinator.synchronize()
        let control = try #require(table.refreshControl)
        control.sendActions(for: .valueChanged)
        try await started.wait()
        control.sendActions(for: .valueChanged)
        #expect(requests == 1)
        #expect(coordinator.parent.items == rows)
        coordinator.dismantle()
        release.succeed(())
        #expect(try await finished.wait())
        #expect(table.refreshControl == nil)
        #expect(table.delegate == nil)
        let plain = VirtualizedList(items: rows, backgroundColor: .systemBackground,
                                    accessibilityIdentifier: "u02.plain", rowContent: { Text(String($0.id)) })
        let plainCoordinator = plain.makeCoordinator()
        plainCoordinator.install(on: table)
        #expect(table.refreshControl == nil)
        plainCoordinator.dismantle()
    }

    private struct Row: Identifiable, Equatable, Sendable { let id: Int }
}
