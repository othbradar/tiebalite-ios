import SwiftUI
import UIKit

@MainActor
struct MediaViewerPage: View {
    let item: MediaViewerItem
    let imageLoader: any ImageLoading
    let isCurrent: Bool
    let shouldLoad: Bool
    let highDefinitionGeneration: UInt64
    let onQualityChanged: (MediaViewerQualityStatus) -> Void
    let onImageDiagnostics: (String) -> Void
    let onViewportDiagnostics: (String) -> Void
    let resetGeneration: UInt64
    let reduceMotion: Bool
    let ownershipController: MediaGestureOwnershipController<String>
    let onLongPress: () -> Void
    let onSingleTap: () -> Void
    let onCapabilityChanged: (MediaPageCapability, Double) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var imageState = MediaViewerImageState()
    private var phase: MediaViewerImagePhase { imageState.phase }
    private var image: UIImage? { imageState.image }
    @State private var completedOriginalGeneration: UInt64 = 0
    @State private var reloadGeneration: UInt64 = 0
    @State private var requestGeneration: UInt64 = 0
    @State private var targetPixelSize: ImageTargetPixelSize?
    @State private var zoomScale = 1.0

    var body: some View {
        ZStack {
            SemanticColor.mediaBackground

            phaseContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(SemanticColor.mediaBackground)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            let viewportMaximum = max(size.width, size.height)
            targetPixelSize = ImageTargetPixelSize.normalized(
                pointWidth: viewportMaximum,
                pointHeight: viewportMaximum,
                displayScale: displayScale,
                purpose: .mediaViewer
            )
        }
        .task(id: MediaViewerImageTaskID(
            mediaID: item.id,
            request: item.request,
            targetPixelSize: targetPixelSize,
            reloadGeneration: reloadGeneration,
            highDefinitionGeneration: highDefinitionGeneration, shouldLoad: shouldLoad, isCurrent: isCurrent
        ), priority: isCurrent ? .userInitiated : .utility) {
            await loadImage()
        }
        .onChange(of: resetGeneration) { _, _ in
            if zoomScale != 1 {
                zoomScale = 1
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .idle, .loading:
            VStack {
                ProgressView(MediaViewerCopy.loading)
                    .tint(.white)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SemanticColor.mediaBackground)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.accessibilityLabel)
            .accessibilityValue(MediaViewerCopy.loading)
            .accessibilityIdentifier(
                MediaViewerAccessibilityID.state(item.id, phase: .loading)
            )
        case .rendered:
            if let image {
                MediaZoomImageView(
                    mediaID: item.id,
                    image: image,
                    preservesViewportOnImageChange: true,
                    resetGeneration: resetGeneration,
                    reduceMotion: reduceMotion,
                    ownershipController: ownershipController,
                    surfaceAccessibilityIdentifier:
                        MediaViewerAccessibilityID.image(item.id),
                    surfaceAccessibilityLabel: item.accessibilityLabel,
                    surfaceAccessibilityValue:
                        MediaViewerCopy.zoomAccessibilityValue(zoomScale),
                    surfaceAccessibilityHint: MediaViewerCopy.zoomHint,
                    onLongPress: onLongPress,
                    onSingleTap: onSingleTap,
                    onCapabilityChanged: { capability, scale in
                        if zoomScale != scale {
                            zoomScale = scale
                        }
                        onCapabilityChanged(capability, scale)
                    },
                    onViewportMetricsChanged: { metrics in
#if UITESTING
                        onViewportDiagnostics(String(
                            format: "x=%.2f y=%.2f zoom=%.2f",
                            metrics.contentOffsetX, metrics.contentOffsetY, metrics.zoomScale))
#endif
                    }
                )
                .accessibilityAction(named: Text("图片操作")) {
                    if zoomScale <= 1.01 { onLongPress() }
                }
            }
        case .failedToFetch:
            failureContent(
                message: MediaViewerCopy.fetchFailure,
                phase: .failedToFetch
            )
        case .failedToDecode:
            failureContent(
                message: MediaViewerCopy.decodeFailure,
                phase: .failedToDecode
            )
        case .cancelled:
            failureContent(
                message: MediaViewerCopy.cancelled,
                phase: .cancelled
            )
        }
    }

    private func failureContent(
        message: String,
        phase: MediaViewerImagePhase
    ) -> some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: IconSize.large))
                .accessibilityHidden(true)
            Text(message)
                .font(Typography.font(.body))
            Button(MediaViewerCopy.retry) {
                reloadGeneration &+= 1
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(MediaViewerCopy.retryHint)
            .accessibilityIdentifier(
                MediaViewerAccessibilityID.retry(item.id)
            )
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.mediaBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityValue(message)
        .accessibilityIdentifier(
            MediaViewerAccessibilityID.state(item.id, phase: phase)
        )
    }

    private func loadImage() async {
        requestGeneration &+= 1
        let generation = requestGeneration
        guard shouldLoad, let targetPixelSize else { return }
        guard isCurrent || image == nil else { return }
        let highDefinition = highDefinitionGeneration > 0 && isCurrent
        if highDefinition, image != nil, completedOriginalGeneration == highDefinitionGeneration { return }
        guard item.request.isLoadable else {
            imageState.apply(.init(phase: .failedToFetch, image: nil))
            return
        }
        imageState.begin()
        if image == nil {
            zoomScale = 1
            onCapabilityChanged(.minimumZoom, 1)
        }
        if highDefinition { onQualityChanged(.loading) }
        do {
            let outcome = try await MediaViewerImageLoad.resolve(
                request: (highDefinition ? item.request.originalOnly : item.request).imageRequest(
                    purpose: .mediaViewer,
                    targetPixelSize: highDefinition ? ImageCachePolicy.highDefinitionSize : targetPixelSize
                ), using: imageLoader)
            guard requestGeneration == generation, !Task.isCancelled else { return }
            imageState.apply(outcome)
            if highDefinition {
                if outcome.image != nil { completedOriginalGeneration = highDefinitionGeneration }
                onQualityChanged(outcome.image == nil ? .failed : .high)
            }
#if DEBUG
            await publishDiagnostics(outcome, generation: generation)
#endif
        } catch {
            // A disappearing page releases its subscription; a cache clear may cancel an otherwise active request.
            guard requestGeneration == generation, !Task.isCancelled else { return }
            let phase: MediaViewerImagePhase = error is CancellationError ? .cancelled : .failedToFetch
            imageState.apply(.init(phase: phase, image: nil))
            if highDefinition { onQualityChanged(.failed) }
        }
    }

#if DEBUG
    private func publishDiagnostics(_ outcome: MediaViewerImageLoadOutcome, generation: UInt64) async {
        guard let loader = imageLoader as? ProductionImageLoader else { return }
        let counts = await loader.imageCacheDiagnostics()
        guard requestGeneration == generation, !Task.isCancelled else { return }
        let width = Int((outcome.image?.size.width ?? 0) * (outcome.image?.scale ?? 1))
        let height = Int((outcome.image?.size.height ?? 0) * (outcome.image?.scale ?? 1))
        onImageDiagnostics("pixels=\(width)x\(height) disk=\(counts.diskHits)"
            + " network=\(counts.networkRequests) merged=\(counts.merged)")
    }
#endif

}

private struct MediaViewerImageTaskID: Hashable {
    let mediaID: String
    let request: ThreadImageRequestDescriptor
    let targetPixelSize: ImageTargetPixelSize?
    let reloadGeneration: UInt64
    let highDefinitionGeneration: UInt64
    let shouldLoad: Bool
    let isCurrent: Bool
}

enum MediaViewerCopy {
    static let cancelled = "图片加载已取消"
    static let close = "关闭图片查看器"
    static let decodeFailure = "图片无法显示"
    static let fetchFailure = "图片加载失败"
    static let loading = "图片加载中"
    static let next = "下一张图片"
    static let previous = "上一张图片"
    static let retry = "重新加载"
    static let retryHint = "重新请求并显示这张图片"
    static let zoomHint = "双击或捏合以缩放，放大后可平移"

    static func zoomAccessibilityValue(_ scale: Double) -> String {
        scale <= 1.01
            ? "原始大小"
            : String(format: "已放大 %.2f 倍", scale)
    }
}

enum MediaViewerAccessibilityID {
    static let chrome = "media-viewer.chrome"
    static let close = "media-viewer.close"
    static let next = "media-viewer.next"
    static let pager = "media-viewer.pager"
    static let previous = "media-viewer.previous"

    static func image(_ mediaID: String) -> String {
        "media-viewer.image.\(mediaID)"
    }

    static func retry(_ mediaID: String) -> String {
        "media-viewer.retry.\(mediaID)"
    }

    static func state(
        _ mediaID: String,
        phase: MediaViewerImagePhase
    ) -> String {
        "media-viewer.state.\(mediaID).\(phase.identifierComponent)"
    }
}

private extension MediaViewerImagePhase {
    var identifierComponent: String {
        switch self {
        case .cancelled:
            "cancelled"
        case .failedToDecode:
            "decode-failure"
        case .failedToFetch:
            "fetch-failure"
        case .idle:
            "idle"
        case .loading:
            "loading"
        case .rendered:
            "rendered"
        }
    }
}
