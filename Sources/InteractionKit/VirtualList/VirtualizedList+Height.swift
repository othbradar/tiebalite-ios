import UIKit

struct VirtualListMeasuredHeight {
    let width: CGFloat
    let height: CGFloat
    let contentSizeCategory: UIContentSizeCategory
    let layoutDirection: UITraitEnvironmentLayoutDirection
}

extension VirtualizedList.Coordinator {
    // Diffable updates can discard UIKit's previous estimates during a pan.
    // Keep actual realized heights by business identity, never by reused cell/path.
    // These remain estimates: automaticDimension still measures current content.
    func estimatedHeight(in tableView: UITableView, at indexPath: IndexPath) -> CGFloat {
        if let id = dataSource?.itemIdentifier(for: indexPath),
           let measured = measuredRowHeights[id], measured.width == tableView.bounds.width,
           measured.contentSizeCategory == tableView.traitCollection.preferredContentSizeCategory,
           measured.layoutDirection == tableView.traitCollection.layoutDirection {
            return measured.height
        }
        return tableView.estimatedRowHeight
    }

    func rememberVisibleHeights() {
        tableView?.visibleCells.forEach(rememberHeight)
    }

    func rememberHeight(of cell: UITableViewCell) {
        guard let cell = cell as? VirtualListHostingCell,
              let id = cell.rowID?.base as? Item.ID,
              cell.hasCurrentConfiguration?() == true,
              cell.bounds.width > 0, cell.bounds.height > 0 else { return }
        measuredRowHeights[id] = .init(
            width: cell.bounds.width, height: cell.bounds.height,
            contentSizeCategory: cell.traitCollection.preferredContentSizeCategory,
            layoutDirection: cell.traitCollection.layoutDirection)
    }
}
