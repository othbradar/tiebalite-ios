import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct InteractionControllerLifecycleTests {
    @Test
    func staleDeferredSelectionCommitCannotOverwriteNewerExternalSelection() async {
        var selection: String? = "p1"
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        var pager = PagerContainer(
            pageIDs: ["p0", "p1", "p2"],
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true
        ) { pageID in
            Text(pageID)
        }
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        coordinator.install(on: controller)
        coordinator.synchronize(controller)

        pager = PagerContainer(
            pageIDs: ["p0", "p2"],
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true
        ) { pageID in
            Text(pageID)
        }
        coordinator.parent = pager
        coordinator.synchronize(controller)

        selection = "p0"
        coordinator.parent = PagerContainer(
            pageIDs: ["p0", "p2"],
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true
        ) { pageID in
            Text(pageID)
        }
        coordinator.synchronize(controller)

        await Task.yield()
        await Task.yield()

        #expect(selection == "p0")
        coordinator.dismantle(controller)
    }

    @Test
    func pagerCoordinatorKeepsARealHostingControllerCacheBoundedAcrossOneHundredPages() {
        let pages = (0..<100).map { "p\($0)" }
        var selection: String? = pages[0]
        let binding = Binding<String?>(
            get: { selection },
            set: { selection = $0 }
        )
        var pager = PagerContainer(
            pageIDs: pages,
            selection: binding,
            backgroundColor: .black,
            reduceMotion: true
        ) { pageID in
            Text(pageID)
        }
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        coordinator.install(on: controller)

        for pageID in pages {
            selection = pageID
            pager = PagerContainer(
                pageIDs: pages,
                selection: binding,
                backgroundColor: .black,
                reduceMotion: true
            ) { candidateID in
                Text(candidateID)
            }
            coordinator.parent = pager
            coordinator.synchronize(controller)
            #expect(coordinator.cachedControllerCount <= 3)
        }

        #expect(coordinator.isInstalled)
        coordinator.dismantle(controller)
        #expect(!coordinator.isInstalled)
        #expect(coordinator.cachedControllerCount == 0)
        #expect(controller.delegate == nil)
        #expect(controller.dataSource == nil)
    }

    @Test
    func zoomCoordinatorDismantleClearsDelegateAndOwnedRecognizers() {
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 64, height: 64)
        ).image { context in
            UIColor.systemBlue.setFill()
            context.fill(
                CGRect(x: 0, y: 0, width: 64, height: 64)
            )
        }
        let view = DebugZoomImageView(
            mediaID: "fixture",
            image: image,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
        let coordinator = view.makeCoordinator()
        let scrollView = DebugZoomScrollView()
        let baselineRecognizerCount = scrollView.gestureRecognizers?.count ?? 0

        coordinator.install(on: scrollView)
        scrollView.configure(image: image, mediaID: "fixture")

        #expect(scrollView.delegate === coordinator)
        #expect(
            (scrollView.gestureRecognizers?.count ?? 0)
                == baselineRecognizerCount + 2
        )

        coordinator.dismantle(scrollView)
        #expect(scrollView.delegate == nil)
        #expect(
            (scrollView.gestureRecognizers?.count ?? 0)
                == baselineRecognizerCount
        )
    }

    @Test
    func committedDepartureResetGenerationResetsTheCachedZoomTransform() {
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 128, height: 128)
        ).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(
                CGRect(x: 0, y: 0, width: 128, height: 128)
            )
        }
        let scrollView = DebugZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        let view = DebugZoomImageView(
            mediaID: "fixture",
            image: image,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
        let coordinator = view.makeCoordinator()
        coordinator.install(on: scrollView)
        scrollView.configure(
            image: image,
            mediaID: "fixture",
            resetGeneration: 0
        )
        scrollView.layoutIfNeeded()
        scrollView.setZoomScale(2, animated: false)
        scrollView.contentOffset = CGPoint(x: 40, y: 60)

        #expect(scrollView.zoomScale > scrollView.minimumZoomScale)

        scrollView.applyResetGeneration(1)

        #expect(scrollView.zoomScale == scrollView.minimumZoomScale)
        #expect(scrollView.capability == .minimumZoom)
        coordinator.dismantle(scrollView)
    }

    @Test
    func zoomTransitionAnimationFollowsReduceMotion() {
        let image = makeImage(size: CGSize(width: 32, height: 32))
        let standard = DebugZoomImageView(
            mediaID: "standard",
            image: image,
            reduceMotion: false,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
        let reduced = DebugZoomImageView(
            mediaID: "reduced",
            image: image,
            reduceMotion: true,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )

        #expect(standard.animatesZoomTransition)
        #expect(!reduced.animatesZoomTransition)
    }

    @Test
    func extremeAspectRatiosAndResizeKeepFiniteZoomGeometryAndIdentity() {
        let fixtures: [(String, UIImage)] = [
            ("tiny", makeImage(size: CGSize(width: 1, height: 1))),
            ("wide", makeImage(size: CGSize(width: 4_096, height: 64))),
            ("tall", makeImage(size: CGSize(width: 64, height: 4_096))),
            ("unknown", UIImage())
        ]
        let viewportSizes = [
            CGSize(width: 320, height: 480),
            CGSize(width: 844, height: 390),
            CGSize(width: 507, height: 768),
            CGSize(width: 1_024, height: 768)
        ]

        for (mediaID, image) in fixtures {
            let scrollView = DebugZoomScrollView()
            let view = DebugZoomImageView(
                mediaID: mediaID,
                image: image,
                onSingleTap: {},
                onCapabilityChanged: { _, _ in }
            )
            let coordinator = view.makeCoordinator()
            coordinator.install(on: scrollView)
            scrollView.configure(image: image, mediaID: mediaID)

            for viewportSize in viewportSizes {
                scrollView.frame = CGRect(origin: .zero, size: viewportSize)
                scrollView.setNeedsLayout()
                scrollView.layoutIfNeeded()
                scrollView.setZoomScale(2, animated: false)
                scrollView.layoutIfNeeded()

                #expect(scrollView.mediaID == mediaID)
                expectFiniteGeometry(scrollView)
            }

            coordinator.dismantle(scrollView)
        }
    }

    @Test
    func zoomCoordinatorAndScrollViewReleaseAfterDismantle() {
        weak var weakCoordinator: DebugZoomImageView.Coordinator?
        weak var weakScrollView: DebugZoomScrollView?

        autoreleasepool {
            let image = makeImage(size: CGSize(width: 64, height: 64))
            let view = DebugZoomImageView(
                mediaID: "release",
                image: image,
                onSingleTap: {},
                onCapabilityChanged: { _, _ in }
            )
            let coordinator = view.makeCoordinator()
            let scrollView = DebugZoomScrollView()
            weakCoordinator = coordinator
            weakScrollView = scrollView

            coordinator.install(on: scrollView)
            scrollView.configure(image: image, mediaID: "release")
            coordinator.dismantle(scrollView)
        }

        #expect(weakCoordinator == nil)
        #expect(weakScrollView == nil)
    }

    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func expectFiniteGeometry(_ scrollView: DebugZoomScrollView) {
        let values = [
            scrollView.bounds.width,
            scrollView.bounds.height,
            scrollView.contentSize.width,
            scrollView.contentSize.height,
            scrollView.contentOffset.x,
            scrollView.contentOffset.y,
            scrollView.contentInset.top,
            scrollView.contentInset.left,
            scrollView.contentInset.bottom,
            scrollView.contentInset.right,
            scrollView.mediaImageView.frame.minX,
            scrollView.mediaImageView.frame.minY,
            scrollView.mediaImageView.frame.width,
            scrollView.mediaImageView.frame.height,
            scrollView.zoomScale
        ]
        for value in values {
            #expect(value.isFinite)
        }
        #expect(scrollView.bounds.width > 0)
        #expect(scrollView.bounds.height > 0)
    }
}
