import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct PagerCallbackRendezvousEvidenceTests {
    @Test
    func delegateCompletionBeforePanTargetActionCommitsExactlyOnce() throws {
        let harness = makeHarness()
        let source = try #require(harness.controller.viewControllers?.first)
        let target = try #require(harness.coordinator.pageViewController(
            harness.controller,
            viewControllerAfter: source
        ))
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        harness.controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        recordEarlyDelegate(
            harness,
            source: source,
            completed: true,
            terminalPhase: .ended
        )
        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.pendingCallbackContext != nil)
        #expect(harness.coordinator.pendingDelegateRecord != nil)
        #expect(harness.coordinator.state.resolvedTransitionCount == 0)

        harness.coordinator.lastGestureTrace = gestureTrace(.ended)

        let resolved = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(resolved.committedID == "p3")
        #expect(resolved.visiblePageID == "p3")
        #expect(resolved.resolvedTransitionCount == 1)
        #expect(resolved.activeCallbackDepth == 0)

        harness.coordinator.lastGestureTrace = gestureTrace(.ended)
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: true
        )
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test(arguments: [PagerPanTerminalPhase.cancelled, .failed])
    func delegateCompletionBeforeCancelledOrFailedTerminalRollsBackOnce(
        terminalPhase: PagerPanTerminalPhase
    ) throws {
        let harness = makeHarness()
        let source = try #require(harness.controller.viewControllers?.first)
        let target = try #require(harness.coordinator.pageViewController(
            harness.controller,
            viewControllerAfter: source
        ))
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        harness.controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        recordEarlyDelegate(
            harness,
            source: source,
            completed: true,
            terminalPhase: terminalPhase
        )
        harness.coordinator.lastGestureTrace = gestureTrace(terminalPhase)

        let resolved = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p2")
        #expect(resolved.committedID == "p2")
        #expect(resolved.visiblePageID == "p2")
        #expect(resolved.resolvedTransitionCount == 1)
        #expect(resolved.activeCallbackDepth == 0)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func delegateBailoutBeforePanTargetActionRollsBackExactlyOnce() throws {
        let harness = makeHarness()
        let source = try #require(harness.controller.viewControllers?.first)
        let target = try #require(harness.coordinator.pageViewController(
            harness.controller,
            viewControllerAfter: source
        ))
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        recordEarlyDelegate(
            harness,
            source: source,
            completed: false,
            terminalPhase: .ended
        )
        harness.coordinator.lastGestureTrace = gestureTrace(.ended)

        let resolved = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p2")
        #expect(resolved.committedID == "p2")
        #expect(resolved.visiblePageID == "p2")
        #expect(resolved.resolvedTransitionCount == 1)
        #expect(resolved.activeCallbackDepth == 0)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func earlyDelegateSnapshotChangeDoesNotConsumeCurrentContext() throws {
        let harness = makeHarness()
        let source = try #require(harness.controller.viewControllers?.first)
        let target = try #require(harness.coordinator.pageViewController(
            harness.controller,
            viewControllerAfter: source
        ))
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        harness.controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        recordEarlyDelegate(
            harness,
            source: source,
            completed: true,
            terminalPhase: .ended
        )
        harness.controller.setViewControllers(
            [source],
            direction: .reverse,
            animated: false
        )
        harness.coordinator.lastGestureTrace = gestureTrace(.ended)

        let rejected = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p2")
        #expect(rejected.committedID == "p2")
        #expect(rejected.visiblePageID == "p2")
        #expect(rejected.resolvedTransitionCount == 0)
        #expect(rejected.activeCallbackDepth == 1)
        #expect(harness.coordinator.pendingDelegateRecord == nil)

        harness.controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: true
        )
        let resolved = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(resolved.committedID == "p3")
        #expect(resolved.visiblePageID == "p3")
        #expect(resolved.resolvedTransitionCount == 1)
        #expect(resolved.activeCallbackDepth == 0)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func wrongPreviousAfterTerminalDoesNotConsumeCurrentContext() throws {
        let harness = makeHarness()
        let source = try #require(harness.controller.viewControllers?.first)
        let wrongPrevious = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerBefore: source
            )
        )
        let target = try #require(harness.coordinator.pageViewController(
            harness.controller,
            viewControllerAfter: source
        ))
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        harness.controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        harness.coordinator.lastGestureTrace = gestureTrace(.ended)
        let token = try #require(
            harness.coordinator.pendingCallbackContext?.transition.token
        )

        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [wrongPrevious],
            transitionCompleted: true
        )

        #expect(harness.selection.value == "p2")
        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(
            harness.coordinator.pendingCallbackContext?.transition.token
                == token
        )
        #expect(harness.coordinator.pendingDelegateRecord == nil)

        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: true
        )
        let resolved = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(resolved.committedID == "p3")
        #expect(resolved.visiblePageID == "p3")
        #expect(resolved.resolvedTransitionCount == 1)
        #expect(resolved.activeCallbackDepth == 0)
        harness.coordinator.dismantle(harness.controller)
    }

    private func makeHarness() -> PagerRendezvousHarness {
        let selection = PagerRendezvousBox<String?>("p2")
        let binding = Binding<String?>(
            get: { selection.value },
            set: { selection.value = $0 }
        )
        let pager = PagerContainer(
            pageIDs: ["p0", "p1", "p2", "p3", "p4"],
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true,
            contentGeneration: { _ in 1 },
            content: { Text($0) }
        )
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        return PagerRendezvousHarness(
            selection: selection,
            coordinator: coordinator,
            controller: controller
        )
    }

    private func recordEarlyDelegate(
        _ harness: PagerRendezvousHarness,
        source: UIViewController,
        completed: Bool,
        terminalPhase: PagerPanTerminalPhase
    ) {
        harness.coordinator.recordDelegateCompletion(
            in: harness.controller,
            finished: true,
            previousViewControllers: [source],
            transitionCompleted: completed,
            terminalPhaseObservedAtCallback: terminalPhase
        )
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

@MainActor
private struct PagerRendezvousHarness {
    let selection: PagerRendezvousBox<String?>
    let coordinator: PagerContainer<String, Text>.Coordinator
    let controller: UIPageViewController
}

private final class PagerRendezvousBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
