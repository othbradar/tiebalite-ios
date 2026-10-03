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
    var itemCount = 0
    var snapshotApplyCount = 0
    var createdCellCount = 0
    var reuseCount = 0
    var peakVisibleCellCount = 0
    var activeHostedCellCount = 0
    var peakActiveHostedCellCount = 0
    var isRestoringInitialReadingPosition = false
    var initialReadingAdjustmentCount = 0
    var viewportAdjustmentCount = 0
}

@MainActor
final class VirtualizedTableView: UITableView {
    var virtualListDiagnostics = VirtualListDiagnostics()
    var onInitialAnchorLayout: (() -> Void)?
    var onViewportLayout: (() -> Void)?
    var isPerformingLayout = false
    var hasInitialAnchorLayout: Bool { onInitialAnchorLayout != nil }

    #if UITESTING
    override var accessibilityValue: String? {
        get { virtualListDiagnostics.isRestoringInitialReadingPosition ? "initial-restoration:active" : "initial-restoration:idle" }
        set { super.accessibilityValue = newValue }
    }
    #endif

    override func layoutSubviews() {
        guard onViewportLayout != nil else {
            super.layoutSubviews()
            onInitialAnchorLayout?()
            return
        }
        guard !isPerformingLayout else { return }
        isPerformingLayout = true
        defer { isPerformingLayout = false }
        super.layoutSubviews()
        onInitialAnchorLayout?()
        onViewportLayout?()
    }
}

@MainActor
final class VirtualListHostingCell: UITableViewCell {
    var hasHostedContent = false
    var rowID: AnyHashable?
    var isDisplayed = false
    var hasCurrentConfiguration: (() -> Bool)?
    var onPrepareForReuse: (() -> Void)?

    override func prepareForReuse() {
        super.prepareForReuse()
        onPrepareForReuse?()
        onPrepareForReuse = nil
        rowID = nil
        isDisplayed = false
        hasCurrentConfiguration = nil
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
    let initialRestorationScope: AnyHashable?
    let onPrefetch: ([Item.ID]) -> Void
    let onScrollSettled: (Item.ID?) -> Void
    let onRefresh: (@MainActor () async -> Void)?
    @ViewBuilder let rowContent: (Item) -> RowContent

    init(
        items: [Item],
        backgroundColor: UIColor,
        accessibilityIdentifier: String,
        restoredAnchor: Item.ID? = nil,
        initialRestorationScope: AnyHashable? = nil,
        onPrefetch: @escaping ([Item.ID]) -> Void = { _ in },
        onScrollSettled: @escaping (Item.ID?) -> Void = { _ in },
        onRefresh: (@MainActor () async -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.backgroundColor = backgroundColor
        self.accessibilityIdentifier = accessibilityIdentifier
        self.restoredAnchor = restoredAnchor
        self.initialRestorationScope = initialRestorationScope
        self.onPrefetch = onPrefetch
        self.onScrollSettled = onScrollSettled
        self.onRefresh = onRefresh
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
        private var refreshTask: Task<Void, Never>?
        var pendingRestoredAnchor: Item.ID?
        let initialScope: AnyHashable?
        var readingRestoration: InitialReadingRestoration<Item.ID>?
        var viewportAnchor: ReadingViewportAnchor<Item.ID>?
        var isAdjustingReadingPosition = false
        var userScrollInProgress = false
        private var activeHostedCellIDs: Set<ObjectIdentifier> = []
        private let hostedCells = NSHashTable<VirtualListHostingCell>
            .weakObjects()

        init(parent: VirtualizedList) {
            self.parent = parent
            pendingRestoredAnchor = parent.restoredAnchor
            initialScope = parent.initialRestorationScope
            if parent.initialRestorationScope != nil, let target = parent.restoredAnchor {
                readingRestoration = .init(target: target)
            }
        }

        func install(on tableView: VirtualizedTableView) {
            self.tableView = tableView
            tableView.virtualListDiagnostics.isRestoringInitialReadingPosition = readingRestoration?.isActive == true
            if parent.onRefresh != nil {
                let control = UIRefreshControl()
                control.accessibilityIdentifier = parent.accessibilityIdentifier + ".refresh"
                control.addTarget(self, action: #selector(refresh), for: .valueChanged)
                tableView.refreshControl = control
            }
            tableView.delegate = self
            tableView.prefetchDataSource = self
            if pendingRestoredAnchor != nil {
                tableView.onInitialAnchorLayout = { [weak self, weak tableView] in
                    guard let tableView else { return }
                    self?.restoreAnchorIfNeeded(in: tableView)
                }
            }
            if initialScope != nil {
                tableView.onViewportLayout = { [weak self, weak tableView] in
                    guard let tableView else { return }
                    self?.maintainReadingViewport(in: tableView)
                }
            }
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
                cell.rowID = AnyHashable(itemID)
                cell.hasCurrentConfiguration = { [weak self] in self?.itemsByID[itemID] == item }
                cell.contentConfiguration = UIHostingConfiguration { content }
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
            invalidateChangedReadingScope()
            tableView.backgroundColor = parent.backgroundColor
            tableView.accessibilityIdentifier = parent.accessibilityIdentifier
            pendingItems = parent.items
            applyPendingSnapshotIfNeeded()
        }

        @objc private func refresh() {
            guard refreshTask == nil, let onRefresh = parent.onRefresh else { return }
            refreshTask = Task { @MainActor [weak self] in
                await onRefresh()
                self?.tableView?.refreshControl?.endRefreshing()
                self?.refreshTask = nil
            }
        }

        func dismantle() {
            refreshTask?.cancel()
            refreshTask = nil
            tableView?.refreshControl?.removeTarget(self, action: #selector(refresh), for: .valueChanged)
            tableView?.refreshControl = nil
            guard let tableView else {
                return
            }
            emitCurrentAnchorIfAvailable()
            stopReadingRestoration(permitsProgress: false)
            for cell in hostedCells.allObjects {
                cell.contentConfiguration = nil
                cell.onPrepareForReuse = nil
                cell.hasCurrentConfiguration = nil
                cell.rowID = nil
                cell.isDisplayed = false
            }
            hostedCells.removeAllObjects()
            activeHostedCellIDs.removeAll(keepingCapacity: false)
            tableView.virtualListDiagnostics.activeHostedCellCount = 0
            tableView.onInitialAnchorLayout = nil
            tableView.onViewportLayout = nil
            viewportAnchor = nil
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
            (cell as? VirtualListHostingCell)?.isDisplayed = true
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
            (cell as? VirtualListHostingCell)?.isDisplayed = false
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            userScrollInProgress = true
            viewportAnchor = nil
            stopReadingRestoration(permitsProgress: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard initialScope != nil, let table = tableView,
                  !isAdjustingReadingPosition, !table.isPerformingLayout else { return }
            // An explicit offset change outside layout takes precedence over the old viewport.
            viewportAnchor = nil
            if readingRestoration?.isActive == true { stopReadingRestoration(permitsProgress: true) }
        }

        func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
            scrollViewWillBeginDragging(scrollView)
            return true
        }

        func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { emitSettledAnchor() }

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
                }
            }
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

        private static var reuseIdentifier: String { "VirtualListHostingCell" }
    }

}

extension VirtualizedList {
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> VirtualizedTableView {
        let tableView = VirtualizedTableView(frame: .zero, style: .plain)
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
