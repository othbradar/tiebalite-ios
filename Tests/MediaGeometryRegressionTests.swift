import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct MediaGeometryRegressionTests {
    @Test
    func resizePreservesVisibleFocalPointAndAspectFitGeometry() {
        let fixtures = [
            ("square", CGSize(width: 2_048, height: 2_048)),
            ("wide", CGSize(width: 4_096, height: 64)),
            ("tall", CGSize(width: 64, height: 4_096))
        ]
        let sizes = [
            CGSize(width: 844, height: 390),
            CGSize(width: 320, height: 480)
        ]

        for (mediaID, imageSize) in fixtures {
            let image = makeImage(size: imageSize)
            let scrollView = MediaZoomScrollView(
                frame: CGRect(x: 0, y: 0, width: 320, height: 480)
            )
            let view = MediaZoomImageView(
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
            let focalPoint = focalPoint(for: mediaID)
            scrollView.contentOffset = contentOffset(
                centering: focalPoint,
                in: scrollView
            )
            let before = normalizedVisibleCenter(scrollView)
            #expect(abs(before.x - focalPoint.x) <= 0.02)
            #expect(abs(before.y - focalPoint.y) <= 0.02)

            for size in sizes {
                scrollView.frame = CGRect(origin: .zero, size: size)
                scrollView.setNeedsLayout()
                scrollView.layoutIfNeeded()
                expectResizeResult(
                    scrollView,
                    focalPoint: focalPoint,
                    imageSize: imageSize,
                    mediaID: mediaID
                )
            }
            coordinator.dismantle(scrollView)
        }
    }

    @Test
    func sameMediaIDImageRevisionReconfiguresGeometryAndOwnerInput() throws {
        let ownership = MediaGestureOwnershipController<String>()
        let square = makeImage(size: CGSize(width: 2_048, height: 2_048))
        let tall = makeImage(size: CGSize(width: 64, height: 4_096))
        let scrollView = MediaZoomScrollView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        var view = makeZoomView(image: square, ownership: ownership)
        let coordinator = view.makeCoordinator()
        coordinator.install(on: scrollView)
        scrollView.configure(image: square, mediaID: "stable")
        scrollView.layoutIfNeeded()
        scrollView.setZoomScale(2.5, animated: false)
        scrollView.layoutIfNeeded()

        view = makeZoomView(image: tall, ownership: ownership)
        coordinator.parent = view
        coordinator.synchronizeContent(on: scrollView)
        coordinator.synchronizeRegistration(on: scrollView)
        scrollView.layoutIfNeeded()

        #expect(scrollView.mediaID == "stable")
        #expect(scrollView.mediaImageView.image === tall)
        #expect(scrollView.mediaImageView.image !== square)
        #expect(scrollView.zoomScale == scrollView.minimumZoomScale)
        #expect(
            abs(
                scrollView.mediaImageView.frame.width
                    / scrollView.mediaImageView.frame.height
                    - tall.size.width / tall.size.height
            ) <= 0.001
        )
        #expect(scrollView.capability == .minimumZoom)

        scrollView.setZoomScale(2.5, animated: false)
        scrollView.layoutIfNeeded()
        let horizontalRange = scrollView.legalContentOffsetRange
        #expect(
            abs(horizontalRange.minimumX - horizontalRange.maximumX) <= 0.5
        )
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
        let session = try #require(ownership.activeSession)
        #expect(session.beganZoomScale == 2.5)
        #expect(session.initialCapability.horizontalBoundary == .both)
        #expect(session.owner == .pager)
        ownership.uninstall()
        coordinator.dismantle(scrollView)
    }

    @Test
    func invalidAttachedGeometryAndInvalidRootAreObservable() {
        let invalidViewport = makeViewportMetrics(viewportWidth: .nan)
        #expect(
            DebugMediaDiagnostics.shouldCountInvalidViewport(
                invalidViewport,
                monitoringArmed: true,
                isCurrentMedia: true
            )
        )

        let invalidRoot = DebugMediaRootGeometry(
            width: .nan,
            height: 480,
            safeTop: 20,
            safeLeft: 0,
            safeBottom: 20,
            safeRight: 0
        )
        #expect(
            DebugMediaDiagnostics.shouldCountInvalidChrome(
                frame: CGRect(x: 0, y: 20, width: 320, height: 44),
                root: invalidRoot,
                monitoringArmed: true
            )
        )
    }
}

private extension MediaGeometryRegressionTests {
    func focalPoint(for mediaID: String) -> CGPoint {
        switch mediaID {
        case "wide":
            CGPoint(x: 0.32, y: 0.5)
        case "tall":
            CGPoint(x: 0.5, y: 0.68)
        default:
            CGPoint(x: 0.32, y: 0.68)
        }
    }

    func expectResizeResult(
        _ scrollView: MediaZoomScrollView,
        focalPoint: CGPoint,
        imageSize: CGSize,
        mediaID: String
    ) {
        let after = normalizedVisibleCenter(scrollView)
        let expected = normalizedVisibleCenter(
            afterClamping: focalPoint,
            in: scrollView
        )
        #expect(abs(scrollView.zoomScale - 2.5) <= 0.001)
        #expect(abs(expected.x - after.x) <= 0.02)
        #expect(abs(expected.y - after.y) <= 0.02)
        #expect(scrollView.mediaID == mediaID)
        expectLegalContentOffset(scrollView)
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
        } else if mediaID == "tall" {
            #expect(abs(range.minimumX - range.maximumX) <= 0.5)
        }
    }

    func normalizedVisibleCenter(
        _ scrollView: MediaZoomScrollView
    ) -> CGPoint {
        CGPoint(
            x: (scrollView.contentOffset.x + scrollView.bounds.width / 2)
                / max(scrollView.contentSize.width, 1),
            y: (scrollView.contentOffset.y + scrollView.bounds.height / 2)
                / max(scrollView.contentSize.height, 1)
        )
    }

    func contentOffset(
        centering focalPoint: CGPoint,
        in scrollView: MediaZoomScrollView
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

    func normalizedVisibleCenter(
        afterClamping focalPoint: CGPoint,
        in scrollView: MediaZoomScrollView
    ) -> CGPoint {
        let offset = contentOffset(centering: focalPoint, in: scrollView)
        return CGPoint(
            x: (offset.x + scrollView.bounds.width / 2)
                / max(scrollView.contentSize.width, 1),
            y: (offset.y + scrollView.bounds.height / 2)
                / max(scrollView.contentSize.height, 1)
        )
    }

    func expectLegalContentOffset(_ scrollView: MediaZoomScrollView) {
        let range = scrollView.legalContentOffsetRange
        #expect(scrollView.contentOffset.x >= range.minimumX - 0.5)
        #expect(scrollView.contentOffset.x <= range.maximumX + 0.5)
        #expect(scrollView.contentOffset.y >= range.minimumY - 0.5)
        #expect(scrollView.contentOffset.y <= range.maximumY + 0.5)
    }

    func makeZoomView(
        image: UIImage,
        ownership: MediaGestureOwnershipController<String>
    ) -> MediaZoomImageView {
        MediaZoomImageView(
            mediaID: "stable",
            image: image,
            ownershipController: ownership,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
    }

    func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    func makeViewportMetrics(
        viewportWidth: Double
    ) -> MediaViewportMetrics {
        MediaViewportMetrics(
            layoutGeneration: 1,
            zoomScale: 2.5,
            viewportWidth: viewportWidth,
            viewportHeight: 480,
            contentOffsetX: 10,
            contentOffsetY: 10,
            contentSizeWidth: 800,
            contentSizeHeight: 800,
            minimumOffsetX: 0,
            maximumOffsetX: 100,
            minimumOffsetY: 0,
            maximumOffsetY: 100,
            imageFrameWidth: 800,
            imageFrameHeight: 800,
            visibleFocalPointX: 0.5,
            visibleFocalPointY: 0.5,
            retainedFocalPointX: 0.5,
            retainedFocalPointY: 0.5,
            safeAreaTop: 20,
            safeAreaLeft: 0,
            safeAreaBottom: 20,
            safeAreaRight: 0,
            windowWidth: 320,
            windowHeight: 480,
            attachedToWindow: true
        )
    }
}
