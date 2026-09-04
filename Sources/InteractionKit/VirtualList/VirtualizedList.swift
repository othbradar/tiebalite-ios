import Foundation
import SwiftUI
import UIKit

struct VirtualListSnapshotPlan<ID: Hashable> {
    let removedIDs: [ID]
    let insertedIDs: [ID]
    let retainedIDs: [ID]
    let requiresFullReplacement: Bool
    let hasDuplicateIncomingIDs: Bool

    init(currentIDs: [ID], incomingIDs: [ID]) {
        let currentSet = Set(currentIDs)
        let incomingSet = Set(incomingIDs)
        removedIDs = currentIDs.filter { !incomingSet.contains($0) }
        insertedIDs = incomingIDs.filter { !currentSet.contains($0) }
        retainedIDs = incomingIDs.filter { currentSet.contains($0) }
        requiresFullReplacement = retainedIDs != currentIDs.filter {
            incomingSet.contains($0)
        }
        hasDuplicateIncomingIDs = Set(incomingIDs).count != incomingIDs.count
    }
}

struct VirtualListDiagnostics: Equatable, Sendable {
    fileprivate(set) var itemCount = 0
    fileprivate(set) var snapshotApplyCount = 0
    fileprivate(set) var createdCellCount = 0
    fileprivate(set) var reuseCount = 0
    fileprivate(set) var peakVisibleCellCount = 0
    fileprivate(set) var activeHostedCellCount = 0
    fileprivate(set) var peakActiveHostedCellCount = 0
}

@MainActor
final class VirtualizedTableView: UITableView {
    fileprivate(set) var virtualListDiagnostics = VirtualListDiagnostics()
}

@MainActor
private final class VirtualListHostingCell: UITableViewCell {
    var hasHostedContent = false
    var onPrepareForReuse: (() -> Void)?

    override func prepareForReuse() {
        super.prepareForReuse()
        onPrepareForReuse?()
        onPrepareForReuse = nil
        contentConfiguration = nil
        accessibilityIdentifier = nil
    }
}

enum VirtualListSection: Hashable {
    case content
}

@MainActor
struct VirtualizedList<Item, RowContent>: UIViewRepresentable
where Item: Identifiable & Equatable & Sendable,
      Item.ID: Hashable & Sendable,
      RowContent: View {
    let items: [Item]
    let backgroundColor: UIColor
    let accessibilityIdentifier: String
    let restoredAnchor: Item.ID?
    let onPrefetch: ([Item.ID]) -> Void
    let onScrollSettled: (Item.ID?) -> Void
    @ViewBuilder let rowContent: (Item) -> RowContent

    init(
        items: [Item],
        backgroundColor: UIColor,
        accessibilityIdentifier: String,
        restoredAnchor: Item.ID? = nil,
        onPrefetch: @escaping ([Item.ID]) -> Void = { _ in },
        onScrollSettled: @escaping (Item.ID?) -> Void = { _ in },
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.backgroundColor = backgroundColor
        self.accessibilityIdentifier = accessibilityIdentifier
        self.restoredAnchor = restoredAnchor
        self.onPrefetch = onPrefetch
        self.onScrollSettled = onScrollSettled
        self.rowContent = rowContent
    }

    final class Coordinator:
        NSObject,
        UITableViewDelegate,
        UITableViewDataSourcePrefetching {
        var parent: VirtualizedList
        weak var tableView: VirtualizedTableView?
        var dataSource:
            UITableViewDiffableDataSource<VirtualListSection, Item.ID>?
        var itemsByID: [Item.ID: Item] = [:]
        var appliedItemsByID: [Item.ID: Item] = [:]
        var pendingItems: [Item]?
        var isApplyingSnapshot = false
        var hasAppliedSnapshot = false
        private var pendingRestoredAnchor: Item.ID?
        private var activeHostedCellIDs: Set<ObjectIdentifier> = []
        private let hostedCells = NSHashTable<VirtualListHostingCell>
            .weakObjects()

        init(parent: VirtualizedList) {
            self.parent = parent
            pendingRestoredAnchor = parent.restoredAnchor
        }

        func install(on tableView: VirtualizedTableView) {
            self.tableView = tableView
            tableView.delegate = self
            tableView.prefetchDataSource = self
            tableView.register(
                VirtualListHostingCell.self,
                forCellReuseIdentifier: Self.reuseIdentifier
            )

            let dataSource = UITableViewDiffableDataSource<
                VirtualListSection,
                Item.ID
            >(tableView: tableView) { [weak self] tableView, _, itemID in
                guard let self,
                      let item = itemsByID[itemID],
                      let cell = tableView.dequeueReusableCell(
                        withIdentifier: Self.reuseIdentifier
                      ) as? VirtualListHostingCell else {
                    return nil
                }

                if cell.hasHostedContent {
                    self.tableView?.virtualListDiagnostics.reuseCount += 1
                } else {
                    cell.hasHostedContent = true
                    self.tableView?.virtualListDiagnostics
                        .createdCellCount += 1
                }
                self.tableView?.virtualListDiagnostics
                    .peakVisibleCellCount = max(
                        self.tableView?.virtualListDiagnostics
                            .peakVisibleCellCount ?? 0,
                        tableView.visibleCells.count + 1
                    )
                cell.onPrepareForReuse = { [weak self, weak cell] in
                    guard let cell else {
                        return
                    }
                    self?.markHostedContentEnded(for: cell)
                }
                self.markHostedContentStarted(for: cell)
                let content = parent.rowContent(item)
                cell.contentConfiguration = UIHostingConfiguration {
                    content
                }
                .margins(.all, 0)
                .background {
                    Color.clear
                }
                cell.backgroundColor = .clear
                cell.contentView.backgroundColor = .clear
                cell.selectionStyle = .none
                return cell
            }
            self.dataSource = dataSource
        }

        func synchronize() {
            guard let tableView else {
                return
            }
            tableView.backgroundColor = parent.backgroundColor
            tableView.accessibilityIdentifier = parent.accessibilityIdentifier
            pendingItems = parent.items
            applyPendingSnapshotIfNeeded()
        }

        func dismantle() {
            guard let tableView else {
                return
            }
            emitCurrentAnchorIfAvailable()
            for cell in hostedCells.allObjects {
                cell.contentConfiguration = nil
                cell.onPrepareForReuse = nil
            }
            hostedCells.removeAllObjects()
            activeHostedCellIDs.removeAll(keepingCapacity: false)
            tableView.virtualListDiagnostics.activeHostedCellCount = 0
            tableView.prefetchDataSource = nil
            tableView.delegate = nil
            tableView.dataSource = nil
            dataSource = nil
            itemsByID.removeAll(keepingCapacity: false)
            appliedItemsByID.removeAll(keepingCapacity: false)
            pendingItems = nil
        }

        func tableView(
            _ tableView: UITableView,
            prefetchRowsAt indexPaths: [IndexPath]
        ) {
            guard let dataSource else {
                return
            }
            let itemIDs = indexPaths.compactMap {
                dataSource.itemIdentifier(for: $0)
            }
            guard !itemIDs.isEmpty else {
                return
            }
            parent.onPrefetch(itemIDs)
        }

        func tableView(
            _ tableView: UITableView,
            willDisplay cell: UITableViewCell,
            forRowAt indexPath: IndexPath
        ) {
            guard let tableView = tableView as? VirtualizedTableView else {
                return
            }
            tableView.virtualListDiagnostics.peakVisibleCellCount = max(
                tableView.virtualListDiagnostics.peakVisibleCellCount,
                tableView.visibleCells.count
            )
        }

        func tableView(
            _ tableView: UITableView,
            didEndDisplaying cell: UITableViewCell,
            forRowAt indexPath: IndexPath
        ) {
            // Self-sizing and bounce can show this cell again before reuse.
        }

        func scrollViewDidEndDragging(
            _ scrollView: UIScrollView,
            willDecelerate decelerate: Bool
        ) {
            if !decelerate {
                emitSettledAnchor()
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            emitSettledAnchor()
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            emitSettledAnchor()
        }

        private func applyPendingSnapshotIfNeeded() {
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
                }
            }
        }

        private func restoreAnchorIfNeeded(in tableView: UITableView) {
            guard let restoredAnchor = pendingRestoredAnchor,
                  let dataSource,
                  let indexPath = dataSource.indexPath(for: restoredAnchor)
            else {
                return
            }
            pendingRestoredAnchor = nil
            tableView.scrollToRow(
                at: indexPath,
                at: .top,
                animated: false
            )
        }

        private func emitSettledAnchor() {
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

        private func emitCurrentAnchorIfAvailable() {
            guard let tableView,
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

        private func markHostedContentStarted(for cell: UITableViewCell) {
            guard let tableView else {
                return
            }
            if let hostingCell = cell as? VirtualListHostingCell {
                hostedCells.add(hostingCell)
            }
            activeHostedCellIDs.insert(ObjectIdentifier(cell))
            tableView.virtualListDiagnostics.activeHostedCellCount =
                activeHostedCellIDs.count
            tableView.virtualListDiagnostics.peakActiveHostedCellCount = max(
                tableView.virtualListDiagnostics.peakActiveHostedCellCount,
                activeHostedCellIDs.count
            )
        }

        private func markHostedContentEnded(for cell: UITableViewCell) {
            activeHostedCellIDs.remove(ObjectIdentifier(cell))
            tableView?.virtualListDiagnostics.activeHostedCellCount =
                activeHostedCellIDs.count
        }

        private static var reuseIdentifier: String {
            "VirtualListHostingCell"
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> VirtualizedTableView {
        let tableView = VirtualizedTableView(
            frame: .zero,
            style: .plain
        )
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = true
        tableView.keyboardDismissMode = .interactive
        tableView.sectionHeaderTopPadding = 0
        context.coordinator.install(on: tableView)
        context.coordinator.synchronize()
        return tableView
    }

    func updateUIView(
        _ tableView: VirtualizedTableView,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.synchronize()
    }

    static func dismantleUIView(
        _ tableView: VirtualizedTableView,
        coordinator: Coordinator
    ) {
        coordinator.dismantle()
    }
}
