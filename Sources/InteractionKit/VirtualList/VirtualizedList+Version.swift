import SwiftUI
import UIKit

/// Optional caller-owned revision; business row identities remain unchanged.
struct VirtualListContentRevision: Hashable {
    let owner: ObjectIdentifier
    let revision: UInt64
    var configuration: AnyHashable?
}

struct VirtualListUpdateVersion: Equatable {
    struct Environment: Equatable {
        let size: DynamicTypeSize
        let color: ColorScheme
        let direction: LayoutDirection
        let locale: Locale
    }
    let content: AnyHashable
    let environment: Environment
}

extension VirtualizedList.Coordinator {
    func stageCurrentItems() {
        let version = parent.updateVersion
        if let version, isApplyingSnapshot, applyingVersion == version {
            // A newer pending update may have been superseded by a return to the in-flight version.
            pendingItems = nil
            pendingVersion = nil
            return
        }
        if let version, !isApplyingSnapshot, hasAppliedSnapshot, completedVersion == version {
            pendingItems = nil
            pendingVersion = nil
            updateVisibleContent()
            if let tableView { restoreAnchorIfNeeded(in: tableView) }
            return
        }
        pendingItems = parent.items
        pendingVersion = version
    }

    // Fresh closures/environment for displayed cells only. Offscreen cells receive the
    // current parent at reuse; no full-array scan or diffable apply for callback changes.
    func updateVisibleContent() {
        guard parent.contentVersion != nil, !isApplyingSnapshot, let tableView else { return }
        for case let cell as VirtualListHostingCell in tableView.visibleCells {
            guard let id = cell.rowID?.base as? Item.ID, let item = appliedItemsByID[id] else { continue }
            configure(cell, with: item)
        }
    }

    func configure(_ cell: VirtualListHostingCell, with item: Item) {
        let content = parent.rowContent(item)
        cell.rowID = AnyHashable(item.id)
        cell.hasCurrentConfiguration = { [weak self] in self?.itemsByID[item.id] == item }
        cell.contentConfiguration = UIHostingConfiguration { content }
            .margins(.all, 0)
            .background { Color.clear }
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none
    }
}
