import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct MediaInteractionControllerTests {
    @Test
    func ownershipGateInstallsOnceWithoutReplacingUIKitPanDelegate() throws {
        var selection: String? = "large"
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        let ownership = MediaGestureOwnershipController<String>()
        let pager = PagerContainer(
            pageIDs: ["large", "small"],
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true,
            mediaGestureOwnership: ownership
        ) { pageID in
            Text(pageID)
        }
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        let pagerScrollView = try #require(
            controller.view.subviews.compactMap { $0 as? UIScrollView }.first
        )
        let originalPanDelegate = pagerScrollView.panGestureRecognizer.delegate
        let originalMaximumTouches = pagerScrollView.panGestureRecognizer
            .maximumNumberOfTouches
        let originalRecognizerCount = controller.view.gestureRecognizers?.count
            ?? 0

        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        #expect(ownership.ownershipGateRecognizer != nil)
        #expect(
            (controller.view.gestureRecognizers?.count ?? 0)
                == originalRecognizerCount + 1
        )
        #expect(pagerScrollView.panGestureRecognizer.delegate === originalPanDelegate)
        #expect(pagerScrollView.panGestureRecognizer.maximumNumberOfTouches == 1)
        #expect(ownership.pagerCoordinatorSequence > 0)

        coordinator.synchronize(controller)
        #expect(
            (controller.view.gestureRecognizers?.count ?? 0)
                == originalRecognizerCount + 1
        )
        coordinator.dismantle(controller)
        #expect(ownership.ownershipGateRecognizer == nil)
        #expect(
            (controller.view.gestureRecognizers?.count ?? 0)
                == originalRecognizerCount
        )
        #expect(pagerScrollView.panGestureRecognizer.delegate === originalPanDelegate)
        #expect(
            pagerScrollView.panGestureRecognizer.maximumNumberOfTouches
                == originalMaximumTouches
        )
        #expect(ownership.pagerCoordinatorSequence == 0)
    }

    @Test
    func ownershipSwapRemovesTheOldGateAndRestoresPagerConfiguration() throws {
        var selection: String? = "large"
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        let firstOwnership = MediaGestureOwnershipController<String>()
        let secondOwnership = MediaGestureOwnershipController<String>()
        var pager = makeMediaPager(
            selection: binding,
            ownership: firstOwnership
        )
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        let pagerScrollView = try #require(
            controller.view.subviews.compactMap { $0 as? UIScrollView }.first
        )
        pagerScrollView.panGestureRecognizer.maximumNumberOfTouches = 4
        let originalRecognizerCount = controller.view.gestureRecognizers?.count
            ?? 0

        coordinator.install(on: controller)
        coordinator.synchronize(controller)
        let firstGate = try #require(firstOwnership.ownershipGateRecognizer)
        #expect(pagerScrollView.panGestureRecognizer.maximumNumberOfTouches == 1)

        pager = makeMediaPager(
            selection: binding,
            ownership: secondOwnership
        )
        coordinator.parent = pager
        coordinator.synchronize(controller)

        #expect(firstOwnership.ownershipGateRecognizer == nil)
        #expect(secondOwnership.ownershipGateRecognizer != nil)
        #expect(
            controller.view.gestureRecognizers?.contains(where: {
                $0 === firstGate
            }) == false
        )
        #expect(
            (controller.view.gestureRecognizers?.count ?? 0)
                == originalRecognizerCount + 1
        )
        #expect(pagerScrollView.panGestureRecognizer.maximumNumberOfTouches == 1)

        coordinator.dismantle(controller)
        #expect(secondOwnership.ownershipGateRecognizer == nil)
        #expect(pagerScrollView.panGestureRecognizer.maximumNumberOfTouches == 4)
        #expect(
            (controller.view.gestureRecognizers?.count ?? 0)
                == originalRecognizerCount
        )
    }

    @Test
    func unknownImageReplacementClearsThePreviousZoomedImageGeometry() {
        let oldImage = makeImage(size: CGSize(width: 2_048, height: 2_048))
        let unknownImage = UIImage()
        let scrollView = DebugZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        scrollView.configure(image: oldImage, mediaID: "old")
        scrollView.layoutIfNeeded()
        scrollView.setZoomScale(3, animated: false)
        scrollView.contentOffset = CGPoint(x: 200, y: 300)

        scrollView.configure(image: unknownImage, mediaID: "unknown")
        scrollView.layoutIfNeeded()

        #expect(scrollView.mediaID == "unknown")
        #expect(scrollView.mediaImageView.image === unknownImage)
        #expect(scrollView.mediaImageView.image !== oldImage)
        #expect(scrollView.zoomScale == scrollView.minimumZoomScale)
        #expect(scrollView.mediaImageView.frame.size == scrollView.bounds.size)
        #expect(scrollView.backgroundColor == .black)
        #expect(scrollView.mediaImageView.backgroundColor == .black)
        expectLegalContentOffset(scrollView)
        expectImageFrameIntersectsViewport(scrollView)
    }

    @Test
    func attachingZoomViewportPublishesUsableWindowGeometry() {
        let image = makeImage(size: CGSize(width: 512, height: 512))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let scrollView = DebugZoomScrollView(frame: window.bounds)
        var metrics: [DebugMediaViewportMetrics] = []
        scrollView.onLayoutMetricsChanged = { metrics.append($0) }
        scrollView.configure(image: image, mediaID: "attached")
        scrollView.layoutIfNeeded()

        #expect(metrics.last?.attachedToWindow == false)

        window.addSubview(scrollView)
        window.layoutIfNeeded()
        scrollView.layoutIfNeeded()

        #expect(metrics.last?.attachedToWindow == true)
        #expect(metrics.last?.hasFiniteLegalGeometry == true)
        #expect(metrics.last?.windowWidth == 320)
        #expect(metrics.last?.windowHeight == 480)
        scrollView.removeFromSuperview()
    }

    @Test
    func staleMediaPagerCompletionCannotOverwriteNewerSelection() throws {
        var selection: String? = "large"
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        let ownership = MediaGestureOwnershipController<String>()
        var pager = makeMediaPager(
            selection: binding,
            ownership: ownership
        )
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(ownership.gestureRecognizerShouldBegin(gate))
        let visible = try #require(controller.viewControllers?.first)
        let pending = try #require(
            coordinator.pageViewController(
                controller,
                viewControllerAfter: visible
            )
        )
        coordinator.pageViewController(
            controller,
            willTransitionTo: [pending]
        )
        ownership.finishActiveSession(as: .ended)

        selection = "small"
        ownership.mediaDidChange(to: selection)
        pager = makeMediaPager(selection: binding, ownership: ownership)
        coordinator.parent = pager
        coordinator.synchronize(controller)
        coordinator.pageViewController(
            controller,
            didFinishAnimating: true,
            previousViewControllers: [visible],
            transitionCompleted: true
        )

        #expect(selection == "small")
        coordinator.dismantle(controller)
    }

    @Test
    func cancelledMediaPagerSessionCannotCommitACompletedUIKitTransition() throws {
        var selection: String? = "large"
        var events: [PagerContainerEvent<String>] = []
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        let ownership = MediaGestureOwnershipController<String>()
        let pager = makeMediaPager(
            selection: binding,
            ownership: ownership,
            onEvent: { events.append($0) }
        )
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(ownership.gestureRecognizerShouldBegin(gate))
        let visible = try #require(controller.viewControllers?.first)
        let pending = try #require(
            coordinator.pageViewController(
                controller,
                viewControllerAfter: visible
            )
        )
        coordinator.pageViewController(
            controller,
            willTransitionTo: [pending]
        )
        ownership.finishActiveSession(as: .cancelled)
        coordinator.pageViewController(
            controller,
            didFinishAnimating: true,
            previousViewControllers: [visible],
            transitionCompleted: true
        )

        #expect(selection == "large")
        let resolvedEvent = try #require(events.last)
        switch resolvedEvent {
        case let .resolved(snapshot, completed):
            #expect(!completed)
            #expect(snapshot.committedID == "large")
        case .began:
            Issue.record("Expected a resolved Pager event")
        }
        coordinator.dismantle(controller)
    }

    @Test
    func ownershipGateResetClearsARecognizerFailureSession() throws {
        let ownership = MediaGestureOwnershipController<String>()
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let pagerPan = UIPanGestureRecognizer()
        root.addGestureRecognizer(pagerPan)
        ownership.install(
            on: root,
            pagerPanRecognizer: pagerPan,
            currentMediaID: { "large" }
        )
        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(ownership.gestureRecognizerShouldBegin(gate))
        #expect(ownership.activeSession != nil)

        gate.reset()

        #expect(ownership.activeSession == nil)
        #expect(ownership.lastSession?.phase == .failed)
        ownership.uninstall()
    }
}
extension MediaInteractionControllerTests {
    @Test
    func extremeAspectFitContentExcludesLetterboxFromPanRange() {
        let fixtures = [
            ("wide", CGSize(width: 4_096, height: 64)),
            ("tall", CGSize(width: 64, height: 4_096))
        ]
        for (mediaID, imageSize) in fixtures {
            let image = makeImage(size: imageSize)
            let scrollView = DebugZoomScrollView(
                frame: CGRect(x: 0, y: 0, width: 320, height: 480)
            )
            let view = DebugZoomImageView(
                mediaID: mediaID,
                image: image,
                onSingleTap: {},
                onCapabilityChanged: { _, _ in }
            )
            let coordinator = view.makeCoordinator()
            coordinator.install(on: scrollView)
            scrollView.configure(image: image, mediaID: mediaID)
            scrollView.layoutIfNeeded()
            scrollView.setZoomScale(2.5, animated: false)
            scrollView.layoutIfNeeded()
            expectAspectFitGeometry(
                scrollView,
                imageSize: imageSize,
                mediaID: mediaID
            )
            expectLegalContentOffset(scrollView)
            coordinator.dismantle(scrollView)
        }
    }
    @Test
    func sameMediaIDReregistersWhenOwnershipControllerChanges() throws {
        let image = makeImage(size: CGSize(width: 2_048, height: 2_048))
        let firstOwnership = MediaGestureOwnershipController<String>()
        let secondOwnership = MediaGestureOwnershipController<String>()
        let scrollView = DebugZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        var view = makeZoomView(
            image: image,
            ownership: firstOwnership
        )
        let coordinator = view.makeCoordinator()
        coordinator.install(on: scrollView)
        scrollView.configure(image: image, mediaID: "stable")
        scrollView.layoutIfNeeded()
        scrollView.setZoomScale(2.5, animated: false)
        scrollView.layoutIfNeeded()
        let range = scrollView.legalContentOffsetRange
        scrollView.contentOffset = CGPoint(
            x: (range.minimumX + range.maximumX) / 2,
            y: (range.minimumY + range.maximumY) / 2
        )
        #expect(scrollView.capability.horizontalBoundary == .interior)
        view = makeZoomView(image: image, ownership: secondOwnership)
        coordinator.parent = view
        coordinator.synchronizeRegistration(on: scrollView)
        #expect(try gestureOwner(for: firstOwnership) == .pager)
        #expect(try gestureOwner(for: secondOwnership) == .mediaPan)
        firstOwnership.uninstall()
        secondOwnership.uninstall()
        coordinator.dismantle(scrollView)
    }
    @Test
    func resizeClampsAnEdgeFocalPointToTheNewLegalBoundary() {
        let image = makeImage(size: CGSize(width: 2_048, height: 2_048))
        let scrollView = DebugZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        scrollView.configure(image: image, mediaID: "square-edge")
        scrollView.layoutIfNeeded()
        scrollView.setZoomScale(2.5, animated: false)
        scrollView.layoutIfNeeded()
        let oldRange = scrollView.legalContentOffsetRange
        scrollView.contentOffset = CGPoint(
            x: oldRange.maximumX,
            y: oldRange.maximumY
        )

        scrollView.frame = CGRect(x: 0, y: 0, width: 844, height: 390)
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()

        let newRange = scrollView.legalContentOffsetRange
        #expect(abs(scrollView.contentOffset.x - newRange.maximumX) <= 0.5)
        expectLegalContentOffset(scrollView)
    }
}

private extension MediaInteractionControllerTests {
    private func makeZoomView(
        image: UIImage,
        ownership: MediaGestureOwnershipController<String>
    ) -> DebugZoomImageView {
        DebugZoomImageView(
            mediaID: "stable",
            image: image,
            ownershipController: ownership,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
    }

    private func gestureOwner(
        for ownership: MediaGestureOwnershipController<String>
    ) throws -> MediaGestureOwner {
        let root = UIView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        let pagerPan = UIPanGestureRecognizer()
        root.addGestureRecognizer(pagerPan)
        ownership.install(
            on: root,
            pagerPanRecognizer: pagerPan,
            currentMediaID: { "stable" }
        )
        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)
        #expect(ownership.gestureRecognizerShouldBegin(gate))
        return try #require(ownership.lastSession).owner
    }

    private func makeMediaPager(
        selection: Binding<String?>,
        ownership: MediaGestureOwnershipController<String>,
        onEvent: @escaping (PagerContainerEvent<String>) -> Void = { _ in }
    ) -> PagerContainer<String, Text> {
        PagerContainer(
            pageIDs: ["large", "delayed", "small"],
            selection: selection,
            backgroundColor: .black,
            reduceMotion: true,
            mediaGestureOwnership: ownership,
            onEvent: onEvent
        ) { pageID in
            Text(pageID)
        }
    }

    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func normalizedVisibleCenter(
        _ scrollView: DebugZoomScrollView
    ) -> CGPoint {
        CGPoint(
            x: (scrollView.contentOffset.x + scrollView.bounds.width / 2)
                / max(scrollView.contentSize.width, 1),
            y: (scrollView.contentOffset.y + scrollView.bounds.height / 2)
                / max(scrollView.contentSize.height, 1)
        )
    }

    private func contentOffset(
        centering focalPoint: CGPoint,
        in scrollView: DebugZoomScrollView
    ) -> CGPoint {
        let range = scrollView.legalContentOffsetRange
        let desired = CGPoint(
            x: focalPoint.x * scrollView.contentSize.width
                - scrollView.bounds.width / 2,
            y: focalPoint.y * scrollView.contentSize.height
                - scrollView.bounds.height / 2
        )
        return CGPoint(
            x: min(range.maximumX, max(range.minimumX, desired.x)),
            y: min(range.maximumY, max(range.minimumY, desired.y))
        )
    }

    private func normalizedVisibleCenter(
        afterClamping focalPoint: CGPoint,
        in scrollView: DebugZoomScrollView
    ) -> CGPoint {
        let offset = contentOffset(centering: focalPoint, in: scrollView)
        return CGPoint(
            x: (offset.x + scrollView.bounds.width / 2)
                / max(scrollView.contentSize.width, 1),
            y: (offset.y + scrollView.bounds.height / 2)
                / max(scrollView.contentSize.height, 1)
        )
    }

    private func expectLegalContentOffset(_ scrollView: DebugZoomScrollView) {
        let range = scrollView.legalContentOffsetRange
        #expect(scrollView.contentOffset.x >= range.minimumX - 0.5)
        #expect(scrollView.contentOffset.x <= range.maximumX + 0.5)
        #expect(scrollView.contentOffset.y >= range.minimumY - 0.5)
        #expect(scrollView.contentOffset.y <= range.maximumY + 0.5)
    }

    private func expectImageFrameIntersectsViewport(
        _ scrollView: DebugZoomScrollView
    ) {
        let visibleRect = CGRect(
            origin: scrollView.contentOffset,
            size: scrollView.bounds.size
        )
        #expect(scrollView.mediaImageView.frame.width > 0)
        #expect(scrollView.mediaImageView.frame.height > 0)
        #expect(scrollView.mediaImageView.frame.intersects(visibleRect))
    }

    private func expectAspectFitGeometry(
        _ scrollView: DebugZoomScrollView,
        imageSize: CGSize,
        mediaID: String
    ) {
        let frame = scrollView.mediaImageView.frame
        #expect(
            abs(
                frame.width / frame.height
                    - imageSize.width / imageSize.height
            ) <= 0.001
        )
        let range = scrollView.legalContentOffsetRange
        if mediaID == "wide" {
            #expect(abs(range.minimumY - range.maximumY) <= 0.5)
            #expect(range.maximumX > range.minimumX)
        } else if mediaID == "tall" {
            #expect(abs(range.minimumX - range.maximumX) <= 0.5)
            #expect(range.maximumY > range.minimumY)
        }
    }
}
