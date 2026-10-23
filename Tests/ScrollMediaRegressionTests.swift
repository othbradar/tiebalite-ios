import Observation
import SwiftUI
import Synchronization
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct ScrollMediaRegressionTests {
        @Test func animatedFramesUseOuterSizeWithoutRestartingForPosterAspect() async throws {
            let url = try #require(Bundle(for: SFMediaMarker.self).resourceURL?.appendingPathComponent("Fixtures/Media/bounded.gif"))
            let resource = try #require(AnimatedImageResource.inspect(data: Data(contentsOf: url)))
            // A poster with a different ratio must not feed frame geometry back into the decode task identity.
            let poster = try #require(UIImage(data: TestImageFixtureFactory.png(width: 64, height: 48)))
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
            let size = SFAnimationSize()
            window.rootViewController = UIHostingController(rootView: SFAnimationHost(image: poster, resource: resource, size: size))
            ScrollWorkMetrics.start()
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            let recorder = ScrollFrameWindow()
            _ = await recorder.run(frames: 120) { _ in 0 }
            let first = ScrollWorkMetrics.stop()
            #expect(first["gif.frame", default: 0] >= 5)
            #expect(first["gif.source", default: 0] == 1)
            ScrollWorkMetrics.start()
            size.width = 240
            _ = await recorder.run(frames: 120) { _ in 0 }
            let resized = ScrollWorkMetrics.stop()
            #expect(resized["gif.frame", default: 0] >= 5)
            #expect(resized["gif.source", default: 0] == 1)
        }

        @Test(arguments: ["gif", "webp"])
        func playbackReusesOneSourceAndKeepsFrameOutputBounded(ext: String) async throws {
            let url = try #require(Bundle(for: SFMediaMarker.self).resourceURL?.appendingPathComponent("Fixtures/Media/bounded.\(ext)"))
            let resource = try #require(AnimatedImageResource.inspect(data: Data(contentsOf: url)))
            ScrollWorkMetrics.start()
            for index in [0, 1, 2, 3, 0] { _ = try await resource.frame(at: index, maximumDimension: 96) }
            #expect(ScrollWorkMetrics.stop()["gif.source", default: 0] == 5) // Original one-shot baseline.
            var decoder: AnimatedImageDecoder? = .init(resource: resource)
            weak var weakDecoder = decoder
            ScrollWorkMetrics.start()
            var first: Data?
            for (offset, index) in [0, 1, 2, 3, 0].enumerated() {
                let next = try await decoder?.frame(at: index, maximumDimension: offset == 2 ? 192 : 96)
                let frame = try #require(next)
                #expect(max(frame.image.size.width, frame.image.size.height) <= (offset == 2 ? 192 : 96))
                if offset == 0 { first = frame.image.pngData() }
                if offset == 1 { #expect(first != frame.image.pngData()) }
                if offset == 4 { #expect(first == frame.image.pngData()) }
            }
            #expect(ScrollWorkMetrics.stop()["gif.source", default: 0] == 1)
            decoder = nil
            #expect(weakDecoder == nil)
            weakDecoder = nil
            let cancelled = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await AnimatedImageDecoder(resource: resource).frame(at: 0, maximumDimension: 96)
            }
            ScrollWorkMetrics.start()
            do { _ = try await cancelled.value; Issue.record("Cancelled decode returned a frame") } catch is CancellationError {
                #expect(ScrollWorkMetrics.stop()["gif.source", default: 0] == 0)
            } catch { Issue.record("Unexpected error: \(error)") }
        }

        @Test func progressTicksDoNotInvalidateIdleRowsButStateChangesDo() {
            let presentation = MediaPlaybackPresentation()
            var state = MediaPlaybackState()
            let ticket = state.begin(owner: "voice")
            state.update(ticket: ticket, phase: .playing, elapsed: 0, duration: 200)
            presentation.update(state)
            let statusChanges = Mutex(0), progressChanges = Mutex(0)
            withObservationTracking { _ = presentation.status } onChange: { statusChanges.withLock { $0 += 1 } }
            withObservationTracking { _ = presentation.progress } onChange: { progressChanges.withLock { $0 += 1 } }
            for tick in 1...100 {
                state.update(ticket: ticket, phase: .playing, elapsed: Double(tick), duration: 200)
                presentation.update(state)
            }
            #expect(statusChanges.withLock { $0 } == 0)
            #expect(progressChanges.withLock { $0 } == 1)
            #expect(presentation.progress.fraction == 0.5)
            state.stop(owner: "voice"); presentation.update(state)
            #expect(statusChanges.withLock { $0 } == 1)
            #expect(presentation.status.owner == nil && presentation.progress.elapsed == 0)
            let before = presentation.status
            state.update(ticket: ticket, phase: .playing, elapsed: 5, duration: 8); presentation.update(state)
            #expect(presentation.status == before && presentation.progress.elapsed == 0)
        }

        @Test func mountedIdleMediaContentDoesNotRebuildOnProgress() async throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
            let presentation = MediaPlaybackPresentation(), counts = SFMediaBodyCounts()
            let controller = UIHostingController(rootView: VStack {
                SFObservedMediaRow(presentation: presentation, owner: "idle", counts: counts)
                SFObservedMediaRow(presentation: presentation, owner: "voice", counts: counts)
            })
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true }
            var state = MediaPlaybackState()
            let ticket = state.begin(owner: "voice")
            state.update(ticket: ticket, phase: .playing, elapsed: 0, duration: 8); presentation.update(state)
            try #require(await VirtualListNativeCondition.wait {
                counts.values["idle", default: 0] > 0 && counts.values["voice", default: 0] > 0
            })
            let idle = counts.values["idle", default: 0], active = counts.values["voice", default: 0]
            state.update(ticket: ticket, phase: .playing, elapsed: 2, duration: 8); presentation.update(state)
            try #require(await VirtualListNativeCondition.wait { counts.values["voice", default: 0] > active })
            #expect(counts.values["idle", default: 0] == idle)
        }
    }
}

private final class SFMediaMarker: NSObject {}
@MainActor @Observable private final class SFAnimationSize { var width = 320 }
private struct SFAnimationHost: View {
    let image: UIImage
    let resource: AnimatedImageResource
    let size: SFAnimationSize
    var body: some View {
        Color.clear.frame(width: CGFloat(size.width), height: 180).overlay {
            AnimatedMediaImage(image: image, resource: resource, targetPixelSize: .init(width: size.width, height: 180)) {
                Image(uiImage: $0).resizable().scaledToFit()
            }
        }
        .environment(\.scenePhase, .active)
    }
}
@MainActor private final class SFMediaBodyCounts { var values: [String: Int] = [:] }
private struct SFObservedMediaRow: View {
    let presentation: MediaPlaybackPresentation
    let owner: String
    let counts: SFMediaBodyCounts
    var body: some View {
        counts.values[owner, default: 0] += 1
        return Text(presentation.status.owner == owner ? "\(presentation.progress.elapsed)" : "idle")
    }
}
