import SwiftUI

/// Only the current and in-flight frame exist. Task cancellation discards late worker results.
@MainActor
struct AnimatedMediaImage<Content: View>: View {
    let image: UIImage
    let resource: AnimatedImageResource?
    var unavailable = false
    var allowsPlaybackControl = true
    var isCurrent = true
    var reduceMotionOverride = false
    @ViewBuilder let content: (UIImage) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var explicitlyPlaying = false
    @State private var frame: UIImage?
    @State private var failed = false

    private var permitted: Bool {
        resource != nil && visible && isCurrent && scenePhase == .active
            && (!(reduceMotion || reduceMotionOverride) || explicitlyPlaying)
    }

    var body: some View {
        content(frame ?? image)
            .background {
                if resource != nil { MediaVisibilityObserver { visible = $0 } }
            }
            .overlay(alignment: .bottomTrailing) {
                if unavailable || failed {
                    Text("动图以静态显示").font(.caption2)
                        .padding(Spacing.small).background(SemanticColor.surface)
                        .accessibilityIdentifier("media.animation.static")
                } else if resource != nil, allowsPlaybackControl, reduceMotion || reduceMotionOverride {
                    Button {
                        explicitlyPlaying.toggle()
                    } label: {
                        Image(systemName: explicitlyPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 44, height: 44).background(SemanticColor.surface)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(explicitlyPlaying ? "暂停动图" : "播放动图")
                    .accessibilityIdentifier("media.animation.toggle")
                }
            }
            .task(id: "\(resource?.id ?? "static").\(permitted)") {
                guard permitted, let resource else { frame = nil; return }
                failed = false
                do {
                    var index = 0
                    var loops = 0
                    while !Task.isCancelled {
                        let next = try await resource.frame(at: index, maximumDimension: 1_024)
                        try Task.checkCancellation()
                        frame = next.image
                        // Media timing from the encoded frame, not a UI/state synchronization delay.
                        try await Task.sleep(for: .seconds(next.delay))
                        index += 1
                        if index == resource.frameCount {
                            loops += 1
                            if resource.loopCount > 0, loops >= resource.loopCount { break }
                            index = 0
                        }
                    }
                } catch is CancellationError {
                    return
                } catch {
                    frame = nil
                    failed = true
                }
            }
            .onDisappear { visible = false; frame = nil; explicitlyPlaying = false }
    }
}
