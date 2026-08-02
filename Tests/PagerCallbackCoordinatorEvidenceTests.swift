import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct PagerCallbackCoordinatorEvidenceTests {
    @Test
    func activeCallbackRejectsOverlapAndResolvesOnlyCapturedToken() throws {
        let harness = makeHarness()
        let source = try #require(harness.controller.viewControllers?.first)
        let next = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerAfter: source
            )
        )
        let previous = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerBefore: source
            )
        )

        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [next]
        )
        let capturedToken = try #require(
            harness.coordinator.pendingCallbackContext?.transition.token
        )
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [previous]
        )
        #expect(harness.coordinator.state.transition?.token == capturedToken)
        #expect(harness.coordinator.rejectedOverlappingTransitionCount == 1)
        #expect(harness.coordinator.maximumActiveCallbackDepth == 1)

        harness.controller.setViewControllers(
            [next],
            direction: .forward,
            animated: false
        )
        harness.coordinator.lastGestureTrace = gestureTrace(.ended)
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: true
        )
        let snapshot = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(snapshot.committedID == "p3")
        #expect(snapshot.visiblePageID == "p3")
        #expect(snapshot.resolvedTransitionCount == 1)
        #expect(snapshot.activeCallbackDepth == 0)
        #expect(snapshot.rejectedOverlappingTransitionCount == 1)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test(arguments: [PagerPanTerminalPhase.cancelled, .failed])
    func cancelledOrFailedRecognizerCannotChangeSelection(
        terminalPhase: PagerPanTerminalPhase
    ) throws {
        let harness = makeHarness()
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
        harness.coordinator.lastGestureTrace = gestureTrace(terminalPhase)
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: true
        )
        let snapshot = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p2")
        #expect(snapshot.committedID == "p2")
        #expect(snapshot.visiblePageID == "p2")
        #expect(snapshot.resolvedTransitionCount == 1)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func reverseTraceFlowsThroughOneCoordinatorCallbackWithoutCommit() throws {
        let harness = makeHarness(inputDiagnosticsEnabled: true)
        let source = try #require(harness.controller.viewControllers?.first)
        let target = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerAfter: source
            )
        )
        let reverseCandidate = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerBefore: source
            )
        )

        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [target]
        )
        let transitionToken = try #require(
            harness.coordinator.pendingCallbackContext?.transition.token
        )
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [reverseCandidate]
        )

        var trace = PagerGestureTrace()
        trace.record(progress: 0.52)
        trace.record(progress: 0.25)
        trace.finish(
            phase: .ended,
            progress: 0,
            velocityPagesPerSecond: 0
        )
        harness.coordinator.lastGestureTrace = trace
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: false
        )

        let diagnostic = try #require(harness.diagnostics.value.last)
        let snapshot = harness.coordinator.diagnosticSnapshot()
        #expect(diagnostic.transitionTokenSequence == transitionToken.sequence)
        #expect(diagnostic.trace == trace)
        #expect(diagnostic.trace.peakProgress == 0.52)
        #expect(diagnostic.trace.terminalProgress == 0)
        #expect(diagnostic.trace.reversalCount == 1)
        #expect(diagnostic.resolutionReason == .systemBailout)
        #expect(!diagnostic.businessCompleted)
        #expect(diagnostic.committedID == "p2")
        #expect(diagnostic.visibleID == "p2")
        #expect(harness.selection.value == "p2")
        #expect(snapshot.committedID == "p2")
        #expect(snapshot.visiblePageID == "p2")
        #expect(snapshot.resolvedTransitionCount == 1)
        #expect(snapshot.activeCallbackDepth == 0)
        #expect(snapshot.maximumActiveCallbackDepth == 1)
        #expect(snapshot.rejectedOverlappingTransitionCount == 1)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func staleDuplicateCallbackCannotConsumeNewTransitionContext() throws {
        let harness = makeHarness()
        let p2 = try #require(harness.controller.viewControllers?.first)
        let p3 = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerAfter: p2
            )
        )

        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [p3]
        )
        harness.coordinator.lastGestureTrace = gestureTrace(.ended)
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [p2],
            transitionCompleted: false
        )
        #expect(harness.selection.value == "p2")

        let retryP3 = try #require(
            harness.coordinator.pageViewController(
                harness.controller,
                viewControllerAfter: p2
            )
        )
        harness.coordinator.pageViewController(
            harness.controller,
            willTransitionTo: [retryP3]
        )
        let secondToken = try #require(
            harness.coordinator.pendingCallbackContext?.transition.token
        )

        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [p2],
            transitionCompleted: false
        )

        #expect(
            harness.coordinator.pendingCallbackContext?.transition.token
                == secondToken
        )
        #expect(harness.coordinator.pendingDelegateRecord == nil)
        #expect(harness.coordinator.state.transition?.token == secondToken)
        #expect(harness.selection.value == "p2")

        harness.controller.setViewControllers(
            [retryP3],
            direction: .forward,
            animated: false
        )
        harness.coordinator.lastGestureTrace = gestureTrace(.ended)
        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [p2],
            transitionCompleted: true
        )

        let snapshot = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(snapshot.committedID == "p3")
        #expect(snapshot.visiblePageID == "p3")
        #expect(snapshot.resolvedTransitionCount == 2)
        #expect(snapshot.activeCallbackDepth == 0)

        harness.coordinator.pageViewController(
            harness.controller,
            didFinishAnimating: true,
            previousViewControllers: [p2],
            transitionCompleted: true
        )
        let afterDuplicate = harness.coordinator.diagnosticSnapshot()
        #expect(harness.selection.value == "p3")
        #expect(afterDuplicate.resolvedTransitionCount == 2)
        #expect(afterDuplicate.activeCallbackDepth == 0)
        harness.coordinator.dismantle(harness.controller)
    }

    private func makeHarness(
        inputDiagnosticsEnabled: Bool = false
    ) -> PagerCallbackHarness {
        let selection = PagerCallbackTestBox<String?>("p2")
        let diagnostics = PagerCallbackTestBox<[
            PagerInputDiagnostic<String>
        ]>([])
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
            inputDiagnosticsEnabled: inputDiagnosticsEnabled,
            onInputDiagnostic: { diagnostics.value.append($0) },
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
        return PagerCallbackHarness(
            selection: selection,
            diagnostics: diagnostics,
            coordinator: coordinator,
            controller: controller
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
private struct PagerCallbackHarness {
    let selection: PagerCallbackTestBox<String?>
    let diagnostics: PagerCallbackTestBox<[PagerInputDiagnostic<String>]>
    let coordinator: PagerContainer<String, Text>.Coordinator
    let controller: UIPageViewController
}

private final class PagerCallbackTestBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
