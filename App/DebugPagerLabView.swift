#if DEBUG
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

    @State private var pageIDs = ["p0", "p1", "p2", "p3", "p4"]
    @State private var selection: String? = "p2"
    @State private var armedMutation: ArmedMutation?
    @State private var transitionState = "idle"
    @State private var liveIDs = ["p1", "p2", "p3"]
    @State private var resolvedTransitionCount = 0
    @State private var controllerCount = 3
    @State private var coordinatorSequence: UInt64 = 0
    @State private var pagerViewportHeight: CGFloat = 0
    @State private var refreshing = false

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
    }

    private var controlPanel: some View {
        VStack(spacing: Spacing.small) {
            statusGrid
            pagerAccessibilityControls
            mutationControls
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
            Text(refreshing ? "Refresh: active" : "Refresh: idle")
                .accessibilityIdentifier("interaction.pager.refresh-state")
            Text("Viewport height: \(Int(pagerViewportHeight.rounded()))")
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
                .accessibilityIdentifier(
                    "interaction.pager.exposure-sentinel"
                )

            PagerContainer(
                pageIDs: pageIDs,
                selection: $selection,
                backgroundColor: .black,
                reduceMotion: reduceMotion || reductionOverride,
                onEvent: handlePagerEvent
            ) { pageID in
                DebugOpaquePagerPage(pageID: pageID)
            }
            .accessibilityLabel("Pager")
            .accessibilityValue(positionText)
            .accessibilityAdjustableAction { direction in
                movePagerAccessibility(direction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            pagerViewportHeight = height
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
                mutationButton(.refresh, title: "非空刷新")
            }

            Button("重置", action: reset)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(
                    "interaction.pager.action.reset"
                )
        }
    }

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
            controllerCount = snapshot.controllerCount
            coordinatorSequence = snapshot.coordinatorSequence
            refreshing = false
        }
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
            refreshing = true
        }
    }

    private func reset() {
        pageIDs = ["p0", "p1", "p2", "p3", "p4"]
        selection = "p2"
        armedMutation = nil
        transitionState = "idle"
        liveIDs = ["p1", "p2", "p3"]
        resolvedTransitionCount = 0
        controllerCount = 3
        refreshing = false
    }
}

@MainActor
private struct DebugOpaquePagerPage: View {
    let pageID: String

    var body: some View {
        ZStack {
            color
            VStack(spacing: Spacing.small) {
                Text(pageID.uppercased())
                    .font(.system(size: 56, weight: .black))
                Text("Opaque stable PageID")
                    .font(Typography.font(.headline))
            }
            .foregroundStyle(Color.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pager page \(pageID)")
        .accessibilityIdentifier("interaction.pager.page.\(pageID)")
    }

    private var color: Color {
        switch pageID {
        case "p0":
            Color(red: 0.60, green: 0.05, blue: 0.12)
        case "p1":
            Color(red: 0.04, green: 0.32, blue: 0.62)
        case "p2":
            Color(red: 0.08, green: 0.48, blue: 0.22)
        case "p3":
            Color(red: 0.42, green: 0.16, blue: 0.62)
        case "p4":
            Color(red: 0.75, green: 0.32, blue: 0.02)
        default:
            Color(red: 0.18, green: 0.18, blue: 0.18)
        }
    }
}
#endif
