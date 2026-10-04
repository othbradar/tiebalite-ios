import SwiftUI
import Testing
@testable import TiebaLite
import UIKit
import XCTest

@MainActor
struct U06P4ReadingProjectionTests {
    @Test
    func navigationInsetBeforeFirstLayoutDoesNotConsumeReadingTarget() async {
        var reports: [Int?] = []
        let list = VirtualizedList(items: (1...60).map(Row.init), backgroundColor: .systemBackground,
                                   accessibilityIdentifier: "p4.projection", restoredAnchor: 33,
                                   initialRestorationScope: AnyHashable("scene-thread-account"),
                                   onScrollSettled: { reports.append($0) }, rowContent: { row in
            Text("Floor \(row.id)").frame(maxWidth: .infinity).frame(height: 117)
        })
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(frame: .zero, style: .plain)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        coordinator.install(on: table)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 850))
        table.frame = window.bounds
        window.addSubview(table)
        // NavigationSplitView adjusts its navigation-bar inset outside layoutSubviews,
        // before the pending semantic target has been positioned.
        table.contentInset.top = 64
        table.setContentOffset(CGPoint(x: 0, y: -64), animated: false)
        coordinator.scrollViewDidScroll(table)
        #expect(coordinator.pendingRestoredAnchor == 33)
        #expect(coordinator.readingRestoration?.isActive == true)
        #expect(reports.isEmpty)
        window.makeKeyAndVisible()
        table.setNeedsLayout()
        table.layoutIfNeeded()
        defer { coordinator.dismantle(); window.isHidden = true }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                coordinator.readingRestoration?.isActive == false &&
                    coordinator.displayedGeometry(for: 33, in: table)?.intersects(coordinator.readableViewport(in: table)) == true
            }
        }, object: nil)
        let result = await XCTWaiter.fulfillment(of: [ready], timeout: 5)
        #expect(result == .completed)
        #expect(coordinator.displayedGeometry(for: 33, in: table)?.intersects(coordinator.readableViewport(in: table)) == true)
        #expect(table.virtualListDiagnostics.initialReadingAdjustmentCount == 1)
        #expect(coordinator.readingRestoration?.target == nil)
        coordinator.scrollViewWillBeginDragging(table)
        table.setContentOffset(CGPoint(x: 0, y: table.contentOffset.y + 350), animated: false)
        table.layoutIfNeeded()
        coordinator.scrollViewDidEndDecelerating(table)
        #expect(reports.last.flatMap { $0 } != nil && reports.last.flatMap { $0 } != 33)
        #expect(table.virtualListDiagnostics.createdCellCount < 60)
    }

    @Test
    func sameTableWidthChangeKeepsCurrentBusinessFloorWithoutReplayingHistory() async {
        let list = VirtualizedList(items: (1...60).map(Row.init), backgroundColor: .systemBackground,
                                   accessibilityIdentifier: "p4.resize", restoredAnchor: 33,
                                   initialRestorationScope: AnyHashable("scene-thread-account")) { row in
            Text("Floor \(row.id) " + String(repeating: "variable width reading content ", count: 20))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        let coordinator = list.makeCoordinator()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 700, height: 850))
        let table = VirtualizedTableView(frame: window.bounds, style: .plain)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        defer { coordinator.dismantle(); window.isHidden = true }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { coordinator.readingRestoration?.isActive == false }
        }, object: nil)
        #expect(await XCTWaiter.fulfillment(of: [ready], timeout: 5) == .completed)
        #expect(coordinator.displayedGeometry(for: 33, in: table)?.intersects(coordinator.readableViewport(in: table)) == true)
        let adjustments = table.virtualListDiagnostics.initialReadingAdjustmentCount
        table.frame.size.width = 320
        table.setNeedsLayout()
        table.layoutIfNeeded()
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                coordinator.displayedGeometry(for: 33, in: table)?.intersects(coordinator.readableViewport(in: table)) == true
            }
        }, object: nil)
        #expect(await XCTWaiter.fulfillment(of: [resized], timeout: 5) == .completed)
        #expect(coordinator.dataSource?.snapshot().numberOfItems == 60)
        #expect(table.virtualListDiagnostics.initialReadingAdjustmentCount == adjustments)
        #expect(coordinator.readingRestoration?.target == nil)
        #expect(table.virtualListDiagnostics.createdCellCount < 60)
    }

    private struct Row: Identifiable, Equatable, Sendable { let id: Int }
}
