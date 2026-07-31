import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct InteractionControllerLifecycleTests {
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
}
