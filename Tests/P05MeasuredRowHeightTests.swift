import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct P05MeasuredRowHeightTests {
    @Test
    func paginationKeepsMeasuredEstimatesButChangedContentAndWidthAreMeasuredAgain() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let fixture = VirtualListBindingFixture(scene: scene)
        defer { fixture.close() }
        let table = fixture.table
        table.estimatedRowHeight = 180
        try #require(await fixture.waitForText("row-1-pending"))
        let coordinator = fixture.coordinator
        let first = IndexPath(row: 0, section: 0)
        coordinator.rememberVisibleHeights()
        #expect(abs(coordinator.estimatedHeight(in: table, at: first) - 72) < 2)
        let loader = fixture.loader
        func list(count: Int, firstHeight: CGFloat) -> VirtualizedList<VirtualListBindingItem, VirtualListBindingRow> {
            VirtualizedList(items: (1...count).map {
                .init(id: $0, title: "row-\($0)", height: $0 == 1 ? firstHeight : 72)
            }, backgroundColor: .systemBackground, accessibilityIdentifier: "p05.estimates") {
                VirtualListBindingRow(item: $0, loader: loader)
            }
        }
        coordinator.parent = list(count: 60, firstHeight: 72)
        coordinator.synchronize()
        try #require(await VirtualListNativeCondition.wait { !coordinator.isApplyingSnapshot })
        #expect(abs(coordinator.estimatedHeight(in: table, at: first) - 72) < 2)
        table.frame.size.width = 320
        #expect(coordinator.estimatedHeight(in: table, at: first) == 180)
        table.frame.size.width = 390
        let category = table.traitCollection.preferredContentSizeCategory
        table.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        table.updateTraitsIfNeeded()
        #expect(table.traitCollection.preferredContentSizeCategory == .accessibilityExtraExtraExtraLarge)
        #expect(coordinator.estimatedHeight(in: table, at: first) == 180)
        table.traitOverrides.preferredContentSizeCategory = category
        table.updateTraitsIfNeeded()
        coordinator.parent = list(count: 60, firstHeight: 144)
        coordinator.synchronize()
        try #require(await VirtualListNativeCondition.wait {
            !coordinator.isApplyingSnapshot && abs(table.rectForRow(at: first).height - 144) < 2
        })
        coordinator.rememberVisibleHeights()
        #expect(abs(coordinator.estimatedHeight(in: table, at: first) - 144) < 2)
        #expect(await fixture.waitForText("row-1-pending"))
        #expect(coordinator.measuredRowHeights.count <= 60)
        coordinator.dismantle()
        #expect(coordinator.measuredRowHeights.isEmpty)
    }
}
