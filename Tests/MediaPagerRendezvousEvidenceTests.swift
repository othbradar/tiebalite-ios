import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

extension MediaInteractionControllerTests {
    @Test
    func pagerTerminalCannotCommitBeforeMediaOwnershipCancellationArrives() throws {
        var selection: String? = "large"
        var events: [PagerContainerEvent<String>] = []
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        let ownership = MediaGestureOwnershipController<String>()
        let pager = makeRendezvousMediaPager(
            selection: binding,
            ownership: ownership,
            onEvent: { events.append($0) }
        )
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(ownership.gestureRecognizerShouldBegin(gate))
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
        controller.setViewControllers(
            [target],
            direction: .forward,
            animated: false
        )
        coordinator.recordDelegateCompletion(
            in: controller,
            finished: true,
            previousViewControllers: [source],
            transitionCompleted: true,
            terminalPhaseObservedAtCallback: .ended
        )

        coordinator.lastGestureTrace = rendezvousEndedPagerTrace()

        #expect(selection == "large")
        #expect(coordinator.pendingCallbackContext != nil)
        #expect(coordinator.state.resolvedTransitionCount == 0)

        ownership.finishActiveSession(as: .cancelled)

        #expect(selection == "large")
        #expect(coordinator.pendingCallbackContext == nil)
        #expect(coordinator.state.resolvedTransitionCount == 1)
        let resolvedEvent = try #require(events.last)
        switch resolvedEvent {
        case let .resolved(snapshot, completed):
            #expect(!completed)
            #expect(snapshot.committedID == "large")
        case .began:
            Issue.record("Expected a resolved Pager event")
        }
        coordinator.dismantle(controller)
    }

    private func makeRendezvousMediaPager(
        selection: Binding<String?>,
        ownership: MediaGestureOwnershipController<String>,
        onEvent: @escaping (PagerContainerEvent<String>) -> Void
    ) -> PagerContainer<String, Text> {
        PagerContainer(
            pageIDs: ["large", "delayed", "small"],
            selection: selection,
            backgroundColor: .black,
            reduceMotion: true,
            mediaGestureOwnership: ownership,
            onEvent: onEvent
        ) { pageID in
            Text(pageID)
        }
    }

    private func rendezvousEndedPagerTrace() -> PagerGestureTrace {
        var trace = PagerGestureTrace()
        trace.finish(
            phase: .ended,
            progress: 0.75,
            velocityPagesPerSecond: 1
        )
        return trace
    }
}
