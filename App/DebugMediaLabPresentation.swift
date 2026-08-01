#if DEBUG
import SwiftUI
import UIKit

@MainActor
struct DebugMediaPage: View {
    let fixture: DebugMediaFixture
    let delayedReleased: Bool
    let failureRecovered: Bool
    let resetGeneration: UInt64
    let reduceMotion: Bool
    let ownershipController: MediaGestureOwnershipController<String>
    let retryFailure: () -> Void
    let toggleChrome: () -> Void
    let capabilityChanged: (MediaPageCapability, Double) -> Void
    let inputMetricsChanged: (DebugMediaInputMetrics) -> Void
    let viewportMetricsChanged: (DebugMediaViewportMetrics) -> Void

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
                        resetGeneration: resetGeneration,
                        reduceMotion: reduceMotion,
                        ownershipController: ownershipController,
                        onSingleTap: toggleChrome,
                        onCapabilityChanged: capabilityChanged,
                        onInputMetricsChanged: inputMetricsChanged,
                        onViewportMetricsChanged: viewportMetricsChanged
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        }
    }
}
#endif
