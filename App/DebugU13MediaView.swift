#if DEBUG
import SwiftUI

@MainActor
struct DebugU13MediaView: View {
    var onOpenURL: (URL) -> Void = { _ in }
    @State private var threadLink = ""
    @State private var playback = MediaPlaybackController.shared
    @State private var images: [String: ImagePayload] = [:]
    @State private var reduceMotion = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                Text("\(playback.status.owner ?? "none") \(String(describing: playback.status.phase))")
                    .accessibilityIdentifier("u13.state")
                ThreadVoicePlayerView(owner: "fixture.voice1", source: local("voice.m4a"))
                ThreadVoicePlayerView(owner: "fixture.voice2", source: local("voice.m4a"))
                video(owner: "fixture.video", source: local("video.mp4"))
                Toggle("减少动态效果", isOn: $reduceMotion).accessibilityIdentifier("u13.reduce")
                ForEach(["gif", "webp"], id: \.self) { ext in
                    if let payload = images[ext], let image = payload.displayImage() {
                        AnimatedMediaImage(image: image, resource: payload.animation,
                                           targetPixelSize: .init(width: 480, height: 320),
                                           unavailable: payload.animationUnavailable, reduceMotionOverride: reduceMotion) { frame in
                            Image(uiImage: frame).resizable().scaledToFit()
                        }
                        .frame(height: 160)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("u13.\(ext)")
                    }
                }
                video(owner: "fixture.failure", source: .init(url: URL(fileURLWithPath: "/missing-u13-video.mp4")))
                TextField("帖子链接", text: $threadLink).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("u13.thread-link")
                Button("打开帖子") {
                    if let url = URL(string: threadLink) { onOpenURL(url) }
                }.accessibilityIdentifier("u13.thread-open")
                ForEach(0..<12) { index in Text("合成内容 \(index)").frame(height: 80) }
            }
            .padding()
        }
        .navigationTitle("U13 媒体")
        .accessibilityIdentifier("u13.gallery")
        .task {
            let loader = ProductionImageLoader(loader: DebugU13MediaLoader())
            for ext in ["gif", "webp"] {
                let request = ImageRequest(resourceID: "u13.\(ext)", candidateURLs: ["https://fixture.invalid/bounded.\(ext)"],
                                           targetPixelSize: .init(width: 480, height: 320), purpose: .threadContent)
                do { images[ext] = try await loader.load(request) } catch { return }
            }
        }
    }

    private func local(_ name: String) -> MediaPlaybackSource? {
        Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "DebugU13Media").map { .init(url: $0) }
    }

    private func video(owner: String, source: MediaPlaybackSource?) -> some View {
        let content = ThreadVideoContent(
            thumbnail: nil, dimensions: .known(width: 320, height: 180), videoTarget: nil, externalIntent: nil)
        return ThreadVideoPlayerView(
            owner: owner, content: content, imageLoader: DisabledImageLoader(),
            onOpenExternalLink: { _ in }, sourceOverride: source)
            .frame(maxHeight: 190)
    }
}

private struct DebugU13MediaLoader: HTTPDataLoading {
    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let local = Bundle.main.url(forResource: url.lastPathComponent, withExtension: nil, subdirectory: "DebugU13Media"),
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "image/\(url.pathExtension)"])
        else { throw ImageLoadingError.missingFixture }
        let data = try await ImageDecodeExecutor.run { try Data(contentsOf: local) }
        return (data, response)
    }
}
#endif
