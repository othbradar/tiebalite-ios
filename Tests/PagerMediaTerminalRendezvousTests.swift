import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct PagerMediaTerminalRendezvousTests {
    @Test(arguments: PagerMediaEventOrder.allCases)
    func terminalEvidenceOrderDoesNotChangeCommit(
        order: PagerMediaEventOrder
    ) throws {
        let harness = try makePagerOwnershipHarness()
        let transition = try startTransition(harness)
        let token = try #require(
            harness.coordinator.pendingCallbackContext?.transition.token
        )

        for (index, event) in order.events.enumerated() {
            deliver(
                event,
                harness: harness,
                source: transition.source
            )
            if index < order.events.count - 1 {
                #expect(harness.selection.value == "large")
                #expect(
                    harness.coordinator.state.resolvedTransitionCount == 0
                )
                #expect(
                    harness.coordinator.pendingCallbackContext?
                        .transition.token == token
                )
                #expect(harness.events.value.count == 1)
                #expect(
                    harness.controller.viewControllers?.first
                        === transition.target
                )
            }
        }

        #expect(harness.selection.value == "delayed")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(harness.coordinator.pendingCallbackContext == nil)
        #expect(harness.coordinator.lastResolvedRendezvous?.result == .committed)
        #expect(harness.coordinator.lastResolvedRendezvous?.didPublish == true)
        #expect(harness.events.value.count == 2)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test(arguments: [
        MediaGestureSessionPhase.cancelled,
        .failed,
        .invalidated
    ])
    func ownershipRejectionNeverCommitsPager(
        phase: MediaGestureSessionPhase
    ) throws {
        let harness = try makePagerOwnershipHarness()
        let transition = try startTransition(harness)
        deliver(.delegate, harness: harness, source: transition.source)
        deliver(.pagerTerminal, harness: harness, source: transition.source)

        #expect(harness.selection.value == "large")
        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(
            harness.coordinator.activeRendezvous?.reason
                == .waitingForOwnershipTerminal
        )

        harness.ownership.finishActiveSession(as: phase)

        #expect(harness.selection.value == "large")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(harness.coordinator.pendingCallbackContext == nil)
        let expectedResult: PagerTransitionRendezvousResult =
            phase == .invalidated ? .invalidated : .cancelled
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == expectedResult
        )
        let expectedReason: PagerTransitionRendezvousReason
        switch phase {
        case .cancelled:
            expectedReason = .ownershipCancelled
        case .failed:
            expectedReason = .ownershipFailed
        case .invalidated:
            expectedReason = .ownershipInvalidated
        case .active, .ended:
            Issue.record("Unexpected non-rejection phase")
            expectedReason = .transitionInvalidated
        }
        #expect(
            harness.coordinator.lastResolvedRendezvous?.reason
                == expectedReason
        )
        #expect(harness.coordinator.lastResolvedRendezvous?.didPublish == true)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func activeOwnershipCannotAuthorizePagerResolution() throws {
        let harness = try makePagerOwnershipHarness()
        let session = try #require(harness.ownership.activeSession)

        #expect(
            !harness.ownership.allowsPagerResolution(
                sessionID: session.gestureSessionID,
                sourceID: session.mediaID,
                completed: true
            )
        )

        harness.ownership.finishActiveSession(as: .ended)

        #expect(
            harness.ownership.allowsPagerResolution(
                sessionID: session.gestureSessionID,
                sourceID: session.mediaID,
                completed: true
            )
        )
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func mediaPanOwnerCannotCommitSyntheticPagerCallback() throws {
        let harness = makeHarness()
        let zoom = MediaZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 600)
        )
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 1_200, height: 900)
        ).image { _ in }
        let zoomView = MediaZoomImageView(
            mediaID: "large",
            image: image,
            ownershipController: harness.ownership,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
        let zoomCoordinator = zoomView.makeCoordinator()
        zoomCoordinator.install(on: zoom)
        zoom.configure(image: image, mediaID: "large")
        zoom.layoutIfNeeded()
        zoom.setZoomScale(2, animated: false)
        let range = zoom.legalContentOffsetRange
        zoom.contentOffset = CGPoint(
            x: (range.minimumX + range.maximumX) / 2,
            y: (range.minimumY + range.maximumY) / 2
        )
        harness.ownership.register(mediaID: "large", scrollView: zoom)
        let gate = try #require(harness.ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(harness.ownership.gestureRecognizerShouldBegin(gate))
        #expect(harness.ownership.activeSession?.owner == .mediaPan)
        let transition = try startTransition(harness)
        deliver(.delegate, harness: harness, source: transition.source)
        deliver(.pagerTerminal, harness: harness, source: transition.source)

        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        harness.ownership.finishActiveSession(as: .ended)

        #expect(harness.selection.value == "large")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(harness.coordinator.lastResolvedRendezvous?.result == .cancelled)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.reason
                == .ownershipRejected
        )
        #expect(harness.coordinator.state.committedID == "large")
        #expect(
            harness.coordinator.diagnosticSnapshot().visiblePageID
                == "large"
        )
        #expect(
            harness.controller.viewControllers?.first
                === transition.source
        )
        zoomCoordinator.dismantle(zoom)
        harness.ownership.unregister(mediaID: "large", scrollView: zoom)
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func externalSelectionWaitsForOwnershipTerminalBeforeReplacingHosts() throws {
        let harness = try makePagerOwnershipHarness()
        let transition = try startTransition(harness)
        deliver(.delegate, harness: harness, source: transition.source)
        deliver(.pagerTerminal, harness: harness, source: transition.source)

        harness.selection.value = "small"
        harness.externalGeneration.value &+= 1
        harness.coordinator.synchronize(harness.controller)

        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(harness.coordinator.pendingCallbackContext != nil)
        #expect(
            harness.controller.viewControllers?.first
                === transition.target
        )
        #expect(harness.coordinator.controllers["large"] === transition.source)
        #expect(harness.coordinator.controllers["delayed"] === transition.target)

        harness.ownership.finishActiveSession(as: .ended)

        #expect(harness.selection.value == "small")
        #expect(harness.coordinator.state.committedID == "small")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(harness.coordinator.pendingCallbackContext == nil)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == .invalidated
        )
        #expect(
            harness.coordinator.lastResolvedRendezvous?.reason
                == .externalSelectionChanged
        )
        #expect(
            harness.coordinator.diagnosticSnapshot().visiblePageID
                == "small"
        )
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func sameMediaGenerationChangeInvalidatesOwnershipLeg() throws {
        let harness = try makePagerOwnershipHarness()
        let transition = try startTransition(harness)

        harness.ownership.mediaDidChange(to: "large")
        deliver(.delegate, harness: harness, source: transition.source)
        deliver(.pagerTerminal, harness: harness, source: transition.source)
        harness.ownership.finishActiveSession(as: .ended)

        #expect(harness.selection.value == "large")
        #expect(harness.coordinator.state.committedID == "large")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == .invalidated
        )
        #expect(
            harness.coordinator.lastResolvedRendezvous?.reason
                == .ownershipInvalidated
        )
        harness.coordinator.dismantle(harness.controller)
    }

    @Test
    func cachedOwnershipTerminalCannotOutliveItsGeneration() throws {
        let harness = try makePagerOwnershipHarness()
        let transition = try startTransition(harness)

        deliver(.ownershipTerminal, harness: harness, source: transition.source)

        #expect(harness.coordinator.state.resolvedTransitionCount == 0)
        #expect(
            harness.coordinator.activeRendezvous?.reason
                == .waitingForDelegate
        )

        harness.ownership.mediaDidChange(to: "large")
        deliver(.delegate, harness: harness, source: transition.source)
        deliver(.pagerTerminal, harness: harness, source: transition.source)

        #expect(harness.selection.value == "large")
        #expect(harness.coordinator.state.committedID == "large")
        #expect(harness.coordinator.state.resolvedTransitionCount == 1)
        #expect(
            harness.coordinator.lastResolvedRendezvous?.result
                == .invalidated
        )
        #expect(
            harness.coordinator.lastResolvedRendezvous?.reason
                == .ownershipInvalidated
        )
        harness.coordinator.dismantle(harness.controller)
    }

    private func makePagerOwnershipHarness() throws -> PagerMediaHarness {
        let harness = makeHarness()
        let gate = try #require(harness.ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(harness.ownership.gestureRecognizerShouldBegin(gate))
        #expect(harness.ownership.activeSession?.owner == .pager)
        return harness
    }

    private func makeHarness() -> PagerMediaHarness {
        let selection = PagerMediaBox<String?>("large")
        let externalGeneration = PagerMediaBox<UInt64>(0)
        let events = PagerMediaBox<[PagerContainerEvent<String>]>([])
        let binding = Binding<String?>(
            get: { selection.value },
            set: { selection.value = $0 }
        )
        let ownership = MediaGestureOwnershipController<String>()
        let pager = PagerContainer(
            pageIDs: ["large", "delayed", "small"],
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true,
            mediaGestureOwnership: ownership,
            externalSelectionGeneration: Binding(
                get: { externalGeneration.value },
                set: { externalGeneration.value = $0 }
            ),
            onEvent: { events.value.append($0) },
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
        return PagerMediaHarness(
            selection: selection,
            externalGeneration: externalGeneration,
            events: events,
            ownership: ownership,
            coordinator: coordinator,
            controller: controller
        )
    }

    private func startTransition(
        _ harness: PagerMediaHarness
    ) throws -> PagerMediaTransitionHosts {
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
        return PagerMediaTransitionHosts(source: source, target: target)
    }

    private func deliver(
        _ event: PagerMediaRendezvousEvent,
        harness: PagerMediaHarness,
        source: UIViewController
    ) {
        switch event {
        case .delegate:
            harness.coordinator.recordDelegateCompletion(
                in: harness.controller,
                finished: true,
                previousViewControllers: [source],
                transitionCompleted: true,
                terminalPhaseObservedAtCallback: .ended
            )
        case .pagerTerminal:
            harness.coordinator.lastGestureTrace = endedPagerTrace()
        case .ownershipTerminal:
            harness.ownership.finishActiveSession(as: .ended)
        }
    }

    private func endedPagerTrace() -> PagerGestureTrace {
        var trace = PagerGestureTrace()
        trace.finish(
            phase: .ended,
            progress: 0.75,
            velocityPagesPerSecond: 1
        )
        return trace
    }
}

enum PagerMediaEventOrder: CaseIterable, Sendable {
    case delegatePagerOwnership
    case delegateOwnershipPager
    case pagerDelegateOwnership
    case pagerOwnershipDelegate
    case ownershipDelegatePager
    case ownershipPagerDelegate

    var events: [PagerMediaRendezvousEvent] {
        switch self {
        case .delegatePagerOwnership:
            [.delegate, .pagerTerminal, .ownershipTerminal]
        case .delegateOwnershipPager:
            [.delegate, .ownershipTerminal, .pagerTerminal]
        case .pagerDelegateOwnership:
            [.pagerTerminal, .delegate, .ownershipTerminal]
        case .pagerOwnershipDelegate:
            [.pagerTerminal, .ownershipTerminal, .delegate]
        case .ownershipDelegatePager:
            [.ownershipTerminal, .delegate, .pagerTerminal]
        case .ownershipPagerDelegate:
            [.ownershipTerminal, .pagerTerminal, .delegate]
        }
    }
}

enum PagerMediaRendezvousEvent: Sendable {
    case delegate
    case pagerTerminal
    case ownershipTerminal
}

@MainActor
private struct PagerMediaHarness {
    let selection: PagerMediaBox<String?>
    let externalGeneration: PagerMediaBox<UInt64>
    let events: PagerMediaBox<[PagerContainerEvent<String>]>
    let ownership: MediaGestureOwnershipController<String>
    let coordinator: PagerContainer<String, Text>.Coordinator
    let controller: UIPageViewController
}

private struct PagerMediaTransitionHosts {
    let source: UIViewController
    let target: UIViewController
}

private final class PagerMediaBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
