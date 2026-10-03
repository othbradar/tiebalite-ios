import UIKit

enum VirtualListRefreshViewport: Equatable {
    case unavailable
    case tracking
    case dragging
    case decelerating
    case settled(isAtTop: Bool)
}

/// Optional, synchronous replacement at the existing diffable commit boundary.
/// Returning nil leaves both the displayed rows and the pending result intact.
@MainActor
struct VirtualListRefreshCommit<Item> {
    let takeRows: (VirtualListRefreshViewport) -> [Item]?
}

extension VirtualizedList.Coordinator {
    var refreshViewport: VirtualListRefreshViewport {
        guard let table = tableView, table.window != nil, !table.bounds.isEmpty,
              hasAppliedSnapshot, !isApplyingSnapshot, pendingItems == nil,
              pendingRestoredAnchor == nil, readingRestoration?.isActive != true,
              !isAdjustingReadingPosition, !table.isPerformingLayout,
              table.bounds.height > table.adjustedContentInset.top + table.adjustedContentInset.bottom,
              table.contentSize.height > 0 else { return .unavailable }
        if table.isDragging { return .dragging }
        if table.isTracking { return .tracking }
        if table.isDecelerating { return .decelerating }
        if userScrollInProgress { return .dragging }
        // All header/section rows live in content coordinates. An overscroll at
        // either end is not the resting top. Allow only one physical pixel of rounding.
        let tolerance = 1 / table.traitCollection.displayScale
        return .settled(isAtTop: abs(table.contentOffset.y + table.adjustedContentInset.top) <= tolerance)
    }

    func refreshViewportChanged(force: Bool = false) {
        guard parent.pendingRefresh != nil else { return }
        let viewport = refreshViewport
        guard force || lastRefreshViewport != viewport else { return }
        lastRefreshViewport = viewport
        guard refreshCommitTask == nil else { return }
        // Leave UIKit layout/provider and SwiftUI update before mutating the Store.
        // This is one coalesced boundary notification, never a timer or polling loop.
        refreshCommitTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            self.refreshCommitTask = nil
            let current = self.refreshViewport
            self.lastRefreshViewport = current
            guard case .settled = current,
                  let rows = self.parent.pendingRefresh?.takeRows(current) else { return }
            // No await between the fresh activity check, Store commit and snapshot.
            self.pendingItems = rows
            self.applyPendingSnapshotIfNeeded()
        }
    }
}
