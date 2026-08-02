import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

struct PagerInteractionEvidenceTests {
    @Test
    func distanceAndVelocityRemainSeparateTraceEvidence() {
        let distance = trace(
            endingAt: 0.51,
            velocityPagesPerSecond: 0.08
        )
        let velocity = trace(
            endingAt: 0.15,
            velocityPagesPerSecond: 1.50
        )

        #expect(distance.terminalProgress == 0.51)
        #expect(distance.terminalVelocityPagesPerSecond == 0.08)
        #expect(velocity.terminalProgress == 0.15)
        #expect(velocity.terminalVelocityPagesPerSecond == 1.50)
        #expect(distance.terminalPhase == .ended)
        #expect(velocity.terminalPhase == .ended)
    }

    @Test
    func reverseSequencesUseEndPositionAndOneTransition() throws {
        var belowThreshold = PagerGestureTrace()
        belowThreshold.record(progress: 0.48)
        belowThreshold.record(progress: 0.20)
        belowThreshold.finish(
            phase: .ended,
            progress: 0,
            velocityPagesPerSecond: 0
        )
        #expect(belowThreshold.reversalCount == 1)
        #expect(belowThreshold.terminalProgress == 0)

        var crossedThreshold = PagerGestureTrace()
        crossedThreshold.record(progress: 0.52)
        crossedThreshold.record(progress: 0.25)
        crossedThreshold.finish(
            phase: .ended,
            progress: 0,
            velocityPagesPerSecond: 0
        )
        #expect(crossedThreshold.peakProgress == 0.52)
        #expect(crossedThreshold.reversalCount == 1)
        #expect(crossedThreshold.terminalProgress == 0)

        var state = PagerStateMachine(
            pageIDs: ["p1", "p2", "p3"],
            committedID: "p2"
        )
        let tokenCandidate = state.beginTransition(to: "p3")
        let token = try #require(tokenCandidate)
        let duplicateTransition = state.beginTransition(to: "p1")
        #expect(duplicateTransition == nil)
        let resolved = state.resolveTransition(
            token: token,
            completed: false
        )
        #expect(resolved)
        #expect(state.committedID == "p2")
        #expect(state.resolvedTransitionCount == 1)
    }

    @Test
    func callbackValidationCommitsOnlyTheCurrentEndedVisualTarget() {
        let transition = PagerTransitionCallbackExpectation(
            tokenSequence: 7,
            sourceID: "p2",
            targetID: "p3"
        )
        let committed = transition.resolve(
            PagerTransitionCallbackEvidence(
                tokenSequence: 7,
                panTerminal: .ended,
                finished: true,
                transitionCompleted: true,
                previousID: "p2",
                visibleID: "p3"
            )
        )
        #expect(committed.completed)
        #expect(committed.reason == .committed)

        var cancelled = PagerGestureTrace()
        cancelled.finish(
            phase: .cancelled,
            progress: 0.90,
            velocityPagesPerSecond: 3
        )
        var failed = PagerGestureTrace()
        failed.finish(
            phase: .failed,
            progress: 0.90,
            velocityPagesPerSecond: 3
        )
        let cancelledResolution = transition.resolve(
            PagerTransitionCallbackEvidence(
                tokenSequence: 7,
                panTerminal: cancelled.terminalPhase,
                finished: true,
                transitionCompleted: true,
                previousID: "p2",
                visibleID: "p3"
            )
        )
        let failedResolution = transition.resolve(
            PagerTransitionCallbackEvidence(
                tokenSequence: 7,
                panTerminal: failed.terminalPhase,
                finished: true,
                transitionCompleted: true,
                previousID: "p2",
                visibleID: "p3"
            )
        )
        #expect(!cancelledResolution.completed)
        #expect(!failedResolution.completed)
        #expect(cancelledResolution.reason == .panCancelled)
        #expect(failedResolution.reason == .panFailed)
        assertUncommittedResolutionKeepsCurrentID(cancelledResolution)
        assertUncommittedResolutionKeepsCurrentID(failedResolution)

        let stale = transition.resolve(
            PagerTransitionCallbackEvidence(
                tokenSequence: 6,
                panTerminal: .ended,
                finished: true,
                transitionCompleted: true,
                previousID: "p2",
                visibleID: "p3"
            )
        )
        #expect(!stale.completed)
        #expect(stale.reason == .staleToken)
        assertInvalidCallbackEvidence(using: transition)
    }

    private func assertInvalidCallbackEvidence(
        using transition: PagerTransitionCallbackExpectation<String>
    ) {
        let invalidEvidence: [(PagerTransitionCallbackEvidence<String>,
            PagerCallbackResolutionReason)] = [
            (
                PagerTransitionCallbackEvidence(
                    tokenSequence: 7,
                    panTerminal: .active,
                    finished: true,
                    transitionCompleted: true,
                    previousID: "p2",
                    visibleID: "p3"
                ),
                .missingPanTerminal
            ),
            (
                PagerTransitionCallbackEvidence(
                    tokenSequence: 7,
                    panTerminal: .ended,
                    finished: false,
                    transitionCompleted: true,
                    previousID: "p2",
                    visibleID: "p3"
                ),
                .animationInterrupted
            ),
            (
                PagerTransitionCallbackEvidence(
                    tokenSequence: 7,
                    panTerminal: .ended,
                    finished: true,
                    transitionCompleted: true,
                    previousID: "p1",
                    visibleID: "p3"
                ),
                .previousSourceMismatch
            ),
            (
                PagerTransitionCallbackEvidence(
                    tokenSequence: 7,
                    panTerminal: .ended,
                    finished: true,
                    transitionCompleted: true,
                    previousID: "p2",
                    visibleID: "p2"
                ),
                .visiblePageMismatch
            )
            ]
        for (evidence, expectedReason) in invalidEvidence {
            let resolution = transition.resolve(evidence)
            #expect(!resolution.completed)
            #expect(resolution.reason == expectedReason)
        }
    }

    @Test
    func retainedStateMatrixKeepsContentAndRejectsStaleGeneration() {
        var state = PagerRetainedContentState(loaded: "content-v1")
        let originalContent = state.content

        let staleRefresh = state.beginRefreshing()
        #expect(state.phase == .refreshing)
        #expect(state.content == originalContent)

        let currentRefresh = state.beginRefreshing()
        #expect(currentRefresh > staleRefresh)
        let staleResolved = state.resolveLoaded(
            "stale-content",
            requestGeneration: staleRefresh
        )
        #expect(!staleResolved)
        #expect(state.content == originalContent)
        let refreshFailed = state.failRefresh(
            requestGeneration: currentRefresh
        )
        #expect(refreshFailed)
        #expect(state.phase == .refreshFailure)
        #expect(state.content == originalContent)

        _ = state.beginLoadingNextPage()
        #expect(state.phase == .loadingNextPage)
        #expect(state.content == originalContent)

        let staleInitialFailureRequest = state.beginInitialLoading()
        let initialRequest = state.beginInitialLoading()
        let staleInitialFailure = state.failInitialLoad(
            requestGeneration: staleInitialFailureRequest
        )
        #expect(!staleInitialFailure)
        #expect(state.phase == .initialLoading)
        #expect(state.content == nil)
        let initialFailed = state.failInitialLoad(
            requestGeneration: initialRequest
        )
        #expect(initialFailed)
        #expect(state.phase == .initialFailure)
        let staleEmptyRequest = state.beginInitialLoading()
        let emptyRequest = state.beginInitialLoading()
        let staleEmpty = state.resolveEmpty(
            requestGeneration: staleEmptyRequest
        )
        #expect(!staleEmpty)
        let didResolveEmpty = state.resolveEmpty(
            requestGeneration: emptyRequest
        )
        #expect(didResolveEmpty)
        #expect(state.phase == .empty)
        #expect(state.content == nil)
    }

    private func trace(
        endingAt progress: Double,
        velocityPagesPerSecond: Double = 0.10
    ) -> PagerGestureTrace {
        var trace = PagerGestureTrace()
        trace.finish(
            phase: .ended,
            progress: progress,
            velocityPagesPerSecond: velocityPagesPerSecond
        )
        return trace
    }

    private func assertUncommittedResolutionKeepsCurrentID(
        _ resolution: PagerCallbackResolution
    ) {
        var state = PagerStateMachine(
            pageIDs: ["p1", "p2", "p3"],
            committedID: "p2"
        )
        let token = state.beginTransition(to: "p3")
        #expect(token != nil)
        if let token {
            let didResolve = state.resolveTransition(
                token: token,
                completed: resolution.completed
            )
            #expect(didResolve)
        }
        #expect(state.committedID == "p2")
    }
}

@MainActor
struct PagerRetainedGeometryTests {
    @Test
    func coveredGeometryCoalescesOnlyAlignedBounceSamples() {
        let baseline = geometrySnapshot(rootX: 0, covered: true)
        let alignedSubpoint = geometrySnapshot(rootX: 0.5, covered: true)
        let exposedBounce = geometrySnapshot(rootX: -83.7, covered: false)

        #expect(baseline == alignedSubpoint)
        #expect(baseline != exposedBounce)
    }

    @Test
    func everyFixtureStateKeepsHostIdentityAndOpaqueBoundsCoverage() throws {
        var selection: String? = "p2"
        var state = PagerRetainedContentState(loaded: "content-v1")
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        var pager = makePager(
            selection: binding,
            state: state
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeInstalledController(
            coordinator: coordinator
        )
        coordinator.synchronize(controller)
        let originalSequence = try #require(
            coordinator.diagnosticSnapshot().visibleControllerSequence
        )

        let transitions: [(inout PagerRetainedContentState<String>) -> Void] = [
            { _ = $0.beginRefreshing() },
            { _ = $0.beginLoadingNextPage() },
            {
                let generation = $0.beginRefreshing()
                _ = $0.failRefresh(requestGeneration: generation)
            },
            { _ = $0.beginInitialLoading() },
            {
                let request = $0.beginInitialLoading()
                _ = $0.failInitialLoad(requestGeneration: request)
            },
            {
                let request = $0.beginInitialLoading()
                _ = $0.resolveEmpty(requestGeneration: request)
            }
        ]

        let resizedBounds = [
            CGRect(x: 0, y: 0, width: 390, height: 600),
            CGRect(x: 0, y: 0, width: 844, height: 390)
        ]
        for (index, transition) in transitions.enumerated() {
            transition(&state)
            pager = makePager(selection: binding, state: state)
            coordinator.parent = pager
            coordinator.synchronize(controller)
            controller.view.frame = resizedBounds[index % resizedBounds.count]
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            let snapshot = coordinator.diagnosticSnapshot()
            let geometry = try #require(snapshot.geometry)
            #expect(snapshot.committedID == "p2")
            #expect(snapshot.visibleControllerSequence == originalSequence)
            #expect(geometry.stateGeneration == state.generation)
            #expect(
                geometry.pagerBounds
                    == resizedBounds[index % resizedBounds.count]
            )
            #expect(geometry.coversPagerBounds)
            #expect(geometry.hasOpaqueBackground)
        }

        coordinator.dismantle(controller)
    }

    @Test
    func retainedRefreshUpdatesExistingHostDuringActiveTransition() throws {
        var selection: String? = "p2"
        var state = PagerRetainedContentState(loaded: "content-v1")
        let transitionSnapshots = PagerGeometryTestBox<[
            PagerContainerSnapshot<String>
        ]>([])
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        var pager = makePager(
            selection: binding,
            state: state,
            onTransitionSnapshot: { transitionSnapshots.value.append($0) }
        )
        let coordinator = pager.makeCoordinator()
        let controller = makeInstalledController(coordinator: coordinator)
        coordinator.synchronize(controller)
        let source = try #require(controller.viewControllers?.first)
        let sourceSequence = try #require(
            coordinator.diagnosticSnapshot().visibleControllerSequence
        )
        let target = try #require(
            coordinator.pageViewController(
                controller,
                viewControllerAfter: source
            )
        )
        let targetSequence = try #require(
            (target as? PagerHostingController<
                String,
                PagerGeometryFixturePage
            >)?.instanceSequence
        )
        coordinator.pageViewController(
            controller,
            willTransitionTo: [target]
        )

        _ = state.beginRefreshing()
        pager = makePager(
            selection: binding,
            state: state,
            onTransitionSnapshot: { transitionSnapshots.value.append($0) }
        )
        coordinator.parent = pager
        coordinator.synchronize(controller)
        coordinator.synchronize(controller)

        let inFlight = try #require(transitionSnapshots.value.last)
        #expect(transitionSnapshots.value.count == 1)
        let identity = PagerInFlightIdentity(
            source: source,
            sourceSequence: sourceSequence,
            target: target,
            targetSequence: targetSequence
        )
        try assertInFlightRefresh(
            inFlight,
            stateGeneration: state.generation,
            identity: identity
        )

        var endedTrace = PagerGestureTrace()
        endedTrace.finish(
            phase: .ended,
            progress: 0.34,
            velocityPagesPerSecond: 0.1
        )
        coordinator.lastGestureTrace = endedTrace
        coordinator.pageViewController(
            controller,
            didFinishAnimating: true,
            previousViewControllers: [source],
            transitionCompleted: false
        )
        let settled = coordinator.diagnosticSnapshot()
        #expect(settled.committedID == "p2")
        #expect(settled.visiblePageID == "p2")
        #expect(settled.visibleControllerSequence == sourceSequence)
        #expect(settled.activeCallbackDepth == 0)
        coordinator.dismantle(controller)
    }

    private func assertInFlightRefresh(
        _ snapshot: PagerContainerSnapshot<String>,
        stateGeneration: UInt64,
        identity: PagerInFlightIdentity
    ) throws {
        let geometry = try #require(snapshot.geometry)
        #expect(snapshot.committedID == "p2")
        #expect(snapshot.visiblePageID == "p2")
        #expect(snapshot.visibleControllerSequence == identity.sourceSequence)
        #expect(
            snapshot.cachedControllerSequences["p2"]
                == identity.sourceSequence
        )
        #expect(
            snapshot.cachedControllerSequences["p3"]
                == identity.targetSequence
        )
        #expect(snapshot.activeCallbackDepth == 1)
        #expect(snapshot.controllerCount <= 4)
        #expect(geometry.stateGeneration == stateGeneration)
        #expect(geometry.coversPagerBounds)
        #expect(geometry.hasOpaqueBackground)
        #expect(
            (identity.source as? PagerHostingController<
                String,
                PagerGeometryFixturePage
            >)?.contentGeneration == stateGeneration
        )
        #expect(
            (identity.target as? PagerHostingController<
                String,
                PagerGeometryFixturePage
            >)?.contentGeneration == stateGeneration
        )
    }

    private func makePager(
        selection: Binding<String?>,
        state: PagerRetainedContentState<String>,
        onTransitionSnapshot: @escaping (
            PagerContainerSnapshot<String>
        ) -> Void = { _ in }
    ) -> PagerContainer<String, PagerGeometryFixturePage> {
        PagerContainer(
            pageIDs: ["p1", "p2", "p3"],
            selection: selection,
            backgroundColor: .black,
            reduceMotion: true,
            contentGeneration: { _ in state.generation },
            onTransitionSnapshot: onTransitionSnapshot,
            content: { pageID in
                PagerGeometryFixturePage(
                    pageID: pageID,
                    phase: state.phase,
                    content: state.content
                )
            }
        )
    }

    private func geometrySnapshot(
        rootX: CGFloat,
        covered: Bool
    ) -> PagerGeometrySnapshot<String> {
        PagerGeometrySnapshot(
            pageID: "p2",
            controllerSequence: 1,
            stateGeneration: 1,
            rootFrame: CGRect(x: rootX, y: 0, width: 390, height: 600),
            pagerBounds: CGRect(x: 0, y: 0, width: 390, height: 600),
            coversPagerBounds: covered,
            hasOpaqueBackground: true
        )
    }

    private func makeInstalledController(
        coordinator: PagerContainer<String, PagerGeometryFixturePage>
            .Coordinator
    ) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        coordinator.install(on: controller)
        return controller
    }
}

@MainActor
private struct PagerInFlightIdentity {
    let source: UIViewController
    let sourceSequence: UInt64
    let target: UIViewController
    let targetSequence: UInt64
}

private final class PagerGeometryTestBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private struct PagerGeometryFixturePage: View {
    let pageID: String
    let phase: PagerContentPhase
    let content: String?

    var body: some View {
        ZStack {
            Color.black
            Text(content ?? phase.rawValue)
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("fixture.\(pageID)")
    }
}
