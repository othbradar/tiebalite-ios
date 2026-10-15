import AVKit
import Foundation
import GeneratedProtobuf
import ImageIO
import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@Suite("U13 bounded media")
struct U13MediaPlaybackTests {
    @Test(arguments: [320.0, 600.0, 1024.0]) @MainActor
    func systemVideoPlayerWorksInsideProductionCellHosting(width: Double) async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 800))
        let parent = UIViewController()
        window.rootViewController = parent
        let player = AVPlayer()
        let content = UIHostingConfiguration { SystemMediaPlayer(player: player) }.makeContentView()
        content.frame = CGRect(x: 0, y: 0, width: width, height: 180)
        parent.view.addSubview(content)
        window.isHidden = false
        parent.view.layoutIfNeeded()
        await Task.yield()
        content.layoutIfNeeded()
        let embedded = parent.children.compactMap { $0 as? AVPlayerViewController }.first
        #expect(embedded?.player === player)
        content.removeFromSuperview()
        #expect(parent.children.isEmpty)
        window.isHidden = true
    }

    @Test func autoplayOnlyStartsVisibleVideoWithoutTakingOverAnotherOwner() throws {
        let source = try #require(MediaPlaybackSource.video("https://fixture.invalid/video.mp4"))
        var policy = VideoAutoplayState()
        policy.update(owner: "one", source: source, visible: true)
        #expect(policy.next(currentOwner: nil) == nil)
        policy.mode = .automatic
        #expect(policy.next(currentOwner: nil)?.owner == "one")
        policy.update(owner: "two", source: source, visible: true)
        #expect(policy.next(currentOwner: "one") == nil) // Includes paused, ended and failed owners.
        #expect(policy.next(currentOwner: "voice") == nil)
        policy.suspendVisible()
        #expect(policy.next(currentOwner: nil) == nil)
        policy.update(owner: "one", source: nil, visible: false)
        policy.update(owner: "one", source: source, visible: true)
        #expect(policy.next(currentOwner: nil)?.owner == "one")
        policy.update(owner: "one", source: nil, visible: false)
        #expect(policy.next(currentOwner: nil) == nil)
    }

    @Test func videoPlaybackPreferenceSurvivesRestartAndDefaultsToClick() async throws {
        let suite = "U13.video-playback.preference"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsAppSettingsRepository(suiteName: suite)
        var snapshot = await repository.load()
        #expect(snapshot.videoPlaybackMode == .manual)
        snapshot.videoPlayback = .automatic
        snapshot.readingTextSize = .large
        try await repository.save(snapshot)
        let restored = await UserDefaultsAppSettingsRepository(suiteName: suite).load()
        #expect(restored == snapshot)
        defaults.set("unknown", forKey: "dev.tiebalite.settings.video-playback.v1")
        #expect(await repository.load().videoPlaybackMode == .manual)
    }

    @Test @MainActor func videoMustMostlyEnterTheViewportBeforeAutoplay() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let scroll = UIScrollView(frame: window.bounds)
        window.addSubview(scroll)
        window.isHidden = false
        scroll.contentSize = CGSize(width: 320, height: 2_000)
        let probe = MediaVisibilityProbe(frame: CGRect(x: 0, y: 580, width: 320, height: 1_000))
        probe.minimumVisibleFraction = 0.5
        var visible = false
        probe.onChange = { visible = $0 }
        scroll.addSubview(probe)
        probe.sample()
        #expect(!visible)
        scroll.contentOffset.y = 500
        probe.sample()
        #expect(visible) // A tall portrait video can fill the viewport without fitting in full.
        scroll.contentOffset.y = 1_500
        probe.sample()
        #expect(!visible)
        probe.removeFromSuperview()
        window.isHidden = true
    }

    @Test @MainActor func animationFrameReplacementDoesNotRebuildZoomGeometry() throws {
        let first = try #require(UIImage(data: TestImageFixtureFactory.png(width: 240, height: 160)))
        let next = try #require(UIImage(data: TestImageFixtureFactory.png(width: 240, height: 160)))
        let scroll = MediaZoomScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = MediaZoomImageView(mediaID: "animated", image: first, preservesViewportOnImageChange: true,
                                      onSingleTap: {}, onCapabilityChanged: { _, _ in })
        let coordinator = view.makeCoordinator()
        coordinator.install(on: scroll)
        defer { coordinator.dismantle(scroll) }
        scroll.configure(image: first, mediaID: "animated")
        scroll.layoutIfNeeded()
        scroll.setZoomScale(2.5, animated: false)
        scroll.layoutIfNeeded()
        scroll.contentOffset = CGPoint(x: 100, y: 20)
        let before = scroll.viewportMetrics
        scroll.replaceImagePreservingViewport(next)
        scroll.layoutIfNeeded()
        #expect(scroll.viewportMetrics.layoutGeneration == before.layoutGeneration)
        #expect(scroll.contentOffset == CGPoint(x: 100, y: 20))
        #expect(scroll.zoomScale == 2.5)
        #expect(scroll.mediaImageView.image === next)
    }

    @Test func verifiedVideoCDNUpgradesTLSWithoutChangingPathOrQuery() throws {
        var node = Tieba_PbContent()
        node.type = 5
        node.link = "http://tb-video.bdstatic.com/example.mp4?token=a%2Bb&time=123"
        node.src = "https://fixture.invalid/poster.jpg"
        node.bsize = "320,180"
        let source = ThreadContentSource(threadID: 1, postID: 2, scope: .firstPost)
        let document = ThreadContentProtoMapper.map(postContent: [node], source: source, availability: .available)
        guard case let .video(video) = document.nodes[0].payload else { Issue.record("Missing video node"); return }
        #expect(video.videoTarget?.absoluteString == "https://tb-video.bdstatic.com/example.mp4?token=a%2Bb&time=123")
        #expect(video.hasThumbnail)
        #expect(MediaPlaybackSource.video("http://tb-video.bdstatic.com.evil.invalid/v.mp4") == nil)
        #expect(MediaPlaybackSource.video("http://tb-video.bdstatic.com:8080/v.mp4") == nil)
    }

    @Test @MainActor func clippedUIKitMediaStopsReportingVisible() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let scroll = UIScrollView(frame: window.bounds)
        window.addSubview(scroll)
        window.isHidden = false
        scroll.contentSize = CGSize(width: 320, height: 2_000)
        let probe = MediaVisibilityProbe(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        var visible = false
        probe.onChange = { visible = $0 }
        scroll.addSubview(probe)
        probe.sample()
        #expect(visible)
        scroll.contentOffset.y = 700
        probe.sample()
        #expect(!visible)
        probe.removeFromSuperview()
        probe.sample()
        #expect(!visible)
        scroll.contentOffset.y = 0
        scroll.addSubview(probe)
        probe.sample()
        #expect(visible)
        probe.removeFromSuperview()
        window.isHidden = true
    }

    @Test func voiceURLUsesIOSReadPathAndEscapesResource() throws {
        let url = try #require(MediaPlaybackSource.voice(resourceID: "a&b=1")?.url)
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.host == "tiebac.baidu.com")
        #expect(parts.path == "/c/p/voice")
        #expect(parts.queryItems == [URLQueryItem(name: "voice_md5", value: "a&b=1")])
        #expect(MediaPlaybackSource.voice(resourceID: nil) == nil)
        #expect(MediaPlaybackSource.video("http://fixture.invalid/video") == nil)
        #expect(MediaPlaybackSource.video("https://user:secret@fixture.invalid/video") == nil)
    }

    @Test func switchingOwnersAndLateCallbacksCannotRevivePreviousPlayback() {
        var state = MediaPlaybackState()
        let first = state.begin(owner: "first")
        let second = state.begin(owner: "second")
        state.update(ticket: first, phase: .playing, elapsed: 4, duration: 8)
        #expect(state.owner == "second")
        #expect(state.phase == .loading)
        state.update(ticket: second, phase: .playing, elapsed: 2, duration: 8)
        #expect(state.fraction == 0.25)
        state.stop(owner: "first")
        #expect(state.owner == "second")
        state.stop(owner: "second")
        state.update(ticket: second, phase: .playing, elapsed: 3, duration: 8)
        #expect(state.owner == nil)
        #expect(state.phase == .idle)
    }

    @Test func nonfiniteProgressAndFinishedPlaybackAreBounded() {
        var state = MediaPlaybackState()
        let ticket = state.begin(owner: "voice")
        state.update(ticket: ticket, phase: .paused, elapsed: .infinity, duration: .nan)
        #expect(state.elapsed == 0 && state.duration == 0 && state.fraction == 0)
        state.update(ticket: ticket, phase: .ended, elapsed: 15, duration: 8)
        #expect(state.fraction == 1)
    }

    @Test(arguments: ["gif", "webp"])
    func animatedFormatsDecodeDifferentBoundedFrames(ext: String) async throws {
        let data = try fixture("bounded", ext)
        let resource = try #require(AnimatedImageResource.inspect(data: data))
        #expect(resource.frameCount == 4)
        #expect(resource.data == data)
        let first = try await resource.frame(at: 0, maximumDimension: 96)
        let next = try await resource.frame(at: 1, maximumDimension: 96)
        #expect(max(first.image.size.width, first.image.size.height) <= 96)
        #expect(first.image.pngData() != next.image.pngData())
        #expect(abs(first.delay - 0.12) < 0.02)
        #expect(abs(next.delay - 0.18) < 0.02)
    }

    @Test func oversizedAndMalformedAnimationStayStatic() throws {
        #expect(AnimatedImageResource.inspect(data: Data([0, 1, 2])) == nil)
        let data = try fixture("bounded", "gif")
        #expect(AnimatedImageResource.inspect(data: data, byteLimit: 1) == nil)
        #expect(AnimatedImageResource.inspect(data: data, pixelLimit: 1) == nil)
        #expect(AnimatedImageResource.inspect(data: data, frameLimit: 1) == nil)
    }

    private func fixture(_ name: String, _ ext: String) throws -> Data {
        let root = Bundle(for: U13MediaBundleMarker.self).resourceURL
        let url = try #require(root?.appendingPathComponent("Fixtures/Media/\(name).\(ext)"))
        return try Data(contentsOf: url)
    }
}

private final class U13MediaBundleMarker: NSObject {}
