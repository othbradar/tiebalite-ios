import Foundation
import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct U06P1ForumRefreshTests {
    @Test
    func responseDuringDragKeepsCachedRowsUntilStableTop() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("u06p1-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U06P1ForumSource()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory))
        let seed = ForumHomeStore(route: route, repository: repository)
        await seed.synchronize(with: route)
        await seed.loadNextPage()
        await seed.saveReadingPosition()
        let previous = try #require(seed.state.snapshot)
        await source.suspendNext()
        let store = ForumHomeStore(route: route, repository: repository)
        let request = Task { await store.synchronize(with: route) }
        try await source.started.wait()
        let list = makeList(store)
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), style: .plain)
        table.rowHeight = 90
        let window = UIWindow(frame: table.frame)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(table)
        window.makeKeyAndVisible()
        defer { coordinator.dismantle(); window.isHidden = true }
        coordinator.install(on: table)
        coordinator.synchronize()
        for _ in 0..<100 where !coordinator.hasAppliedSnapshot { await Task.yield() }
        #expect(coordinator.hasAppliedSnapshot)
        table.layoutIfNeeded()
        coordinator.scrollViewWillBeginDragging(table)
        #expect(store.scrollAnchor == nil)
        source.release.succeed(())
        await request.value
        #expect(store.state.snapshot == previous)
        #expect(store.state.snapshot?.currentPage == 2)
        coordinator.parent = makeList(store)
        coordinator.synchronize()
        for _ in 0..<100 where coordinator.refreshCommitTask != nil { await Task.yield() }
        #expect(coordinator.refreshViewport == .dragging)
        #expect(store.state.snapshot == previous)

        table.contentOffset.y = 300
        coordinator.scrollViewDidEndDragging(table, willDecelerate: true)
        #expect(store.pendingRefreshCommit?.takeRows(.decelerating) == nil)
        #expect(store.state.snapshot == previous)
        coordinator.scrollViewDidEndDecelerating(table)
        for _ in 0..<100 where coordinator.refreshCommitTask != nil { await Task.yield() }
        #expect(coordinator.refreshViewport == .settled(isAtTop: false))
        #expect(store.state.snapshot == previous)

        // A top notification queued before another gesture must re-read UIKit at commit.
        table.contentOffset.y = -table.adjustedContentInset.top
        coordinator.scrollViewDidScroll(table)
        coordinator.scrollViewWillBeginDragging(table)
        for _ in 0..<100 where coordinator.refreshCommitTask != nil { await Task.yield() }
        #expect(store.state.snapshot == previous)
        coordinator.scrollViewDidEndDragging(table, willDecelerate: false)
        for _ in 0..<100 where store.state.snapshot?.currentPage != 1 { await Task.yield() }
        #expect(store.state.snapshot?.currentPage == 1)
        #expect(store.state.snapshot?.threads.first?.title.hasPrefix("刷新2") == true)
        #expect(store.pendingRefreshCommit == nil)
        #expect(coordinator.dataSource?.snapshot().itemIdentifiers.contains(.thread(140_103)) == false)
        #expect(await source.count == 3)
    }

    @Test
    func staticTopAndManualRefreshWaitForUsableViewportAndKeepFailureContent() async throws {
        let source = U06P1ForumSource()
        let route = try #require(ForumRoute("Swift开发"))
        let store = ForumHomeStore(route: route, repository: source)
        await store.synchronize(with: route)
        let previous = store.state.snapshot
        #expect(previous != nil) // A first load has no viewport and still displays.
        await store.reload()
        let pending = try #require(store.pendingRefreshCommit)
        for state in [VirtualListRefreshViewport.unavailable, .tracking, .dragging, .decelerating] {
            #expect(pending.takeRows(state) == nil)
            #expect(store.state.snapshot == previous)
        }
        #expect(pending.takeRows(.settled(isAtTop: false)) != nil) // Explicit refresh may finish off-top.
        #expect(store.state.snapshot?.threads.first?.title.hasPrefix("刷新2") == true)
        #expect(pending.takeRows(.settled(isAtTop: true)) == nil) // Consumed only once.
        let refreshed = store.state.snapshot
        await source.setFailure()
        await store.reload()
        #expect(store.state.snapshot == refreshed)
        #expect(store.pendingRefreshCommit == nil)
        guard case .refreshFailure = store.state else { Issue.record("Missing retained refresh failure"); return }
    }

    @Test
    func pendingRefreshCannotCrossSortAccountOrCancellation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("u06p1-scope-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = U06P1ForumSource()
        let scope = Scope()
        let repository = CachedForumHomeRepository(source: source, cache: ContentPageCache(directory: directory),
                                                   context: { scope.context })
        let route = try #require(ForumRoute("Swift开发"))
        let store = ForumHomeStore(route: route, repository: repository)
        await store.synchronize(with: route)
        await store.reload()
        let oldSort = try #require(store.pendingRefreshCommit)
        await store.changeQuery(.latest(.creation))
        #expect(oldSort.takeRows(.settled(isAtTop: true)) == nil)
        #expect(store.query == .latest(.creation))
        await store.reload()
        let oldAccount = try #require(store.pendingRefreshCommit)
        scope.context = .init(namespace: "u06p1-other", revision: 1)
        #expect(oldAccount.takeRows(.settled(isAtTop: true)) == nil)
        await store.synchronize(with: route)
        await store.reload()
        let cancelled = try #require(store.pendingRefreshCommit)
        store.cancel()
        #expect(cancelled.takeRows(.settled(isAtTop: true)) == nil)
    }

    private func makeList(_ store: ForumHomeStore) -> VirtualizedList<ForumHomeRowModel, Text> {
        VirtualizedList(items: store.listPresentation?.rows ?? [], backgroundColor: .systemBackground,
                        accessibilityIdentifier: "u06p1.forum",
                        contentVersion: VirtualListContentRevision(owner: ObjectIdentifier(store), revision: store.listRevision),
                        onScrollSettled: store.setScrollAnchor,
                        pendingRefresh: store.pendingRefreshCommit, rowContent: { Text(String(describing: $0.id)) })
    }

    private final class Scope { var context = ContentCacheContext.anonymous }
}

@MainActor
struct U06P1RefreshViewportTests {
    @Test
    func insetGeometrySnapshotQueueAndStaticTopCommitWithoutAnotherGesture() async throws {
        let rows = (1...20).map(Row.init)
        let original = VirtualizedList(items: rows, backgroundColor: .systemBackground,
                                       accessibilityIdentifier: "u06p1.geometry", rowContent: { Text(String($0.id)) })
        let coordinator = original.makeCoordinator()
        let table = VirtualizedTableView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), style: .plain)
        table.rowHeight = 90
        table.contentInsetAdjustmentBehavior = .never
        table.contentInset.top = 31
        coordinator.install(on: table)
        coordinator.synchronize()
        #expect(coordinator.refreshViewport == .unavailable)
        #expect(table.onRefreshViewportChange == nil) // Other pages remain opt-out.
        let window = UIWindow(frame: table.frame)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(table)
        window.makeKeyAndVisible()
        defer { coordinator.dismantle(); window.isHidden = true }
        for _ in 0..<100 where !coordinator.hasAppliedSnapshot { await Task.yield() }
        #expect(coordinator.hasAppliedSnapshot)
        table.layoutIfNeeded()
        for offset in [-90.0, 5.0, table.contentSize.height - table.bounds.height + 20] {
            table.contentOffset.y = offset
            #expect(coordinator.refreshViewport == .settled(isAtTop: false))
        }
        table.contentOffset.y = -31
        #expect(coordinator.refreshViewport == .settled(isAtTop: true))
        let control = UIRefreshControl()
        table.refreshControl = control
        control.beginRefreshing()
        guard case .settled = coordinator.refreshViewport else {
            Issue.record("Refresh control spinning must not block a settled viewport")
            return
        }
        table.contentOffset.y = -table.adjustedContentInset.top

        var commits = 0
        let replacement = VirtualListRefreshCommit<Row> { viewport in
            guard viewport == .settled(isAtTop: true), commits == 0 else { return nil }
            commits += 1
            return [Row(id: 99)]
        }
        coordinator.isApplyingSnapshot = true
        coordinator.parent = VirtualizedList(items: rows, backgroundColor: .systemBackground,
                                             accessibilityIdentifier: "u06p1.geometry", pendingRefresh: replacement,
                                             rowContent: { Text(String($0.id)) })
        coordinator.synchronize()
        for _ in 0..<100 where coordinator.refreshCommitTask != nil { await Task.yield() }
        #expect(commits == 0)
        #expect(coordinator.refreshViewport == .unavailable)
        // The previous apply completes; the newest queued rows are drained first.
        coordinator.isApplyingSnapshot = false
        coordinator.applyPendingSnapshotIfNeeded()
        coordinator.refreshViewportChanged()
        for _ in 0..<100 where commits == 0 { await Task.yield() }
        #expect(commits == 1)
        #expect(coordinator.dataSource?.snapshot().itemIdentifiers == [99])
        coordinator.dismantle()
        #expect(table.onRefreshViewportChange == nil)
        #expect(coordinator.refreshCommitTask == nil)
    }

    private struct Row: Identifiable, Equatable, Sendable { let id: Int }
}

private actor U06P1ForumSource: ForumHomeRepository {
    let started = HarnessContinuationGate<Void>()
    let release = HarnessContinuationGate<Void>()
    private let source = R05ForumFixture(tracksRefreshes: true)
    private var suspended = false
    private var fails = false
    private(set) var count = 0

    func suspendNext() { suspended = true }
    func setFailure() { fails = true }

    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        count += 1
        if suspended {
            suspended = false
            started.succeed(())
            try await release.wait()
        }
        if fails { throw ForumHomeLoadFailure.unavailable }
        return try await source.loadForumHomePage(request)
    }
}
