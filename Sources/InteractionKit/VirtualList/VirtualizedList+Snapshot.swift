import UIKit

extension VirtualizedList.Coordinator {
    func applyPendingSnapshotIfNeeded() {
        guard !isApplyingSnapshot,
              let dataSource,
              let tableView,
              let incomingItems = pendingItems else {
            return
        }
        let incomingVersion = pendingVersion
        pendingItems = nil
        pendingVersion = nil
        tableView.virtualListDiagnostics.preparationCount += 1

        let (incomingIDs, uniqueItemsByID) = prepareItems(incomingItems)

        let currentIDs = dataSource.snapshot().itemIdentifiers
        let currentIDSet = Set(currentIDs)
        let changedRetainedIDs = incomingIDs.filter { itemID in
            guard currentIDSet.contains(itemID),
                  let incoming = uniqueItemsByID[itemID],
                  let applied = appliedItemsByID[itemID] else {
                return false
            }
            return incoming != applied || incomingVersion?.environment != completedVersion?.environment
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
            completedVersion = incomingVersion
            updateVisibleContent()
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
        applyingVersion = incomingVersion
        tableView.virtualListDiagnostics.snapshotApplyCount += 1
        dataSource.apply(
            snapshot,
            animatingDifferences: false
        ) { [weak self, weak tableView] in
            Task { @MainActor in
                guard let self else {
                    return
                }
                self.completeSnapshot(items: uniqueItemsByID, version: incomingVersion, tableView: tableView)
            }
        }
    }
    private func completeSnapshot(items: [Item.ID: Item], version: VirtualListUpdateVersion?, tableView: VirtualizedTableView?) {
        appliedItemsByID = items
        completedVersion = version
        applyingVersion = nil
        hasAppliedSnapshot = true
        isApplyingSnapshot = false
        if let tableView {
            restoreAnchorIfNeeded(in: tableView)
        }
        updateVisibleContent()
        applyPendingSnapshotIfNeeded()
        refreshViewportChanged()
    }

    private func prepareItems(_ items: [Item]) -> ([Item.ID], [Item.ID: Item]) {
        var ids: [Item.ID] = []
        var byID: [Item.ID: Item] = [:]
        for item in items where byID[item.id] == nil {
            ids.append(item.id)
            byID[item.id] = item
        }
        return (ids, byID)
    }
}
