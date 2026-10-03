import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct U06MediaQualityTests {
    @Test func higherResolutionSameMediaKeepsZoomAndVisibleCenter() throws {
        let small = try #require(UIImage(data: TestImageFixtureFactory.png(width: 200, height: 300)))
        let high = try #require(UIImage(data: TestImageFixtureFactory.png(width: 800, height: 1_200)))
        let scroll = MediaZoomScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = zoomView(small)
        let coordinator = view.makeCoordinator()
        coordinator.install(on: scroll)
        scroll.configure(image: small, mediaID: "same")
        scroll.layoutIfNeeded()
        scroll.setZoomScale(2.5, animated: false)
        scroll.layoutIfNeeded()
        scroll.contentOffset = CGPoint(x: 220, y: 390)
        let before = scroll.viewportMetrics
        coordinator.parent = zoomView(high)
        coordinator.synchronizeContent(on: scroll)
        scroll.layoutIfNeeded()
        let after = scroll.viewportMetrics
        #expect(scroll.mediaImageView.image === high)
        #expect(scroll.mediaID == "same")
        #expect(abs(after.zoomScale - before.zoomScale) < 0.001)
        #expect(abs(after.visibleFocalPointX - before.visibleFocalPointX) < 0.002)
        #expect(abs(after.visibleFocalPointY - before.visibleFocalPointY) < 0.002)
        coordinator.dismantle(scroll)
    }

    @Test func failedUpgradeKeepsDisplayedImageAndAllowsRetry() throws {
        let image = try #require(UIImage(data: TestImageFixtureFactory.png(width: 40, height: 20)))
        var state = MediaViewerImageState()
        state.apply(.init(phase: .rendered, image: image))
        state.begin()
        #expect(state.image === image)
        #expect(state.phase == .rendered)
        state.apply(.init(phase: .failedToFetch, image: nil))
        #expect(state.image === image)
        #expect(state.phase == .rendered)
        #expect(state.upgradeFailed)
        state.begin()
        #expect(!state.upgradeFailed)
        #expect(state.image === image)
    }

    @Test func zoomedViewportAllowsFreeSingleAndTwoFingerPan() {
        let scroll = MediaZoomScrollView()
        #expect(!scroll.isDirectionalLockEnabled)
        #expect(scroll.panGestureRecognizer.minimumNumberOfTouches == 1)
        #expect(scroll.panGestureRecognizer.maximumNumberOfTouches >= 2)
        #expect(scroll.pinchGestureRecognizer?.isEnabled == true)
    }

    @Test func productionOwnershipKeepsZoomedEdgePan() {
        for boundary: MediaHorizontalBoundary in [.both, .leading, .trailing, .interior] {
            let session = MediaGestureSession<String>.begin(
                gestureSessionID: 1, generation: 1, mediaID: "same",
                evidence: .init(
                    zoomScale: 2.5, contentOffset: .zero, velocity: CGPoint(x: -100, y: -20),
                    translation: CGPoint(x: -20, y: -4),
                    capability: .init(atMinimumZoom: false, horizontalBoundary: boundary), intent: .towardNext),
                allowsZoomedPaging: false)
            #expect(session.owner == .mediaPan)
        }
        #expect(MediaViewerQualityStatus.screen.title == "加载原图")
    }

    @Test func longPressIsRemovedWithViewportAndUnavailableWhenZoomed() throws {
        let image = try #require(UIImage(data: TestImageFixtureFactory.png(width: 200, height: 300)))
        let scroll = MediaZoomScrollView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = zoomView(image)
        let coordinator = view.makeCoordinator()
        coordinator.install(on: scroll)
        scroll.configure(image: image, mediaID: "same")
        scroll.layoutIfNeeded()
        let actions = MediaImageActionGesture(on: scroll, action: {})
        let press = try #require(actions.recognizer)
        #expect(press.numberOfTouchesRequired == 1)
        scroll.setZoomScale(2.5, animated: false)
        #expect(!actions.gestureRecognizerShouldBegin(press))
        actions.dismantle()
        #expect(press.view == nil)
        #expect(press.delegate == nil)
        #expect(actions.recognizer == nil)
        coordinator.dismantle(scroll)
    }

    private func zoomView(_ image: UIImage) -> MediaZoomImageView {
        MediaZoomImageView(mediaID: "same", image: image, preservesViewportOnImageChange: true,
                           onSingleTap: {}, onCapabilityChanged: { _, _ in })
    }
}
