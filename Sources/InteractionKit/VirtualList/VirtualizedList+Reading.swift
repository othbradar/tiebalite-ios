import SwiftUI
import UIKit

extension VirtualizedList.Coordinator {
    func invalidateChangedReadingScope() {
        guard let tableView else { return }
        if initialScope != parent.initialRestorationScope {
            stopReadingRestoration(permitsProgress: false)
            viewportAnchor = nil
            tableView.onViewportLayout = nil
        } else if let restoration = readingRestoration, restoration.isActive,
                  restoration.target != parent.restoredAnchor {
            stopReadingRestoration(permitsProgress: false)
            viewportAnchor = nil
        }
    }

    func restoreAnchorIfNeeded(in tableView: VirtualizedTableView) {
        // Snapshot completion can precede attachment and layout. Keep the one-shot
        // anchor until UIKit has the real viewport, rather than scrolling a zero-size table.
        guard tableView.window != nil, !tableView.bounds.isEmpty,
              let restoredAnchor = pendingRestoredAnchor,
              let dataSource,
              let indexPath = dataSource.indexPath(for: restoredAnchor)
        else {
            return
        }
        if readingRestoration != nil {
            advanceReadingRestoration(in: tableView, indexPath: indexPath)
            return
        }
        pendingRestoredAnchor = nil
        tableView.onInitialAnchorLayout = nil
        tableView.scrollToRow(at: indexPath, at: .top, animated: false)
    }

    func emitSettledAnchor() {
        userScrollInProgress = false
        if let tableView { captureReadingViewport(in: tableView) }
        guard !isAdjustingReadingPosition, initialScope == parent.initialRestorationScope,
              readingRestoration?.permitsProgress != false else { return }
        guard let tableView,
              let dataSource else {
            parent.onScrollSettled(nil)
            return
        }
        let topVisible = tableView.indexPathsForVisibleRows?
            .sorted()
            .first
        parent.onScrollSettled(
            topVisible.flatMap { dataSource.itemIdentifier(for: $0) }
        )
    }

    func emitCurrentAnchorIfAvailable() {
        // A transient zero-size table can report its first row without ever displaying it.
        // Ignore that teardown so it cannot replace a restored reading position with top.
        guard !isAdjustingReadingPosition, initialScope == parent.initialRestorationScope,
              readingRestoration?.permitsProgress != false,
              let tableView,
              !tableView.bounds.isEmpty,
              let dataSource,
              let topVisible = tableView.indexPathsForVisibleRows?
                .sorted()
                .first,
              let itemID = dataSource.itemIdentifier(for: topVisible)
        else {
            return
        }
        parent.onScrollSettled(itemID)
    }

    func stopReadingRestoration(permitsProgress: Bool) {
        guard readingRestoration != nil else { return }
        readingRestoration?.stop(permitsProgress: permitsProgress)
        tableView?.virtualListDiagnostics.isRestoringInitialReadingPosition = false
        pendingRestoredAnchor = nil
        tableView?.onInitialAnchorLayout = nil
    }

    func advanceReadingRestoration(in table: VirtualizedTableView, indexPath: IndexPath) {
        guard hasAppliedSnapshot, !isApplyingSnapshot, !isAdjustingReadingPosition,
              readingRestoration?.isActive == true else { return }
        if table.isTracking || table.isDragging || table.isDecelerating || userScrollInProgress {
            stopReadingRestoration(permitsProgress: true)
            return
        }
        isAdjustingReadingPosition = true
        defer { isAdjustingReadingPosition = false }
        if readingRestoration?.hasPositioned == false {
            readingRestoration?.positioned()
            table.scrollToRow(at: indexPath, at: .top, animated: false)
            table.virtualListDiagnostics.initialReadingAdjustmentCount += 1
        }
        guard let target = readingRestoration?.target,
              let geometry = displayedGeometry(for: target, in: table),
              geometry.intersects(readableViewport(in: table)) else { return }
        viewportAnchor = makeViewportAnchor(id: target, rect: geometry, in: table)
        stopReadingRestoration(permitsProgress: true)
    }

    func readableViewport(in table: VirtualizedTableView) -> CGRect {
        table.bounds.inset(by: table.adjustedContentInset)
    }

    func displayedGeometry(for id: Item.ID, in table: VirtualizedTableView) -> CGRect? {
        guard let path = dataSource?.indexPath(for: id),
              let cell = table.cellForRow(at: path) as? VirtualListHostingCell,
              cell.rowID == AnyHashable(id), cell.isDisplayed, cell.window != nil,
              cell.hasCurrentConfiguration?() == true,
              table.visibleCells.contains(where: { $0 === cell }) else { return nil }
        return cell.frame
    }

    func makeViewportAnchor(id: Item.ID, rect: CGRect, in table: VirtualizedTableView) -> ReadingViewportAnchor<Item.ID> {
        ReadingViewportAnchor(rowID: id, rowMinY: rect.minY, offsetY: table.contentOffset.y,
                              topInset: table.adjustedContentInset.top, layoutSize: table.bounds.size)
    }

    func captureReadingViewport(in table: VirtualizedTableView) {
        guard initialScope != nil, initialScope == parent.initialRestorationScope,
              table.window != nil, !table.bounds.isEmpty, !isApplyingSnapshot else { return }
        let viewport = readableViewport(in: table)
        for path in table.indexPathsForVisibleRows?.sorted() ?? [] {
            guard let id = dataSource?.itemIdentifier(for: path),
                  let rect = displayedGeometry(for: id, in: table), rect.intersects(viewport) else { continue }
            viewportAnchor = makeViewportAnchor(id: id, rect: rect, in: table)
            return
        }
    }

    func maintainReadingViewport(in table: VirtualizedTableView) {
        guard !isAdjustingReadingPosition, initialScope == parent.initialRestorationScope,
              readingRestoration?.isActive != true, !isApplyingSnapshot,
              table.window != nil, !table.bounds.isEmpty else { return }
        guard !userScrollInProgress, !table.isTracking, !table.isDragging, !table.isDecelerating else {
            viewportAnchor = nil
            return
        }
        if let anchor = viewportAnchor, anchor.layoutSize == table.bounds.size,
           let path = dataSource?.indexPath(for: anchor.rowID) {
            isAdjustingReadingPosition = true
            defer { isAdjustingReadingPosition = false }
            // This geometry read may enter the provider; no transaction mutation spans it.
            let row = table.rectForRow(at: path)
            let lower = -table.adjustedContentInset.top
            let upper = max(lower, table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom)
            let desired = anchor.desiredOffset(rowMinY: row.minY, topInset: table.adjustedContentInset.top,
                                               lower: lower, upper: upper)
            if abs(desired - table.contentOffset.y) > 0.5 {
                table.setContentOffset(CGPoint(x: table.contentOffset.x, y: desired), animated: false)
                table.virtualListDiagnostics.viewportAdjustmentCount += 1
            }
        } else {
            viewportAnchor = nil
            captureReadingViewport(in: table)
        }
    }

}
