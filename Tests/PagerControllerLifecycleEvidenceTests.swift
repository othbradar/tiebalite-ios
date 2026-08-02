import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct PagerControllerLifecycleEvidenceTests {
    @Test
    func sameGenerationDoesNotRebuildExpensiveCachedContent() throws {
        let selection = PagerTestBox<String?>("p2")
        var generation: UInt64 = 1
        let buildCount = PagerTestBox(0)
        let binding = makeBinding(selection: selection)
        var pager = makeCountingPager(
            selection: binding,
            generation: generation,
            buildCount: buildCount
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        materializeNeighbors(coordinator: coordinator, controller: controller)
        #expect(buildCount.value == 3)

        for _ in 0..<100 {
            pager = makeCountingPager(
                selection: binding,
                generation: generation,
                buildCount: buildCount
            )
            coordinator.parent = pager
            coordinator.synchronize(controller)
        }
        #expect(buildCount.value == 3)

        generation += 1
        pager = makeCountingPager(
            selection: binding,
            generation: generation,
            buildCount: buildCount
        )
        coordinator.parent = pager
        coordinator.synchronize(controller)
        #expect(buildCount.value == 6)
        #expect(coordinator.cachedControllerCount == 3)

        generation -= 1
        pager = makeCountingPager(
            selection: binding,
            generation: generation,
            buildCount: buildCount
        )
        coordinator.parent = pager
        coordinator.synchronize(controller)
        #expect(buildCount.value == 6)
        #expect(
            coordinator.diagnosticSnapshot().geometry?.stateGeneration == 2
        )
        coordinator.dismantle(controller)
    }

    @Test
    func cachedIdentitySurvivesReturnRefreshResizeAndProjection() throws {
        let selection = PagerTestBox<String?>("p2")
        var generation: UInt64 = 1
        let binding = makeBinding(selection: selection)
        var pager = makePager(
            selection: binding,
            generation: generation
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        materializeNeighbors(coordinator: coordinator, controller: controller)
        let p2Sequence = try #require(
            coordinator.diagnosticSnapshot().visibleControllerSequence
        )

        selection.value = "p3"
        pager = makePager(selection: binding, generation: generation)
        coordinator.parent = pager
        coordinator.synchronize(controller)
        selection.value = "p2"
        coordinator.parent = makePager(
            selection: binding,
            generation: generation
        )
        coordinator.synchronize(controller)
        #expect(
            coordinator.diagnosticSnapshot().visibleControllerSequence
                == p2Sequence
        )

        generation += 1
        coordinator.parent = makePager(
            selection: binding,
            generation: generation
        )
        coordinator.synchronize(controller)
        controller.view.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        controller.view.layoutIfNeeded()
        #expect(
            coordinator.diagnosticSnapshot().visibleControllerSequence
                == p2Sequence
        )
        coordinator.dismantle(controller)
    }

    @Test
    func evictionReleasesHostAndReturnCreatesANewLifecycle() async throws {
        let selection = PagerTestBox<String?>("p2")
        let binding = makeBinding(selection: selection)
        var pager = makePager(selection: binding, generation: 1)
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        let oldSequence = try #require(
            coordinator.diagnosticSnapshot().visibleControllerSequence
        )
        weak var weakP2: UIViewController?
        weakP2 = coordinator.cachedController(for: "p2")

        autoreleasepool {
            selection.value = "p4"
            pager = makePager(selection: binding, generation: 1)
            coordinator.parent = pager
            coordinator.synchronize(controller)
        }
        #expect(
            coordinator.diagnosticSnapshot().orphanChildControllerCount == 0
        )
        await Task.yield()
        #expect(weakP2 == nil)

        selection.value = "p2"
        coordinator.parent = makePager(selection: binding, generation: 1)
        coordinator.synchronize(controller)
        let newSequence = try #require(
            coordinator.diagnosticSnapshot().visibleControllerSequence
        )
        #expect(newSequence != oldSequence)
        #expect(selection.value == "p2")
        coordinator.dismantle(controller)
    }

    @Test
    func staleHostsAndRecursiveAdjacencyCannotPolluteTheCache() throws {
        let selection = PagerTestBox<String?>("p50")
        let pages = (0..<100).map { "p\($0)" }
        let binding = makeBinding(selection: selection)
        let pager = makePager(
            pages: pages,
            selection: binding,
            generation: 1
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        let source = try #require(controller.viewControllers?.first)
        let target = try #require(
            coordinator.pageViewController(
                controller,
                viewControllerAfter: source
            )
        )
        coordinator.pageViewController(
            controller,
            willTransitionTo: [target]
        )
        let p52 = try #require(
            coordinator.pageViewController(
                controller,
                viewControllerAfter: target
            )
        )
        let outsideParticipant = coordinator.pageViewController(
            controller,
            viewControllerAfter: p52
        )
        #expect(outsideParticipant == nil)
        #expect(coordinator.cachedControllerCount <= 4)

        coordinator.lastGestureTrace = endedGestureTrace()
        coordinator.pageViewController(
            controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: false
        )
        selection.value = "p0"
        coordinator.parent = makePager(
            pages: pages,
            selection: binding,
            generation: 1
        )
        coordinator.synchronize(controller)
        #expect(
            coordinator.pageViewController(
                controller,
                viewControllerAfter: source
            ) == nil
        )
        coordinator.dismantle(controller)
    }

    @Test
    func oneHundredPagesKeepCacheAndCreationCountsBounded() {
        let pages = (0..<100).map { "p\($0)" }
        let selection = PagerTestBox<String?>(pages[0])
        let buildCount = PagerTestBox(0)
        let binding = makeBinding(selection: selection)
        var pager = makeCountingPager(
            pages: pages,
            selection: binding,
            generation: 1,
            buildCount: buildCount
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)

        for pageID in pages {
            selection.value = pageID
            pager = makeCountingPager(
                pages: pages,
                selection: binding,
                generation: 1,
                buildCount: buildCount
            )
            coordinator.parent = pager
            coordinator.synchronize(controller)
            materializeNeighbors(
                coordinator: coordinator,
                controller: controller
            )
            let snapshot = coordinator.diagnosticSnapshot()
            #expect(snapshot.controllerCount <= 3)
            #expect(snapshot.orphanChildControllerCount == 0)
            #expect(snapshot.committedID == pageID)
            #expect(snapshot.visiblePageID == pageID)
            #expect(
                snapshot.visibleControllerSequence
                    == snapshot.cachedControllerSequences[pageID]
            )
            #expect(snapshot.activeCallbackDepth == 0)
            #expect(!snapshot.teardownSentinelVisible)
        }

        let final = coordinator.diagnosticSnapshot()
        #expect(final.createdControllerCount == 100)
        #expect(buildCount.value == 100)
        coordinator.dismantle(controller)
    }

    private func makeBinding(
        selection: PagerTestBox<String?>
    ) -> Binding<String?> {
        Binding(
            get: { selection.value },
            set: { selection.value = $0 }
        )
    }

    private func makeController() -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        return controller
    }

    private func makePager(
        pages: [String] = ["p0", "p1", "p2", "p3", "p4"],
        selection: Binding<String?>,
        generation: UInt64
    ) -> PagerContainer<String, Text> {
        PagerContainer(
            pageIDs: pages,
            selection: selection,
            backgroundColor: .black,
            reduceMotion: true,
            contentGeneration: { _ in generation },
            content: { Text($0) }
        )
    }

    private func makeCountingPager(
        pages: [String] = ["p0", "p1", "p2", "p3", "p4"],
        selection: Binding<String?>,
        generation: UInt64,
        buildCount: PagerTestBox<Int>
    ) -> PagerContainer<String, Text> {
        PagerContainer(
            pageIDs: pages,
            selection: selection,
            backgroundColor: .black,
            reduceMotion: true,
            contentGeneration: { _ in generation },
            content: { pageID in
                buildCount.value += 1
                return Text(pageID)
            }
        )
    }

    private func materializeNeighbors(
        coordinator: PagerContainer<String, Text>.Coordinator,
        controller: UIPageViewController
    ) {
        guard let visible = controller.viewControllers?.first else {
            return
        }
        _ = coordinator.pageViewController(
            controller,
            viewControllerBefore: visible
        )
        _ = coordinator.pageViewController(
            controller,
            viewControllerAfter: visible
        )
    }

    private func endedGestureTrace() -> PagerGestureTrace {
        gestureTrace(.ended)
    }

    private func gestureTrace(
        _ terminalPhase: PagerPanTerminalPhase
    ) -> PagerGestureTrace {
        var trace = PagerGestureTrace()
        trace.finish(
            phase: terminalPhase,
            progress: 0.75,
            velocityPagesPerSecond: 1
        )
        return trace
    }
}

extension PagerControllerLifecycleEvidenceTests {
    @Test
    func reinstallAndDismantleReleaseDelegatesChildrenAndCoordinator() {
        weak var weakCoordinator: PagerContainer<String, Text>.Coordinator?
        weak var weakHost: UIViewController?

        autoreleasepool {
            let selection = PagerTestBox<String?>("p2")
            let binding = makeBinding(selection: selection)
            let pager = PagerContainer(
                pageIDs: ["p1", "p2", "p3"],
                selection: binding,
                backgroundColor: .black,
                reduceMotion: true,
                contentGeneration: { _ in 1 },
                content: { Text($0) }
            )
            let coordinator = pager.makeCoordinator()
            let first = makeController()
            let second = makeController()
            weakCoordinator = coordinator
            coordinator.install(on: first)
            coordinator.synchronize(first)
            weakHost = first.viewControllers?.first

            coordinator.install(on: second)
            #expect(first.delegate == nil)
            #expect(first.dataSource == nil)
            coordinator.synchronize(second)
            coordinator.dismantle(second)
            #expect(second.delegate == nil)
            #expect(second.dataSource == nil)
            #expect(second.viewControllers?.count == 1)
            #expect(
                second.viewControllers?.first
                    is PagerTeardownViewController
            )
        }

        #expect(weakHost == nil)
        #expect(weakCoordinator == nil)
    }

    @Test
    func settledDiagnosticTaskReleasesAndDismantleCancelsPendingWork() async {
        let selection = PagerTestBox<String?>("p2")
        let snapshotCount = PagerTestBox(0)
        let pager = PagerContainer(
            pageIDs: ["p1", "p2", "p3"],
            selection: makeBinding(selection: selection),
            backgroundColor: .black,
            reduceMotion: true,
            onSettledSnapshot: { _ in
                snapshotCount.value += 1
            },
            content: { Text($0) }
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        #expect(coordinator.settledSnapshotTask != nil)
        await drainSettledSnapshotTasks(coordinator)
        #expect(snapshotCount.value == 1)
        #expect(coordinator.settledSnapshotTask == nil)
        #expect(coordinator.pagerContentOffsetObservation != nil)
        #expect(coordinator.observedPagerScrollView != nil)

        coordinator.scheduleSettledSnapshot()
        #expect(coordinator.settledSnapshotTask != nil)
        await drainSettledSnapshotTasks(coordinator)
        #expect(snapshotCount.value == 1)
        #expect(coordinator.settledSnapshotTask == nil)

        coordinator.scheduleSettledSnapshot()
        let cancelledTask = coordinator.settledSnapshotTask
        #expect(cancelledTask != nil)
        coordinator.dismantle(controller)
        #expect(coordinator.settledSnapshotTask == nil)
        #expect(coordinator.pagerContentOffsetObservation == nil)
        #expect(coordinator.observedPagerScrollView == nil)
        await cancelledTask?.value
        #expect(snapshotCount.value == 1)
    }

    @Test
    func dismantleCancelsPendingSelectionCommitWithoutMutation() async {
        let selection = PagerTestBox<String?>("p2")
        let pager = PagerContainer(
            pageIDs: ["p1", "p2", "p3"],
            selection: makeBinding(selection: selection),
            backgroundColor: .black,
            reduceMotion: true,
            content: { Text($0) }
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeController()
        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        coordinator.scheduleSelectionCommit("p3")
        let pendingCommit = coordinator.selectionCommitTask
        #expect(pendingCommit != nil)
        coordinator.dismantle(controller)
        #expect(coordinator.selectionCommitTask == nil)
        await pendingCommit?.value
        #expect(selection.value == "p2")
    }

    private func drainSettledSnapshotTasks(
        _ coordinator: PagerContainer<String, Text>.Coordinator
    ) async {
        var observedTaskGenerations = 0
        while let pendingTask = coordinator.settledSnapshotTask {
            observedTaskGenerations += 1
            #expect(observedTaskGenerations <= 8)
            guard observedTaskGenerations <= 8 else {
                return
            }
            await pendingTask.value
        }
    }
}

private final class PagerTestBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
