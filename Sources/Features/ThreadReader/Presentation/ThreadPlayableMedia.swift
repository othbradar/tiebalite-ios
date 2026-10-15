import AVKit
import SwiftUI

@MainActor
struct ThreadVoicePlayerView: View {
    let owner: String
    let source: MediaPlaybackSource?
    @State private var playback = MediaPlaybackController.shared

    private var isOwner: Bool { playback.state.owner == owner }
    private var active: Bool { isOwner && [.playing, .loading].contains(playback.state.phase) }
    private var failed: Bool { isOwner && playback.state.phase == .failed }

    var body: some View {
        Button {
            if let source { playback.toggle(owner: owner, source: source) }
        } label: {
            HStack(spacing: Spacing.medium) {
                Image(systemName: failed ? "arrow.clockwise" : (active ? "pause.fill" : "play.fill"))
                ProgressView(value: isOwner ? playback.state.fraction : 0)
                    .tint(SemanticColor.primaryText)
                Text(timeLabel).monospacedDigit().font(Typography.font(.caption))
            }
            .padding(Spacing.medium)
            .frame(maxWidth: 280, minHeight: 44)
            .background(SemanticColor.surface, in: RoundedRectangle(cornerRadius: CornerRadius.small))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(source == nil)
        .accessibilityLabel(source == nil ? "语音不可用" : (failed ? "播放失败，重试" : (active ? "暂停语音" : "播放语音")))
        .accessibilityValue(timeLabel)
        .accessibilityIdentifier("media.voice.\(owner)")
        .background {
            if isOwner { MediaVisibilityObserver { if !$0 { playback.stop(owner: owner) } } }
        }
        .onDisappear { playback.stop(owner: owner) }
    }

    private var timeLabel: String {
        if source == nil { return "不可用" }
        if failed { return "重试" }
        guard isOwner, playback.state.duration > 0 else { return "语音" }
        return "\(Int(playback.state.elapsed)) / \(Int(playback.state.duration.rounded(.up))) 秒"
    }
}

@MainActor
struct ThreadVideoPlayerView: View {
    let owner: String
    let content: ThreadVideoContent
    let imageLoader: any ImageLoading
    let onOpenExternalLink: (ExternalLinkIntent) -> Void
    var sourceOverride: MediaPlaybackSource?
    @State private var playback = MediaPlaybackController.shared
    @State private var poster: UIImage?
    private var isOwner: Bool { playback.state.owner == owner }
    private var source: MediaPlaybackSource? {
        sourceOverride ?? content.videoTarget.flatMap { MediaPlaybackSource.video($0.absoluteString) }
    }

    var body: some View {
        Color.clear
            .aspectRatio(content.dimensions.layoutAspectRatio, contentMode: .fit)
            .background(SemanticColor.surface)
            .overlay {
                if isOwner, playback.state.phase != .failed, let player = playback.player {
                    SystemMediaPlayer(player: player)
                        .accessibilityIdentifier("media.video.inline.\(owner)")
                } else {
                    if let poster { Image(uiImage: poster).resizable().scaledToFit() }
                    playButton
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .background {
                MediaVisibilityObserver(minimumVisibleFraction: 0.5) { visible in
                    playback.updateVideoVisibility(owner: owner, source: source, visible: visible)
                }
            }
        .task(id: content.thumbnail) {
            guard let thumbnail = content.thumbnail else { return }
            do {
                let request = thumbnail.imageRequest(purpose: .listThumbnail, targetPixelSize: .default(for: .listThumbnail))
                let payload = try await imageLoader.load(request)
                try Task.checkCancellation()
                poster = payload.displayImage()
            } catch is CancellationError { return } catch { poster = nil }
        }
        .onDisappear { playback.updateVideoVisibility(owner: owner, source: nil, visible: false) }
    }

    private var playButton: some View {
        let failed = isOwner && playback.state.phase == .failed
        return Button {
            if let source { playback.play(owner: owner, source: source) } else if let intent = content.externalIntent {
                onOpenExternalLink(intent)
            }
        } label: {
            ZStack {
                Color.clear.contentShape(Rectangle())
                if failed {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(Typography.font(.caption)).padding(Spacing.medium)
                        .background(SemanticColor.surface, in: Capsule())
                } else {
                    Image(systemName: source != nil || content.externalIntent != nil ? "play.circle.fill" : "video.slash")
                        .font(.largeTitle).foregroundStyle(SemanticColor.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(source == nil && content.externalIntent == nil)
        .accessibilityLabel(failed ? "播放失败，重试" :
            (source != nil ? "播放视频" : (content.externalIntent != nil ? "打开视频网页" : "视频不可用")))
        .accessibilityIdentifier(failed ? "media.video.retry.\(owner)" : "media.video.\(owner)")
    }
}
