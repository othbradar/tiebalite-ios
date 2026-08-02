import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct PagerCallbackIdentityGenerationTests {
    @Test
    func samePageIDWrongPreviousHostDoesNotConsumeContext() throws {
        let harness = makeHarness()
        let hosts = try startTransition(harness)
        harness.coordinator.lastGestureTrace = endedTrace()
        let source = try #require(
            hosts.source as? PagerHostingController<String, Text>
        )
        let rogueSource = rogueHost(matching: source)

        deliverCompletedDelegate(
            harness,
            previous: rogueSource
        )

        expectPending(
            harness,
            ignoredReason: .previousControllerMismatch
        )
        deliverCompletedDelegate(harness, previous: hosts.source)
        expectCommitted(harness)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func samePageIDWrongVisibleHostDoesNotConsumeContext() throws {
        let harness = makeHarness()
        let hosts = try startTransition(harness)
        let target = try #require(
            hosts.target as? PagerHostingController<String, Text>
        )
        let rogueTarget = rogueHost(matching: target)
        harness.controller.setViewControllers(
            [rogueTarget],
            direction: .forward,
            animated: false
        )
        harness.coordinator.lastGestureTrace = endedTrace()

        deliverCompletedDelegate(harness, previous: hosts.source)

        expectPending(
            harness,
            ignoredReason: .visibleControllerMismatch
        )
        harness.controller.setViewControllers(
            [hosts.target],
            direction: .forward,
            animated: false
        )
        deliverCompletedDelegate(harness, previous: hosts.source)
        expectCommitted(harness)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func wrongDirectionDoesNotConsumeContext() throws {
        let harness = makeHarness()
        let hosts = try startTransition(harness)
        harness.coordinator.lastGestureTrace = endedTrace()
        harness.coordinator.inputDirectionSign = 1

        deliverCompletedDelegate(harness, previous: hosts.source)

        expectPending(harness, ignoredReason: .directionMismatch)
        harness.coordinator.inputDirectionSign = -1
        deliverCompletedDelegate(harness, previous: hosts.source)
        expectCommitted(harness)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func awayAndBackExternalGenerationInvalidatesOldTransition() throws {
        let harness = makeHarness()
        let hosts = try startTransition(harness)
        let token = try #require(
            harness.coordinator.pendingCallbackContext?.transition.token
        )
        harness.externalGeneration.value &+= 1

        harness.coordinator.synchronize(harness.controller)

        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.pendingCallbackContext != nil)
        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(
            harness.controller.viewControllers?.first === hosts.target
        )

        harness.coordinator.lastGestureTrace = endedTrace()
        deliverCompletedDelegate(harness, previous: hosts.source)

        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.pendingCallbackContext == nil)
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.context
                .transition.token == token
        )
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == .invalidated
        )
        #expect(
            harness.coordinator.lastResolvedRendezvous?.reason
                == .externalSelectionChanged
        )
        #expect(
            harness.coordinator.diagnosticSnapshot().visiblePageID == "p2"
        )

        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func newerExternalSelectionWinsWithoutPagerSelectionJitter() throws {
        let harness = makeHarness()
        let hosts = try startTransition(harness)
        harness.selection.value = "p4"
        harness.externalGeneration.value &+= 1

        harness.coordinator.synchronize(harness.controller)

        #expect(harness.selection.value == "p4")
        #expect(harness.coordinator.state.committedID == "p2")
        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(harness.coordinator.pendingCallbackContext != nil)
        #expect(
            harness.controller.viewControllers?.first === hosts.target
        )

        harness.coordinator.lastGestureTrace = endedTrace()
        deliverCompletedDelegate(harness, previous: hosts.source)

        let snapshot = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p4")
        #expect(snapshot.committedID == "p4")
        #expect(snapshot.visiblePageID == "p4")
        #expect(snapshot.resolvedTransitionCount == 1)
        #expect(harness.coordinator.lastResolvedRendezvous?.result == .invalidated)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func replacingPagerPanRecognizerInvalidatesActiveContext() throws {
        let harness = makeHarness()
        _ = try startTransition(harness)

        harness.coordinator.installPagerPanObserver(
            UIPanGestureRecognizer()
        )

        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.state.transition == nil)
        #expect(harness.coordinator.pendingCallbackContext == nil)
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == .invalidated
        )
        #expect(
            harness.coordinator.lastResolvedRendezvous?.didPublish == false
        )
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func committedPageRejectsSameIDStaleVisibleHost() throws {
        let harness = makeHarness()
        let canonical = try #require(harness.coordinator.controllers["p2"])
        let rogue = rogueHost(matching: canonical)
        harness.controller.setViewControllers(
            [rogue],
            direction: .forward,
            animated: false
        )

        harness.coordinator.showCommittedPageIfNeeded(
            in: harness.controller,
            animated: false
        )

        #expect(harness.controller.viewControllers?.first === canonical)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func laterValidDelegateReplacesStoredSnapshotThatBecameStale() throws {
        let harness = makeHarness()
        let hosts = try startTransition(harness)
        harness.coordinator.recordDelegateCompletion(
            in: harness.controller,
            finished: true,
            previousViewControllers: [hosts.source],
            transitionCompleted: true,
            terminalPhaseObservedAtCallback: .ended
        )
        #expect(harness.coordinator.pendingDelegateRecord != nil)

        harness.controller.setViewControllers(
            [hosts.source],
            direction: .reverse,
            animated: false
        )
        harness.coordinator.recordDelegateCompletion(
            in: harness.controller,
            finished: true,
            previousViewControllers: [hosts.source],
            transitionCompleted: false,
            terminalPhaseObservedAtCallback: .ended
        )
        harness.coordinator.lastGestureTrace = endedTrace()

        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(harness.coordinator.pendingCallbackContext == nil)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == .cancelled
        )
        #expect(
            harness.coordinator.diagnosticSnapshot().visiblePageID == "p2"
        )
        harness.coordinator.dismantle(harness.controller)
    }

    private func makeHarness() -> PagerIdentityHarness {
        let selection = PagerIdentityBox<String?>("p2")
        let generation = PagerIdentityBox<UInt64>(0)
        let pager = makePager(
            selection: selection,
            externalGeneration: generation
        )
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        return PagerIdentityHarness(
            selection: selection,
            externalGeneration: generation,
            coordinator: coordinator,
            controller: controller
        )
    }

    private func makePager(
        selection: PagerIdentityBox<String?>,
        externalGeneration: PagerIdentityBox<UInt64>
    ) -> PagerContainer<String, Text> {
        PagerContainer(
            pageIDs: ["p0", "p1", "p2", "p3", "p4"],
            selection: Binding(
                get: { selection.value },
                set: { selection.value = $0 }
            ),
            backgroundColor: .black,
            reduceMotion: true,
            externalSelectionGeneration: Binding(
                get: { externalGeneration.value },
                set: { externalGeneration.value = $0 }
            ),
            contentGeneration: { _ in 1 },
            content: { Text($0) }
        )
    }

    private func startTransition(
        _ harness: PagerIdentityHarness
    ) throws -> PagerIdentityTransitionHosts {
        let source = try #require(harness.controller.viewControllers?.first)
        let target = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerAfter: source
            )
        )
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        harness.controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        return PagerIdentityTransitionHosts(source: source, target: target)
    }

    private func deliverCompletedDelegate(
        _ harness: PagerIdentityHarness,
        previous: UIViewController
    ) {
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [previous],
            transitionCompleted: true
        )
    }

    private func rogueHost(
        matching host: PagerHostingController<String, Text>
    ) -> PagerHostingController<String, Text> {
        PagerHostingController(
            pageID: host.pageID,
            instanceSequence: host.instanceSequence,
            contentGeneration: host.contentGeneration,
            rootView: PagerHostedPage(
                controllerSequence: host.instanceSequence,
                content: Text(host.pageID)
            )
        )
    }

    private func expectPending(
        _ harness: PagerIdentityHarness,
        ignoredReason: PagerCallbackIgnoredReason
    ) {
        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(harness.coordinator.pendingCallbackContext != nil)
        #expect(harness.coordinator.pendingDelegateRecord == nil)
        #expect(harness.coordinator.lastIgnoredCallbackReason == ignoredReason)
    }

    private func expectCommitted(_ harness: PagerIdentityHarness) {
        let snapshot = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(snapshot.committedID == "p3")
        #expect(snapshot.visiblePageID == "p3")
        #expect(snapshot.resolvedTransitionCount == 1)
        #expect(harness.coordinator.pendingCallbackContext == nil)
    }

    private func endedTrace() -> PagerGestureTrace {
        var trace = PagerGestureTrace()
        trace.finish(
            phase: .ended,
            progress: 0.75,
            velocityPagesPerSecond: 1
        )
        return trace
    }
}

@MainActor
private struct PagerIdentityHarness {
    let selection: PagerIdentityBox<String?>
    let externalGeneration: PagerIdentityBox<UInt64>
    let coordinator: PagerContainer<String, Text>.Coordinator
    let controller: UIPageViewController
}

private struct PagerIdentityTransitionHosts {
    let source: UIViewController
    let target: UIViewController
}

private final class PagerIdentityBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
