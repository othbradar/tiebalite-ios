#if DEBUG
import SwiftUI

@MainActor
struct DebugScenarioMenuView: View {
    let openGallery: () -> Void
    let openInteractionLab: () -> Void
    let openThreadContentRenderer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("调试场景")
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)

            Button(action: openGallery) {
                Label("组件画廊", systemImage: "paintpalette")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AppAccessibilityID.debugOpenGallery)

            Button(action: openInteractionLab) {
                Label("交互实验室", systemImage: "rectangle.3.group")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(
                AppAccessibilityID.debugOpenInteractionLab
            )

            Button(action: openThreadContentRenderer) {
                Label("正文 Renderer Lab", systemImage: "text.page")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(
                AppAccessibilityID.debugOpenThreadContentRenderer
            )
        }
    }
}

@MainActor
struct DebugComponentGalleryView: View {
    private static let isolationCanary = "TIEBALITE_DEBUG_GALLERY_CANARY"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.motionReductionOverride) private var reductionOverride

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text(Self.isolationCanary)
                    .frame(width: 0, height: 0)
                    .hidden()
                    .accessibilityHidden(true)

                environmentSummary

                InitialLoadingView()
                InlineLoadingView()
                EmptyStateView(
                    title: "暂无内容",
                    message: "固定 fixture 的空状态。",
                    systemImage: "tray"
                )
                FullPageErrorView(
                    title: "加载失败",
                    message: "固定 fixture 的整页错误。",
                    retry: {}
                )
                InlineErrorView(
                    message: "固定 fixture 的行内错误。",
                    retry: {}
                )
                PaginationFooter(state: .end, retry: {})
            }
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .navigationTitle("组件画廊")
        .accessibilityIdentifier(AppAccessibilityID.galleryRoot)
    }

    private var environmentSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(
                colorScheme == .dark
                    ? "Appearance: Dark"
                    : "Appearance: Light"
            )
            .accessibilityIdentifier(AppAccessibilityID.galleryAppearance)

            Text(
                dynamicTypeSize.isAccessibilitySize
                    ? "Dynamic Type: Accessibility"
                    : "Dynamic Type: Standard"
            )
            .accessibilityIdentifier(AppAccessibilityID.galleryDynamicType)

            Text(
                reduceMotion || reductionOverride
                    ? "Reduce Motion: On"
                    : "Reduce Motion: Off"
            )
                .accessibilityIdentifier(AppAccessibilityID.galleryReduceMotion)
        }
        .font(Typography.font(.body))
        .foregroundStyle(SemanticColor.primaryText)
    }
}
#endif
