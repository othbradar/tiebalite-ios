import SwiftUI
import Testing
@testable import TiebaLite
import UIKit
import XCTest

@MainActor
struct U03InitialReadingRestorationTests {
    @Test
    func newTableCompletesSizingWithRepeatedRowHeightsAndNeverRestartsOnUpdate() async {
        var reports: [Int?] = []
        func list(count: Int = 60, expandedRow: Int? = nil) -> VirtualizedList<Row, some View> {
            VirtualizedList(items: (1...count).map { Row(id: $0, expanded: $0 == expandedRow) }, backgroundColor: .systemBackground,
                            accessibilityIdentifier: "u03.sizing", restoredAnchor: 29,
                            initialRestorationScope: AnyHashable("thread-account"),
                            onScrollSettled: { reports.append($0) }, rowContent: { item in
                Text("Floor \(item.id)").frame(maxWidth: .infinity).frame(height: item.id == 1 ? 777 : item.expanded ? 277 : 117)
            })
        }
        let coordinator = list().makeCoordinator()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let table = VirtualizedTableView(frame: window.bounds, style: .plain)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        table.separatorStyle = .none
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        defer { coordinator.dismantle(); window.isHidden = true }
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { !table.virtualListDiagnostics.isRestoringInitialReadingPosition }
        }, object: nil)
        let result = await XCTWaiter.fulfillment(of: [completed], timeout: 5)
        #expect(result == .completed)
        #expect(coordinator.readingRestoration?.isActive == false)
        #expect(coordinator.readingRestoration?.permitsProgress == true)
        #expect(!table.hasInitialAnchorLayout)
        #expect(table.indexPathsForVisibleRows?.contains(IndexPath(row: 28, section: 0)) == true)
        #expect(table.virtualListDiagnostics.createdCellCount < 60)
        #expect(reports.isEmpty)
        #expect(coordinator.readingRestoration?.target == nil)
        // A later self-sizing update to a realized predecessor must retain this viewport.
        let restoredOffset = table.contentOffset.y
        let targetPath = IndexPath(row: 28, section: 0)
        let relativeY = table.rectForRow(at: targetPath).minY - restoredOffset
        coordinator.parent = list(expandedRow: 28)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        table.layoutIfNeeded()
        #expect(table.indexPathsForVisibleRows?.contains(targetPath) == true)
        #expect(abs(table.rectForRow(at: targetPath).minY - table.contentOffset.y - relativeY) < 1)
        let corrections = table.virtualListDiagnostics.initialReadingAdjustmentCount
        coordinator.scrollViewWillBeginDragging(table)
        table.setContentOffset(CGPoint(x: 0, y: table.contentOffset.y + 200), animated: false)
        table.layoutIfNeeded()
        coordinator.scrollViewDidEndDecelerating(table)
        #expect(reports.last.flatMap { $0 } != nil && reports.last.flatMap { $0 } != 29)
        // Append a page/footer, then expand a realized row as a late image would.
        coordinator.parent = list(count: 65)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        table.layoutIfNeeded()
        coordinator.parent = list(count: 65, expandedRow: 33)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        table.layoutIfNeeded()
        coordinator.scrollViewDidEndDecelerating(table)
        let actualTopID = table.indexPathsForVisibleRows?.sorted().first.flatMap { coordinator.dataSource?.itemIdentifier(for: $0) }
        #expect(reports.last.flatMap { $0 } == actualTopID && actualTopID != 29)
        #expect(table.virtualListDiagnostics.initialReadingAdjustmentCount == corrections)
        #expect(!table.hasInitialAnchorLayout && coordinator.readingRestoration?.permitsProgress == true)
        #expect(!table.virtualListDiagnostics.isRestoringInitialReadingPosition)
    }

    @Test(arguments: [0.0, 160.0, 80.0])
    func layoutOnlyCompensatesWhatUIKitHasNotAlreadyAdjusted(nativeCompensation: Double) async {
        let list = VirtualizedList(items: (1...60).map(Row.init), backgroundColor: .systemBackground,
                                   accessibilityIdentifier: "u03.compensation", restoredAnchor: 29,
                                   initialRestorationScope: AnyHashable("thread-account"), rowContent: {
            Text("Floor \($0.id)").frame(maxWidth: .infinity).frame(height: 117)
        })
        let coordinator = list.makeCoordinator()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let table = VirtualizedTableView(frame: window.bounds, style: .plain)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        defer { coordinator.dismantle(); window.isHidden = true }
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { coordinator.readingRestoration?.isActive == false }
        }, object: nil)
        #expect(await XCTWaiter.fulfillment(of: [completed], timeout: 5) == .completed)
        let target = IndexPath(row: 28, section: 0)
        let oldOrigin = table.rectForRow(at: target).minY
        let oldOffset = table.contentOffset.y
        let oldRelativeY = oldOrigin - oldOffset
        // A real header change moves the target's row geometry by 160 points.
        // Supply the native offset outcome at the layout boundary, before our adapter runs.
        coordinator.isAdjustingReadingPosition = true
        table.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 160))
        table.setContentOffset(CGPoint(x: 0, y: oldOffset + nativeCompensation), animated: false)
        coordinator.isAdjustingReadingPosition = false
        coordinator.maintainReadingViewport(in: table)
        #expect(abs(table.rectForRow(at: target).minY - oldOrigin - 160) < 1)
        #expect(abs(table.rectForRow(at: target).minY - table.contentOffset.y - oldRelativeY) < 1)
        let corrections = table.virtualListDiagnostics.viewportAdjustmentCount
        coordinator.maintainReadingViewport(in: table)
        #expect(table.virtualListDiagnostics.viewportAdjustmentCount == corrections)
        #expect(coordinator.readingRestoration?.target == nil)
        #expect(table.virtualListDiagnostics.createdCellCount < 60)
    }

    @Test(arguments: [true, false])
    func completionOrCancellationReleasesHistoricalTarget(permitsProgress: Bool) {
        var transaction = InitialReadingRestoration(target: 430_001)
        transaction.positioned()
        transaction.stop(permitsProgress: permitsProgress)
        #expect(!transaction.isActive && transaction.target == nil)
        #expect(transaction.permitsProgress == permitsProgress)
    }

    @Test(arguments: ["drag", "account", "target", "dismantle"])
    func interruptedTableCannotRestoreOrPersistItsProgrammaticPosition(reason: String) async {
        var reports: [Int?] = []
        func list(scope: String = "account-a", target: Int = 29) -> VirtualizedList<Row, some View> {
            VirtualizedList(items: (1...60).map(Row.init), backgroundColor: .systemBackground,
                            accessibilityIdentifier: "u03.initial", restoredAnchor: target,
                            initialRestorationScope: AnyHashable(scope), onScrollSettled: { reports.append($0) }, rowContent: {
                Text("Floor \($0.id)").frame(maxWidth: .infinity).frame(height: 100)
            })
        }
        let coordinator = list().makeCoordinator()
        let table = VirtualizedTableView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), style: .plain)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 180
        coordinator.install(on: table)
        coordinator.synchronize()
        while coordinator.isApplyingSnapshot { await Task.yield() }
        table.layoutIfNeeded()
        #expect(table.virtualListDiagnostics.isRestoringInitialReadingPosition)
        coordinator.scrollViewDidEndScrollingAnimation(table)
        #expect(reports.isEmpty)
        switch reason {
        case "drag": coordinator.scrollViewWillBeginDragging(table)
        case "account": coordinator.parent = list(scope: "account-b")
        case "target": coordinator.parent = list(target: 39)
        default: coordinator.dismantle()
        }
        if reason != "dismantle" { coordinator.synchronize() }
        #expect(!table.virtualListDiagnostics.isRestoringInitialReadingPosition)
        let window = UIWindow(frame: table.frame)
        window.addSubview(table)
        window.makeKeyAndVisible()
        defer { coordinator.dismantle(); window.isHidden = true }
        table.setContentOffset(CGPoint(x: 0, y: 200), animated: false)
        table.setNeedsLayout()
        table.layoutIfNeeded()
        #expect(table.contentOffset.y == (reason == "dismantle" ? 0 : 200))
        coordinator.scrollViewDidEndDecelerating(table)
        #expect(reason == "drag" ? !reports.isEmpty : reports.isEmpty)
    }

    private struct Row: Identifiable, Equatable, Sendable {
        let id: Int
        var expanded = false
        init(id: Int, expanded: Bool = false) { self.id = id; self.expanded = expanded }
        init(_ id: Int) { self.id = id }
    }
}
