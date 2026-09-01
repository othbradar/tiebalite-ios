import SwiftUI
import UIKit

@MainActor
struct MediaViewerPage: View {
    let item: MediaViewerItem
    let imageLoader: any ImageLoading
    let resetGeneration: UInt64
    let reduceMotion: Bool
    let ownershipController: MediaGestureOwnershipController<String>
    let onSingleTap: () -> Void
    let onCapabilityChanged: (MediaPageCapability, Double) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var phase = MediaViewerImagePhase.idle
    @State private var image: UIImage?
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
            reloadGeneration: reloadGeneration
        )) {
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
                    resetGeneration: resetGeneration,
                    reduceMotion: reduceMotion,
                    ownershipController: ownershipController,
                    surfaceAccessibilityIdentifier:
                        MediaViewerAccessibilityID.image(item.id),
                    surfaceAccessibilityLabel: item.accessibilityLabel,
                    surfaceAccessibilityValue:
                        MediaViewerCopy.zoomAccessibilityValue(zoomScale),
                    surfaceAccessibilityHint: MediaViewerCopy.zoomHint,
                    onSingleTap: onSingleTap,
                    onCapabilityChanged: { capability, scale in
                        if zoomScale != scale {
                            zoomScale = scale
                        }
                        onCapabilityChanged(capability, scale)
                    }
                )
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
        image = nil
        zoomScale = 1
        onCapabilityChanged(.minimumZoom, 1)
        phase = .loading
        guard item.request.isLoadable else {
            phase = .failedToFetch
            return
        }
        guard let targetPixelSize else {
            phase = .idle
            return
        }
        do {
            let outcome = try await MediaViewerImageLoad.resolve(
                request: item.request.imageRequest(
                    purpose: .mediaViewer,
                    targetPixelSize: targetPixelSize
                ),
                using: imageLoader
            )
            guard requestGeneration == generation,
                  !Task.isCancelled else {
                return
            }
            image = outcome.image
            phase = outcome.phase
        } catch is CancellationError {
            guard requestGeneration == generation else {
                return
            }
            phase = .cancelled
        } catch {
            guard requestGeneration == generation else {
                return
            }
            phase = .failedToFetch
        }
    }
}

private struct MediaViewerImageTaskID: Hashable {
    let mediaID: String
    let request: ThreadImageRequestDescriptor
    let targetPixelSize: ImageTargetPixelSize?
    let reloadGeneration: UInt64
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
