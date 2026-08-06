import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct Stage15ThreadListVirtualizationTests {
    @Test
    func threadRowsUseOnlyStableBusinessIdentity() throws {
        let seed = try #require(
            FixtureReadingCatalog.forumThreadSeeds.first { seed in
                seed.threadID == 140_006
            }
        )
        let snapshot = FixtureThreadReaderPages.firstPage(from: seed)
        let presentation = ThreadReaderListPresentation(
            snapshot: snapshot,
            pagination: .loadMore(nextPage: 2)
        )
        let postIDs = snapshot.posts.map(\.document.source.postID)

        let expectedRows: [ThreadReaderRowID] = [
            .header(threadID: snapshot.threadID),
            .firstPost(threadID: snapshot.threadID, postID: postIDs[0])
        ] + postIDs.dropFirst().map { postID in
            .post(threadID: snapshot.threadID, postID: postID)
        } + [.loadMore(threadID: snapshot.threadID, page: 2)]
        #expect(presentation.rows.map(\.id) == expectedRows)
        #expect(Set(presentation.rows.map(\.id)).count == presentation.rows.count)
        #expect(presentation.prefetchRowIDs == Set(expectedRows.dropLast(1).suffix(4)))

        let secondFloor = try #require(
            presentation.rows.compactMap(\.post).first { row in
                row.floorNumber == 2
            }
        )
        #expect(secondFloor.inlineSubposts.count == 2)
        #expect(secondFloor.inlineSubposts.map(\.id).count == 2)
        #expect(secondFloor.remainingSubpostCount == 2)
        #expect(secondFloor.totalSubpostCount == 4)
    }

    @Test
    func diffablePlanAppendsRowsWithoutReplacingRetainedIdentity() {
        let current: [Int64] = [1, 2, 9]
        let incoming: [Int64] = [1, 2, 3, 4, 10]
        let plan = VirtualListSnapshotPlan(
            currentIDs: current,
            incomingIDs: incoming
        )

        #expect(plan.removedIDs == [9])
        #expect(plan.insertedIDs == [3, 4, 10])
        #expect(plan.retainedIDs == [1, 2])
        #expect(!plan.requiresFullReplacement)
        #expect(!plan.hasDuplicateIncomingIDs)
    }

    @Test
    func fivePagedFixtureBuildsOneThousandUniqueRowsIncrementally() async throws {
        let repository = Stage15LongThreadFixtureRepository(
            threadID: 990_015,
            totalPostCount: 1_000,
            pageSize: 200
        )
        let store = ThreadReaderStore(
            threadID: 990_015,
            repository: repository
        )

        await store.loadIfNeeded()
        let first = try #require(store.state.snapshot)
        let retained = first.posts
        #expect(first.posts.count == 200)

        for expectedCount in [400, 600, 800, 1_000] {
            await store.loadNextPage()
            #expect(store.state.snapshot?.posts.count == expectedCount)
            #expect(store.state.snapshot?.posts.prefix(200).elementsEqual(retained) == true)
        }

        let final = try #require(store.state.snapshot)
        #expect(!final.hasMore)
        #expect(Set(final.posts.map(\.document.source.postID)).count == 1_000)
        #expect(store.listPresentation?.postRowCount == 1_000)
        #expect(await repository.requestedPageNumbers() == [0, 2, 3, 4, 5])

        await store.loadNextPage()
        #expect(await repository.requestedPageNumbers() == [0, 2, 3, 4, 5])
    }

    @Test
    func tableVirtualizesOneThousandRowsAndReleasesItsDataSource() async throws {
        let anchor = Stage15VirtualListTestBox<Int?>(nil)
        let prefetched = Stage15VirtualListTestBox<[Int]>([])
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        var list = makeList(
            count: 200,
            anchor: anchor,
            prefetched: prefetched
        )
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(
            frame: window.bounds,
            style: .plain
        )
        window.addSubview(table)
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        await waitForItems(200, coordinator: coordinator)

        for count in [400, 600, 800, 1_000] {
            list = makeList(
                count: count,
                anchor: anchor,
                prefetched: prefetched
            )
            coordinator.parent = list
            coordinator.synchronize()
            await waitForItems(count, coordinator: coordinator)
            #expect(
                coordinator.dataSource?.snapshot().itemIdentifiers
                    .prefix(200)
                    .elementsEqual(0..<200) == true
            )
        }

        for row in [999, 499, 0] {
            table.scrollToRow(
                at: IndexPath(row: row, section: 0),
                at: .middle,
                animated: false
            )
            table.layoutIfNeeded()
            await Task.yield()
            #expect(table.indexPathsForVisibleRows?.contains(where: {
                $0.row == row
            }) == true)
        }

        coordinator.tableView(
            table,
            prefetchRowsAt: [IndexPath(row: 997, section: 0)]
        )
        #expect(prefetched.value == [997])
        coordinator.scrollViewDidEndDecelerating(table)
        #expect(anchor.value != nil)

        let diagnostics = table.virtualListDiagnostics
        #expect(diagnostics.itemCount == 1_000)
        #expect(diagnostics.reuseCount > 0)
        #expect(diagnostics.peakVisibleCellCount > 0)
        #expect(diagnostics.peakActiveHostedCellCount > 0)
        #expect(
            diagnostics.peakActiveHostedCellCount
                <= diagnostics.createdCellCount
        )
        #expect(
            diagnostics.activeHostedCellCount
                <= diagnostics.peakActiveHostedCellCount
        )
        #expect(
            diagnostics.createdCellCount
                <= diagnostics.peakVisibleCellCount * 4
        )

        coordinator.dismantle()
        table.removeFromSuperview()
        #expect(coordinator.dataSource == nil)
        #expect(table.dataSource == nil)
        #expect(table.delegate == nil)
        #expect(table.prefetchDataSource == nil)
        #expect(table.virtualListDiagnostics.activeHostedCellCount == 0)
    }

    @Test
    func dismantleDoesNotRetainTheTable() {
        let anchor = Stage15VirtualListTestBox<Int?>(nil)
        let prefetched = Stage15VirtualListTestBox<[Int]>([])
        weak var releasedTableView: VirtualizedTableView?

        autoreleasepool {
            let list = makeList(
                count: 20,
                anchor: anchor,
                prefetched: prefetched
            )
            let coordinator = list.makeCoordinator()
            let table = VirtualizedTableView(
                frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                style: .plain
            )
            releasedTableView = table
            coordinator.install(on: table)
            coordinator.dismantle()
            #expect(coordinator.dataSource == nil)
        }

        #expect(releasedTableView == nil)
    }

    @Test
    func didEndDisplayingDoesNotBlankAHostedCellBeforeReuse() async throws {
        let anchor = Stage15VirtualListTestBox<Int?>(nil)
        let prefetched = Stage15VirtualListTestBox<[Int]>([])
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        let list = makeList(
            count: 20,
            anchor: anchor,
            prefetched: prefetched
        )
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(
            frame: window.bounds,
            style: .plain
        )
        window.addSubview(table)
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        await waitForItems(20, coordinator: coordinator)
        table.layoutIfNeeded()

        let indexPath = IndexPath(row: 0, section: 0)
        let cell = try #require(table.cellForRow(at: indexPath))
        #expect(cell.contentConfiguration != nil)

        coordinator.tableView(
            table,
            didEndDisplaying: cell,
            forRowAt: indexPath
        )

        #expect(cell.contentConfiguration != nil)
        coordinator.dismantle()
    }

    @Test
    func preparingForReuseCancelsTheHostedRowTask() async throws {
        let barrier = HarnessControlledBarrier()
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        let list = VirtualizedList(
            items: (0..<20).map(Stage15VirtualListTestItem.init),
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage15.task-list",
            rowContent: { item in
                Stage15VirtualListTaskRow(item: item, barrier: barrier)
            }
        )
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(
            frame: window.bounds,
            style: .plain
        )
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        await waitForItems(20, coordinator: coordinator)

        for _ in 0..<1_000 {
            guard await barrier.pendingArrivals().isEmpty else {
                break
            }
            await Task.yield()
        }
        let activeBeforeReuse = await barrier.pendingArrivals().count
        #expect(activeBeforeReuse > 0)
        let cell = try #require(table.visibleCells.first)

        cell.prepareForReuse()

        for _ in 0..<1_000 {
            if await barrier.pendingArrivals().count < activeBeforeReuse {
                break
            }
            await Task.yield()
        }
        #expect(await barrier.pendingArrivals().count < activeBeforeReuse)
        #expect(cell.contentConfiguration == nil)

        coordinator.dismantle()
        for _ in 0..<1_000 {
            guard !(await barrier.pendingArrivals().isEmpty) else {
                break
            }
            await Task.yield()
        }
        #expect(await barrier.pendingArrivals().isEmpty)
    }

    private func makeList(
        count: Int,
        anchor: Stage15VirtualListTestBox<Int?>,
        prefetched: Stage15VirtualListTestBox<[Int]>
    ) -> VirtualizedList<
        Stage15VirtualListTestItem,
        Stage15VirtualListTestRow
    > {
        VirtualizedList(
            items: (0..<count).map(Stage15VirtualListTestItem.init),
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage15.virtual-list",
            onPrefetch: { prefetched.value = $0 },
            onScrollSettled: { anchor.value = $0 },
            rowContent: { item in
                Stage15VirtualListTestRow(item: item)
            }
        )
    }

    private func waitForItems<RowContent: View>(
        _ expectedCount: Int,
        coordinator: VirtualizedList<
            Stage15VirtualListTestItem,
            RowContent
        >.Coordinator
    ) async {
        for _ in 0..<100 {
            if coordinator.dataSource?.snapshot().numberOfItems
                == expectedCount {
                return
            }
            await Task.yield()
        }
    }
}

private struct Stage15VirtualListTestItem: Identifiable, Equatable, Sendable {
    let id: Int

    init(_ id: Int) {
        self.id = id
    }
}

private struct Stage15VirtualListTestRow: View {
    let item: Stage15VirtualListTestItem

    var body: some View {
        Text("Fixture row \(item.id)")
            .frame(maxWidth: .infinity, minHeight: 72)
    }
}

private struct Stage15VirtualListTaskRow: View {
    let item: Stage15VirtualListTestItem
    let barrier: HarnessControlledBarrier

    var body: some View {
        Text("Fixture task row \(item.id)")
            .frame(maxWidth: .infinity, minHeight: 72)
            .task {
                try? await barrier.arrive()
            }
    }
}

@MainActor
private final class Stage15VirtualListTestBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
