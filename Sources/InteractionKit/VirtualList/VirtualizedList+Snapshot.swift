import UIKit

extension VirtualizedList.Coordinator {
    func applyPendingSnapshotIfNeeded() {
        guard !isApplyingSnapshot,
              let dataSource,
              let tableView,
              let incomingItems = pendingItems else {
            return
        }
        pendingItems = nil

        var incomingIDs: [Item.ID] = []
        var uniqueItemsByID: [Item.ID: Item] = [:]
        for item in incomingItems where uniqueItemsByID[item.id] == nil {
            incomingIDs.append(item.id)
            uniqueItemsByID[item.id] = item
        }

        let currentIDs = dataSource.snapshot().itemIdentifiers
        let currentIDSet = Set(currentIDs)
        let changedRetainedIDs = incomingIDs.filter { itemID in
            guard currentIDSet.contains(itemID),
                  let incoming = uniqueItemsByID[itemID],
                  let applied = appliedItemsByID[itemID] else {
                return false
            }
            return incoming != applied
        }

        if let anchor = viewportAnchor,
           !incomingIDs.contains(anchor.rowID) ||
            VirtualListSnapshotPlan(currentIDs: currentIDs, incomingIDs: incomingIDs).requiresFullReplacement {
            viewportAnchor = nil
        }
        if let target = readingRestoration?.target, !incomingIDs.contains(target), hasAppliedSnapshot {
            stopReadingRestoration(permitsProgress: false)
        }
        itemsByID = uniqueItemsByID
        tableView.virtualListDiagnostics.itemCount = incomingIDs.count
        if hasAppliedSnapshot,
           currentIDs == incomingIDs,
           changedRetainedIDs.isEmpty {
            appliedItemsByID = uniqueItemsByID
            restoreAnchorIfNeeded(in: tableView)
            return
        }

        var snapshot: NSDiffableDataSourceSnapshot<
            VirtualListSection,
            Item.ID
        >
        if currentIDs == incomingIDs,
           dataSource.snapshot().sectionIdentifiers == [.content] {
            snapshot = dataSource.snapshot()
        } else {
            snapshot = NSDiffableDataSourceSnapshot<
                VirtualListSection,
                Item.ID
            >()
            snapshot.appendSections([.content])
            snapshot.appendItems(incomingIDs, toSection: .content)
        }
        if !changedRetainedIDs.isEmpty {
            snapshot.reconfigureItems(changedRetainedIDs)
        }

        isApplyingSnapshot = true
        tableView.virtualListDiagnostics.snapshotApplyCount += 1
        dataSource.apply(
            snapshot,
            animatingDifferences: false
        ) { [weak self, weak tableView] in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.appliedItemsByID = uniqueItemsByID
                self.hasAppliedSnapshot = true
                self.isApplyingSnapshot = false
                if let tableView {
                    self.restoreAnchorIfNeeded(in: tableView)
                }
                self.applyPendingSnapshotIfNeeded()
                self.refreshViewportChanged()
            }
        }
    }
}
