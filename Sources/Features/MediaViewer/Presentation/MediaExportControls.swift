import SwiftUI

/// Only in-progress or dismissible result feedback; image actions live in the long-press menu.
struct MediaExportControls: View {
    @Environment(\.openURL) private var openURL
    let store: MediaExportStore

    var body: some View {
        if !store.statusText.isEmpty {
            VStack(spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    if store.isBusy && store.shareFile == nil { ProgressView().tint(.white) }
                    Text(store.statusText)
                        .font(Typography.font(.caption))
                        .accessibilityIdentifier("media-viewer.export.status")
                    if !store.isBusy {
                        Button(action: store.dismissFeedback) {
                            Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("关闭保存结果")
                        .accessibilityIdentifier("media-viewer.export.dismiss")
                    }
                }
                if store.failure != nil {
                    HStack {
                        Button("重试", action: store.retry).accessibilityIdentifier("media-viewer.export.retry")
                        if store.failure == .permissionDenied {
                            Button("打开设置") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }.accessibilityIdentifier("media-viewer.export.settings")
                        } else {
                            Button("分享这张图片", action: store.shareCapturedImage)
                                .accessibilityIdentifier("media-viewer.export.share-captured")
                        }
                    }.font(Typography.font(.body))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.small)
            .background(Color.black.opacity(0.72))
        }
    }
}
