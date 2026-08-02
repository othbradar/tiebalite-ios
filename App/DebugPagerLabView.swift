#if DEBUG
import Foundation
import SwiftUI
import UIKit

@MainActor
struct DebugPagerLabView: View {
    private enum ArmedMutation: String {
        case delete
        case insert
        case refresh
        case reorder
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.motionReductionOverride) private var reductionOverride
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var pageIDs = ["p0", "p1", "p2", "p3", "p4"]
    @State private var selection: String? = "p2"
    @State private var externalSelectionGeneration: UInt64 = 0
    @State private var armedMutation: ArmedMutation?
    @State private var transitionState = "idle"
    @State private var liveIDs = ["p1", "p2", "p3"]
    @State private var resolvedTransitionCount = 0
    @State private var controllerCount = 3
    @State private var coordinatorSequence: UInt64 = 0
    @State private var pagerViewportWidth: CGFloat = 0
    @State private var pagerViewportHeight: CGFloat = 0
    @State private var contentState = PagerRetainedContentState(
        loaded: "retained-content-v1"
    )
    @State private var staleResponseRejectionCount = 0
    @State private var inputDiagnosticCount = 0
    @State private var lastTrace = "Trace: none"
    @State private var lastResolution = "Resolution: none"
    @State private var visibleControllerSequence: UInt64 = 0
    @State private var createdControllerCount = 0
    @State private var contentBuildCount = 0
    @State private var evictedControllerCount = 0
    @State private var orphanControllerCount = 0
    @State private var settledSnapshotCount = 0
    @State private var geometryStatus = "Geometry: pending"
    @State private var settledProjectionStatus = "Settled: pending"
    @State private var inFlightRefreshStatus = "In-flight: none"
    @State private var inFlightRefreshCount = 0
    @State private var inputAlignmentMismatchCount = 0
    @State private var projectionGeneration = 0
    @State private var projectionStatus = "Projection: pending"
    @State private var verticalScrollStatus = "Vertical offset: 0"

    var body: some View {
        GeometryReader { proxy in
            let layout = proxy.size.width > proxy.size.height
                ? AnyLayout(HStackLayout(spacing: Spacing.small))
                : AnyLayout(VStackLayout(spacing: Spacing.small))
            layout {
                controlPanel
                pagerViewport
            }
        }
        .onChange(
            of: horizontalSizeClass,
            initial: true
        ) { _, sizeClass in
            projectionGeneration += 1
            projectionStatus = "Projection: "
                + (sizeClass == .regular ? "regular" : "compact")
                + ", generation \(projectionGeneration)"
        }
    }

    private var controlPanel: some View {
        VStack(spacing: Spacing.small) {
            pagerAccessibilityControls
            mutationControls
            ScrollView(.vertical) {
                statusGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Candidate: UIPageViewController")
                .accessibilityIdentifier("interaction.lab.candidate")

            Text("Current ID: \(selection ?? "none")")
                .accessibilityIdentifier("interaction.pager.current-id")
            Text("Position: \(positionText)")
                .accessibilityIdentifier("interaction.pager.position")
            Text("Transition: \(transitionState)")
                .accessibilityIdentifier(
                    "interaction.pager.transition-state"
                )
            Text("Live IDs: \(liveIDs.joined(separator: ","))")
                .accessibilityIdentifier("interaction.pager.live-ids")
            Text("Resolved: \(resolvedTransitionCount)")
                .accessibilityIdentifier(
                    "interaction.pager.completion-count"
                )
            Text("Controllers: \(controllerCount)")
                .accessibilityIdentifier(
                    "interaction.pager.controller-count"
                )
            Text("Coordinator: \(coordinatorSequence)")
                .accessibilityIdentifier(
                    "interaction.pager.coordinator-sequence"
                )
            Text("State: \(contentState.phase.rawValue)")
                .accessibilityIdentifier("interaction.pager.refresh-state")
            Text("Generation: \(contentState.generation)")
                .accessibilityIdentifier(
                    "interaction.pager.state-generation"
                )
            Text("Stale rejected: \(staleResponseRejectionCount)")
                .accessibilityIdentifier(
                    "interaction.pager.stale-rejections"
                )
            Text("Inputs: \(inputDiagnosticCount)")
                .accessibilityIdentifier(
                    "interaction.pager.input-count"
                )
            Text(lastTrace)
                .accessibilityIdentifier("interaction.pager.input-trace")
            Text(lastResolution)
                .accessibilityIdentifier(
                    "interaction.pager.input-resolution"
                )
            Text(
                "Lifecycle: visible \(visibleControllerSequence), "
                    + "created \(createdControllerCount), "
                    + "builds \(contentBuildCount), "
                    + "evicted \(evictedControllerCount), "
                    + "orphans \(orphanControllerCount)"
            )
            .accessibilityIdentifier("interaction.pager.lifecycle")
            Text("Settled snapshots: \(settledSnapshotCount)")
                .accessibilityIdentifier(
                    "interaction.pager.settled-snapshot-count"
                )
            Text(geometryStatus)
                .accessibilityIdentifier("interaction.pager.geometry")
            Text(settledProjectionStatus)
                .accessibilityIdentifier(
                    "interaction.pager.settled-projection"
                )
            Text(inFlightRefreshStatus)
                .accessibilityIdentifier(
                    "interaction.pager.in-flight-refresh"
                )
            Text(projectionStatus)
                .accessibilityIdentifier(
                    "interaction.pager.projection"
                )
            Text(verticalScrollStatus)
                .accessibilityIdentifier(
                    "interaction.pager.vertical-scroll-offset"
                )
            Text("Input mismatches: \(inputAlignmentMismatchCount)")
                .accessibilityIdentifier(
                    "interaction.pager.input-mismatches"
                )
            Text(
                verbatim: "Viewport width: "
                    + "\(Int(pagerViewportWidth.rounded()))"
            )
                .accessibilityIdentifier(
                    "interaction.pager.viewport-width"
                )
            Text(
                verbatim: "Viewport height: "
                    + "\(Int(pagerViewportHeight.rounded()))"
            )
                .accessibilityIdentifier(
                    "interaction.pager.viewport-height"
                )
        }
        .font(Typography.font(.caption))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pagerViewport: some View {
        ZStack {
            Color(red: 1, green: 0, blue: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            PagerContainer(
                pageIDs: pageIDs,
                selection: $selection,
                backgroundColor: .black,
                reduceMotion: reduceMotion || reductionOverride,
                externalSelectionGeneration: $externalSelectionGeneration,
                contentGeneration: { _ in contentState.generation },
                inputDiagnosticsEnabled: true,
                onEvent: handlePagerEvent,
                onSettledSnapshot: handleSettledPagerSnapshot,
                onTransitionSnapshot: handleTransitionPagerSnapshot,
                onInputDiagnostic: handleInputDiagnostic,
                content: { pageID in
                    DebugOpaquePagerPage(
                        pageID: pageID,
                        phase: contentState.phase,
                        content: contentState.content,
                        generation: contentState.generation,
                        retryInitialFailure: restoreLoadedContent,
                        onVerticalScrollOffsetChange: { pageID, offset in
                            guard pageID == selection else {
                                return
                            }
                            verticalScrollStatus = "Vertical offset: "
                                + "\(Int(offset.rounded()))"
                        }
                    )
                }
            )
            .accessibilityLabel("Pager")
            .accessibilityValue(positionText)
            .accessibilityIdentifier("interaction.pager.adjustable")
            .accessibilityAdjustableAction { direction in
                movePagerAccessibility(direction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            pagerViewportWidth = size.width
            pagerViewportHeight = size.height
        }
    }

    private var pagerAccessibilityControls: some View {
        HStack(spacing: Spacing.small) {
            Button("上一页") {
                movePager(by: -1)
            }
            .buttonStyle(.bordered)
            .disabled(!canMovePager(by: -1))
            .accessibilityIdentifier(
                "interaction.pager.accessibility.previous"
            )

            Button("下一页") {
                movePager(by: 1)
            }
            .buttonStyle(.bordered)
            .disabled(!canMovePager(by: 1))
            .accessibilityIdentifier(
                "interaction.pager.accessibility.next"
            )
        }
    }

    private var mutationControls: some View {
        VStack(spacing: Spacing.small) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: Spacing.small
            ) {
                mutationButton(.insert, title: "转场中插入")
                mutationButton(.delete, title: "转场中删除")
                mutationButton(.reorder, title: "转场中重排")
                mutationButton(.refresh, title: "保留内容刷新")
                Button("下一内容状态", action: cycleContentState)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(
                        "interaction.pager.action.next-content-state"
                    )
                Button("注入过期响应", action: injectStaleResponse)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(
                        "interaction.pager.action.stale-response"
                    )
            }

            Button("重置", action: reset)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(
                    "interaction.pager.action.reset"
                )
        }
    }
}

private extension DebugPagerLabView {
    private var positionText: String {
        guard let selection,
              let index = pageIDs.firstIndex(of: selection) else {
            return "0/0"
        }
        return "\(index + 1)/\(pageIDs.count)"
    }

    private func movePagerAccessibility(
        _ direction: AccessibilityAdjustmentDirection
    ) {
        switch direction {
        case .increment:
            movePager(by: 1)
        case .decrement:
            movePager(by: -1)
        @unknown default:
            return
        }
    }

    private func canMovePager(by offset: Int) -> Bool {
        guard let selection,
              let index = pageIDs.firstIndex(of: selection) else {
            return false
        }
        return pageIDs.indices.contains(index + offset)
    }

    private func movePager(by offset: Int) {
        guard let selection,
              let index = pageIDs.firstIndex(of: selection) else {
            return
        }
        let targetIndex = index + offset
        guard pageIDs.indices.contains(targetIndex) else {
            return
        }
        externalSelectionGeneration &+= 1
        self.selection = pageIDs[targetIndex]
    }

    private func mutationButton(
        _ mutation: ArmedMutation,
        title: String
    ) -> some View {
        Button(title) {
            armedMutation = mutation
            transitionState = "armed-\(mutation.rawValue)"
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(
            "interaction.pager.action.arm-\(mutation.rawValue)"
        )
    }

    private func handlePagerEvent(
        _ event: PagerContainerEvent<String>
    ) {
        switch event {
        case let .began(transition):
            transitionState = "transitioning"
            liveIDs = transition.participantIDs
            applyArmedMutationDuringUIKitTransition()
        case let .resolved(snapshot, completed):
            transitionState = completed ? "idle-completed" : "idle-cancelled"
            liveIDs = snapshot.liveIDs
            resolvedTransitionCount = snapshot.resolvedTransitionCount
        }
    }

    private func handleInputDiagnostic(
        _ diagnostic: PagerInputDiagnostic<String>
    ) {
        inputDiagnosticCount += 1
        if diagnostic.committedID != diagnostic.visibleID {
            inputAlignmentMismatchCount += 1
        }
        lastTrace = String(
            format: "Trace: end %.2f, peak %.2f, velocity %.2f, "
                + "reversals %d, %@",
            diagnostic.trace.terminalProgress,
            diagnostic.trace.peakProgress,
            diagnostic.trace.terminalVelocityPagesPerSecond,
            diagnostic.trace.reversalCount,
            terminalPhaseText(diagnostic.trace.terminalPhase)
        )
        lastResolution = "Resolution: "
            + pagerResolutionText(diagnostic.resolutionReason)
            + ", visual \(diagnostic.visibleID ?? "none")"
    }

    private func handleSettledPagerSnapshot(
        _ snapshot: PagerContainerSnapshot<String>
    ) {
        settledSnapshotCount += 1
        controllerCount = snapshot.controllerCount
        coordinatorSequence = snapshot.coordinatorSequence
        visibleControllerSequence = snapshot.visibleControllerSequence
            ?? visibleControllerSequence
        createdControllerCount = snapshot.createdControllerCount
        contentBuildCount = snapshot.contentBuildCount
        evictedControllerCount = snapshot.evictedControllerCount
        orphanControllerCount = snapshot.orphanChildControllerCount
        let committed = snapshot.committedID ?? "none"
        let visible = snapshot.visiblePageID ?? "none"
        let sequence = snapshot.visibleControllerSequence ?? 0
        let cachedSequence = snapshot.visiblePageID.flatMap {
            snapshot.cachedControllerSequences[$0]
        } ?? 0
        settledProjectionStatus = "Settled: committed \(committed), "
            + "visible \(visible), controller \(sequence), "
            + "cached \(cachedSequence), callbacks "
            + "\(snapshot.activeCallbackDepth), overlaps "
            + "\(snapshot.rejectedOverlappingTransitionCount), sentinel "
            + "\(snapshot.teardownSentinelVisible ? 1 : 0)"
        if let geometry = snapshot.geometry {
            let coverage = geometry.coversPagerBounds
                ? "covered"
                : "uncovered"
            let background = geometry.hasOpaqueBackground
                ? "opaque"
                : "transparent"
            geometryStatus = "Geometry: \(coverage), \(background), "
                + "generation \(geometry.stateGeneration), "
                + String(
                    format: "root %.1f,%.1f %.1fx%.1f, bounds %.1f,%.1f %.1fx%.1f",
                    geometry.rootFrame.minX,
                    geometry.rootFrame.minY,
                    geometry.rootFrame.width,
                    geometry.rootFrame.height,
                    geometry.pagerBounds.minX,
                    geometry.pagerBounds.minY,
                    geometry.pagerBounds.width,
                    geometry.pagerBounds.height
                )
        }
    }

    private func handleTransitionPagerSnapshot(
        _ snapshot: PagerContainerSnapshot<String>
    ) {
        inFlightRefreshCount += 1
        let committed = snapshot.committedID ?? "none"
        let visible = snapshot.visiblePageID ?? "none"
        let sequence = snapshot.visibleControllerSequence ?? 0
        let generation = snapshot.geometry?.stateGeneration ?? 0
        let covered = snapshot.geometry?.coversPagerBounds == true
        let opaque = snapshot.geometry?.hasOpaqueBackground == true
        inFlightRefreshStatus = "In-flight: \(inFlightRefreshCount), "
            + "state \(contentState.phase.rawValue), generation \(generation), "
            + "committed \(committed), visible \(visible), "
            + "controller \(sequence), covered \(covered ? 1 : 0), "
            + "opaque \(opaque ? 1 : 0), callbacks "
            + "\(snapshot.activeCallbackDepth)"
    }

    private func applyArmedMutationDuringUIKitTransition() {
        guard let armedMutation else {
            return
        }
        apply(mutation: armedMutation)
        self.armedMutation = nil
    }

    private func apply(mutation: ArmedMutation) {
        switch mutation {
        case .insert:
            guard !pageIDs.contains("inserted") else {
                return
            }
            pageIDs.insert("inserted", at: min(2, pageIDs.count))
        case .delete:
            pageIDs.removeAll { $0 == "p0" }
        case .reorder:
            pageIDs.reverse()
        case .refresh:
            _ = contentState.beginRefreshing()
        }
    }

    private func cycleContentState() {
        switch contentState.phase {
        case .loaded:
            _ = contentState.beginRefreshing()
        case .refreshing:
            _ = contentState.beginLoadingNextPage()
        case .loadingNextPage:
            let request = contentState.beginRefreshing()
            _ = contentState.failRefresh(
                requestGeneration: request
            )
        case .refreshFailure:
            _ = contentState.beginInitialLoading()
        case .initialLoading:
            if let request = contentState.activeRequestGeneration {
                _ = contentState.failInitialLoad(
                    requestGeneration: request
                )
            }
        case .initialFailure:
            let request = contentState.beginInitialLoading()
            _ = contentState.resolveEmpty(
                requestGeneration: request
            )
        case .empty:
            restoreLoadedContent()
        }
    }

    private func injectStaleResponse() {
        if contentState.content == nil {
            contentState.setLoaded("retained-content-restored")
        }
        let staleRequest = contentState.beginRefreshing()
        let currentRequest = contentState.beginRefreshing()
        let accepted = contentState.resolveLoaded(
            "stale-content-must-not-render",
            requestGeneration: staleRequest
        )
        if !accepted {
            staleResponseRejectionCount += 1
        }
        _ = contentState.failRefresh(
            requestGeneration: currentRequest
        )
    }

    private func restoreLoadedContent() {
        contentState.setLoaded(
            "retained-content-v\(contentState.generation + 1)"
        )
    }

    private func terminalPhaseText(
        _ phase: PagerPanTerminalPhase
    ) -> String {
        switch phase {
        case .active:
            "active"
        case .ended:
            "ended"
        case .cancelled:
            "cancelled"
        case .failed:
            "failed"
        }
    }

    private func reset() {
        pageIDs = ["p0", "p1", "p2", "p3", "p4"]
        externalSelectionGeneration &+= 1
        selection = "p2"
        armedMutation = nil
        transitionState = "idle"
        liveIDs = ["p1", "p2", "p3"]
        resolvedTransitionCount = 0
        controllerCount = 3
        contentState.setLoaded("retained-content-reset")
        staleResponseRejectionCount = 0
        inputDiagnosticCount = 0
        lastTrace = "Trace: none"
        lastResolution = "Resolution: none"
        visibleControllerSequence = 0
        createdControllerCount = 0
        contentBuildCount = 0
        evictedControllerCount = 0
        orphanControllerCount = 0
        geometryStatus = "Geometry: pending"
        settledProjectionStatus = "Settled: pending"
        inFlightRefreshStatus = "In-flight: none"
        inFlightRefreshCount = 0
        inputAlignmentMismatchCount = 0
        verticalScrollStatus = "Vertical offset: 0"
    }
}

#endif
