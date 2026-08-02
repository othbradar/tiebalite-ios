#if DEBUG
import SwiftUI

@MainActor
struct DebugOpaquePagerPage: View {
    let pageID: String
    let phase: PagerContentPhase
    let content: String?
    let generation: UInt64
    let retryInitialFailure: () -> Void
    let onVerticalScrollOffsetChange: (String, CGFloat) -> Void

    @Environment(\.debugPagerControllerSequence)
    private var controllerSequence
    @State private var retainedHitCount = 0
    @State private var verticalScrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            SemanticColor.background
            stateContent
            if phase.isRetainedActivity {
                retainedStateBadge
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pager page \(pageID)")
        .accessibilityIdentifier("interaction.pager.page.\(pageID)")
    }

    @ViewBuilder
    private var stateContent: some View {
        switch phase {
        case .loaded, .refreshing, .loadingNextPage, .refreshFailure:
            retainedContent
        case .initialLoading:
            InitialLoadingView(title: "Pager fixture initial loading")
        case .initialFailure:
            FullPageErrorView(
                title: "Pager fixture initial failure",
                message: "Deterministic offline failure",
                retry: retryInitialFailure
            )
        case .empty:
            EmptyStateView(
                title: "Pager fixture empty",
                message: "No retained content",
                systemImage: "rectangle.stack"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SemanticColor.background)
        }
    }

    private var retainedContent: some View {
        ZStack {
            color
            ScrollView(.vertical) {
                VStack(spacing: Spacing.small) {
                    Text(pageID.uppercased())
                        .font(.system(size: 56, weight: .black))
                    Text(content ?? "missing-retained-content")
                        .font(Typography.font(.headline))
                    Text("Controller: \(controllerSequence)")
                        .accessibilityIdentifier(
                            "interaction.pager.page.\(pageID)"
                                + ".controller-sequence"
                        )
                    Text("Generation: \(generation)")
                        .accessibilityIdentifier(
                            "interaction.pager.page.\(pageID).generation"
                        )
                    Button("Content hits: \(retainedHitCount)") {
                        retainedHitCount += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(
                        "interaction.pager.page.\(pageID).content-action"
                    )
                    ForEach(1...8, id: \.self) { row in
                        Text("Vertical fixture row \(row)")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.vertical, Spacing.medium)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.white)
            .accessibilityIdentifier(
                "interaction.pager.page.\(pageID).vertical-scroll"
            )
            .accessibilityValue(
                "Offset: \(Int(verticalScrollOffset.rounded()))"
            )
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offset in
                verticalScrollOffset = offset
                onVerticalScrollOffsetChange(pageID, offset)
            }
        }
    }

    private var retainedStateBadge: some View {
        VStack {
            Text("State: \(phase.rawValue)")
                .font(Typography.font(.caption))
                .padding(Spacing.small)
                .foregroundStyle(SemanticColor.primaryText)
                .background(SemanticColor.surface)
                .clipShape(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                )
                .accessibilityIdentifier(
                    "interaction.pager.page.\(pageID).state-badge"
                )
            Spacer()
        }
        .padding(Spacing.small)
        .allowsHitTesting(false)
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

private extension PagerContentPhase {
    var isRetainedActivity: Bool {
        switch self {
        case .refreshing, .loadingNextPage, .refreshFailure:
            true
        case .loaded, .initialLoading, .initialFailure, .empty:
            false
        }
    }
}
#endif
