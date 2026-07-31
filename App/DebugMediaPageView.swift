#if DEBUG
import SwiftUI
import UIKit

@MainActor
struct DebugMediaPage: View {
    let fixture: DebugMediaFixture
    let delayedReleased: Bool
    let failureRecovered: Bool
    let retryFailure: () -> Void
    let toggleChrome: () -> Void
    let capabilityChanged: (MediaPageCapability, Double) -> Void

    var body: some View {
        ZStack {
            Color.black

            Text("Media item \(fixture.id)")
                .font(Typography.font(.caption))
                .foregroundStyle(Color.white)
                .padding(Spacing.xSmall)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .allowsHitTesting(false)
                .accessibilityIdentifier(
                    "interaction.media.item.\(fixture.id)"
                )

            switch fixture.kind {
            case .delayed where !delayedReleased:
                ProgressView("等待显式释放")
                    .tint(Color.white)
                    .foregroundStyle(Color.white)
                    .accessibilityIdentifier(
                        "interaction.media.loading.delayed"
                    )
            case .failure where !failureRecovered:
                VStack(spacing: Spacing.medium) {
                    Text("固定图片加载失败")
                        .foregroundStyle(Color.white)
                        .accessibilityIdentifier(
                            "interaction.media.error.failure"
                        )
                    Button("使用本地 fixture 重试", action: retryFailure)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(
                            "interaction.media.retry.failure"
                        )
                }
            default:
                if let image = resolvedImage {
                    DebugZoomImageView(
                        mediaID: fixture.id,
                        image: image,
                        onSingleTap: toggleChrome,
                        onCapabilityChanged: capabilityChanged
                    )
                }
            }
        }
    }

    private var resolvedImage: UIImage? {
        if fixture.kind == .failure {
            return DebugMediaFixture(
                id: fixture.id,
                kind: .small
            ).image
        }
        return fixture.image
    }
}

struct DebugMediaPresentation: Identifiable {
    let id: String
    let items: [DebugMediaFixture]
    let initialID: String
}

@MainActor
struct DebugMediaLabView: View {
    @State private var presentation: DebugMediaPresentation?

    var body: some View {
        VStack(spacing: Spacing.large) {
            Text("Media source anchor")
                .font(Typography.font(.headline))
                .accessibilityIdentifier("interaction.media.source-anchor")

            Text(
                presentation == nil
                    ? "Overlay: absent"
                    : "Overlay: presented"
            )
            .accessibilityIdentifier("interaction.media.overlay-state")

            Button("打开单图") {
                presentation = DebugMediaPresentation(
                    id: "single",
                    items: [DebugMediaFixture.all[0]],
                    initialID: "small"
                )
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("interaction.media.open.single")

            Button("打开多图") {
                presentation = DebugMediaPresentation(
                    id: "multiple",
                    items: DebugMediaFixture.all,
                    initialID: "large"
                )
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("interaction.media.open.multiple")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenCover(item: $presentation) { presentation in
            DebugMediaViewer(
                presentation: presentation,
                close: {
                    self.presentation = nil
                }
            )
        }
    }
}

@MainActor
private struct DebugMediaViewer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.motionReductionOverride) private var reductionOverride

    let presentation: DebugMediaPresentation
    let close: () -> Void

    @State private var currentID: String?
    @State private var chromeVisible = true
    @State private var delayedReleased = false
    @State private var failureRecovered = false
    @State private var capabilityByID: [
        String: MediaPageCapability
    ] = [:]
    @State private var zoomScaleByID: [String: Double] = [:]
    @State private var transitionSourceID: String?

    init(
        presentation: DebugMediaPresentation,
        close: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.close = close
        _currentID = State(initialValue: presentation.initialID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PagerContainer(
                pageIDs: presentation.items.map(\.id),
                selection: $currentID,
                backgroundColor: .black,
                reduceMotion: reduceMotion || reductionOverride,
                pagingEnabled: pagingEnabled,
                onEvent: handlePagerEvent
            ) { mediaID in
                mediaPage(for: mediaID)
            }
            .accessibilityLabel("Media Pager")
            .accessibilityValue(positionText)
            .accessibilityAdjustableAction { direction in
                moveMediaAccessibility(direction)
            }

            statusOverlay

            if chromeVisible {
                chrome
            }
        }
        .accessibilityAction(.escape, closeViewer)
    }

    private var statusOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.small) {
                Text("Media Viewer")
                    .accessibilityIdentifier("interaction.media.viewer")
                Text("Current: \(currentID ?? "none")")
                    .accessibilityIdentifier("interaction.media.current-id")
                Text("Position: \(positionText)")
                    .accessibilityIdentifier("interaction.media.position")
                Text("Zoom: \(zoomScaleText)")
                    .accessibilityIdentifier("interaction.media.zoom-state")
                Text("Boundary: \(boundaryText)")
                    .accessibilityIdentifier(
                        "interaction.media.horizontal-boundary"
                    )
                Text("Owner: \(ownerText)")
                    .accessibilityIdentifier(
                        "interaction.media.gesture-owner"
                    )
            }
            .font(Typography.font(.caption))
            .foregroundStyle(Color.white)
            .padding(Spacing.small)
            .background(Color.black.opacity(0.78))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(false)
    }

    private var chrome: some View {
        VStack {
            HStack(spacing: Spacing.small) {
                Text("Chrome")
                    .accessibilityIdentifier("interaction.media.chrome")

                Button("关闭", action: closeViewer)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("interaction.media.close")

                Button("上一张") {
                    moveMedia(by: -1)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveMedia(by: -1))
                .accessibilityIdentifier(
                    "interaction.media.accessibility.previous"
                )

                Button("下一张") {
                    moveMedia(by: 1)
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveMedia(by: 1))
                .accessibilityIdentifier(
                    "interaction.media.accessibility.next"
                )

                if currentID == "delayed", !delayedReleased {
                    Button("释放延迟图") {
                        delayedReleased = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        "interaction.media.release-delayed"
                    )
                }

                Spacer()
            }
            .padding(Spacing.medium)
            .background(Color.black.opacity(0.78))

            Spacer()
        }
    }

    @ViewBuilder
    private func mediaPage(for mediaID: String) -> some View {
        if let fixture = presentation.items.first(where: {
            $0.id == mediaID
        }) {
            DebugMediaPage(
                fixture: fixture,
                delayedReleased: delayedReleased,
                failureRecovered: failureRecovered,
                retryFailure: {
                    failureRecovered = true
                },
                toggleChrome: {
                    chromeVisible.toggle()
                },
                capabilityChanged: { capability, scale in
                    capabilityByID[mediaID] = capability
                    zoomScaleByID[mediaID] = scale
                }
            )
        } else {
            Color.black
        }
    }

    private var currentCapability: MediaPageCapability {
        guard let currentID else {
            return .minimumZoom
        }
        return capabilityByID[currentID] ?? .minimumZoom
    }

    private var pagingEnabled: Bool {
        currentCapability.atMinimumZoom
            || currentCapability.horizontalBoundary != .interior
    }

    private var positionText: String {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return "0/0"
        }
        return "\(index + 1)/\(presentation.items.count)"
    }

    private var zoomScaleText: String {
        guard let currentID else {
            return "1.00"
        }
        return String(format: "%.2f", zoomScaleByID[currentID] ?? 1)
    }

    private func moveMediaAccessibility(
        _ direction: AccessibilityAdjustmentDirection
    ) {
        switch direction {
        case .increment:
            moveMedia(by: 1)
        case .decrement:
            moveMedia(by: -1)
        @unknown default:
            return
        }
    }

    private func canMoveMedia(by offset: Int) -> Bool {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return false
        }
        return presentation.items.indices.contains(index + offset)
    }

    private func moveMedia(by offset: Int) {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return
        }
        let targetIndex = index + offset
        guard presentation.items.indices.contains(targetIndex) else {
            return
        }
        self.currentID = presentation.items[targetIndex].id
    }

    private var boundaryText: String {
        switch currentCapability.horizontalBoundary {
        case .both:
            "both"
        case .interior:
            "interior"
        case .leading:
            "leading"
        case .trailing:
            "trailing"
        }
    }

    private var ownerText: String {
        currentCapability.atMinimumZoom ? "pager" : "zoom-page"
    }

    private func handlePagerEvent(
        _ event: PagerContainerEvent<String>
    ) {
        switch event {
        case let .began(transition):
            transitionSourceID = transition.sourceID
        case let .resolved(_, completed):
            guard completed,
                  let transitionSourceID else {
                self.transitionSourceID = nil
                return
            }
            capabilityByID[transitionSourceID] = .minimumZoom
            zoomScaleByID[transitionSourceID] = 1
            self.transitionSourceID = nil
        }
    }

    private func closeViewer() {
        capabilityByID.removeAll(keepingCapacity: false)
        zoomScaleByID.removeAll(keepingCapacity: false)
        transitionSourceID = nil
        close()
    }
}
#endif
