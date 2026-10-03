import SwiftUI

struct MediaExportControls: View {
    @Environment(\.openURL) private var openURL
    let store: MediaExportStore
    let request: ImageExportRequest?

    var body: some View {
        VStack(spacing: Spacing.small) {
            if !store.statusText.isEmpty {
                HStack(spacing: Spacing.small) {
                    if store.isBusy && store.shareFile == nil { ProgressView().tint(.white) }
                    Text(store.statusText)
                        .font(Typography.font(.caption))
                        .accessibilityIdentifier("media-viewer.export.status")
                }
                .padding(.horizontal, Spacing.small)
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
            HStack {
                Button {
                    if let request { store.start(request, action: .save) }
                } label: {
                    Label("保存图片", systemImage: "square.and.arrow.down").frame(minHeight: 44)
                }
                .accessibilityIdentifier("media-viewer.export.save")
                Spacer()
                Button {
                    if let request { store.start(request, action: .share) }
                } label: {
                    Label("分享／存文件", systemImage: "square.and.arrow.up").frame(minHeight: 44)
                }
                .accessibilityIdentifier("media-viewer.export.share")
                .background {
                    ImageFileSharePresenter(file: store.shareFile, began: store.shareDidPresent, completion: store.shareFinished)
                }
            }
            .font(Typography.font(.body))
            .disabled(store.isBusy || request == nil)
            .padding(.horizontal, Spacing.medium)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.top, Spacing.small)
        .background(Color.black.opacity(0.72))
    }
}
