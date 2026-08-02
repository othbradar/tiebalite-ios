import SwiftUI
import UIKit

struct MediaInputMetrics: Equatable, Sendable {
    var eventSequence: UInt64 = 0
    var singleTapCount: UInt64 = 0
    var doubleTapCount: UInt64 = 0
    var panBeginCount: UInt64 = 0
    var panEndCount: UInt64 = 0
}

struct MediaViewportMetrics: Equatable, Sendable {
    let layoutGeneration: UInt64
    let zoomScale: Double
    let viewportWidth: Double
    let viewportHeight: Double
    let contentOffsetX: Double
    let contentOffsetY: Double
    let contentSizeWidth: Double
    let contentSizeHeight: Double
    let minimumOffsetX: Double
    let maximumOffsetX: Double
    let minimumOffsetY: Double
    let maximumOffsetY: Double
    let imageFrameWidth: Double
    let imageFrameHeight: Double
    let visibleFocalPointX: Double
    let visibleFocalPointY: Double
    let retainedFocalPointX: Double
    let retainedFocalPointY: Double
    let safeAreaTop: Double
    let safeAreaLeft: Double
    let safeAreaBottom: Double
    let safeAreaRight: Double
    let windowWidth: Double
    let windowHeight: Double
    let attachedToWindow: Bool

    var hasFiniteLegalGeometry: Bool {
        let values = [
            zoomScale,
            viewportWidth,
            viewportHeight,
            contentOffsetX,
            contentOffsetY,
            contentSizeWidth,
            contentSizeHeight,
            minimumOffsetX,
            maximumOffsetX,
            minimumOffsetY,
            maximumOffsetY,
            imageFrameWidth,
            imageFrameHeight,
            visibleFocalPointX,
            visibleFocalPointY,
            retainedFocalPointX,
            retainedFocalPointY,
            safeAreaTop,
            safeAreaLeft,
            safeAreaBottom,
            safeAreaRight,
            windowWidth,
            windowHeight
        ]
        return values.allSatisfy(\.isFinite)
            && attachedToWindow
            && viewportWidth > 0
            && viewportHeight > 0
            && imageFrameWidth > 0
            && imageFrameHeight > 0
            && contentSizeWidth > 0
            && contentSizeHeight > 0
            && windowWidth > 0
            && windowHeight > 0
            && minimumOffsetX <= maximumOffsetX
            && minimumOffsetY <= maximumOffsetY
            && safeAreaTop >= 0
            && safeAreaLeft >= 0
            && safeAreaBottom >= 0
            && safeAreaRight >= 0
            && contentOffsetX >= minimumOffsetX - 0.5
            && contentOffsetX <= maximumOffsetX + 0.5
            && contentOffsetY >= minimumOffsetY - 0.5
            && contentOffsetY <= maximumOffsetY + 0.5
    }
}

#if DEBUG
enum DebugMediaFixtureKind: String, CaseIterable, Sendable {
    case delayed
    case failure
    case large
    case small
}

struct DebugMediaFixture: Identifiable, Equatable, Sendable {
    let id: String
    let kind: DebugMediaFixtureKind

    static let all: [DebugMediaFixture] = [
        DebugMediaFixture(id: "small", kind: .small),
        DebugMediaFixture(id: "large", kind: .large),
        DebugMediaFixture(id: "delayed", kind: .delayed),
        DebugMediaFixture(id: "failure", kind: .failure)
    ]

    @MainActor
    var image: UIImage? {
        switch kind {
        case .small:
            DebugGeneratedMedia.small
        case .large:
            DebugGeneratedMedia.large
        case .delayed:
            DebugGeneratedMedia.delayed
        case .failure:
            nil
        }
    }
}
#endif

@MainActor
struct MediaZoomImageView: UIViewRepresentable {
    let mediaID: String
    let image: UIImage
    let resetGeneration: UInt64
    let reduceMotion: Bool
    let ownershipController: MediaGestureOwnershipController<String>?
    let surfaceAccessibilityIdentifier: String?
    let surfaceAccessibilityLabel: String?
    let surfaceAccessibilityValue: String?
    let surfaceAccessibilityHint: String?
    let onSingleTap: () -> Void
    let onCapabilityChanged: (MediaPageCapability, Double) -> Void
    let onInputMetricsChanged: (MediaInputMetrics) -> Void
    let onViewportMetricsChanged: (MediaViewportMetrics) -> Void

    init(
        mediaID: String,
        image: UIImage,
        resetGeneration: UInt64 = 0,
        reduceMotion: Bool = false,
        ownershipController: MediaGestureOwnershipController<String>? = nil,
        surfaceAccessibilityIdentifier: String? = nil,
        surfaceAccessibilityLabel: String? = nil,
        surfaceAccessibilityValue: String? = nil,
        surfaceAccessibilityHint: String? = nil,
        onSingleTap: @escaping () -> Void,
        onCapabilityChanged: @escaping (
            MediaPageCapability,
            Double
        ) -> Void,
        onInputMetricsChanged: @escaping (
            MediaInputMetrics
        ) -> Void = { _ in },
        onViewportMetricsChanged: @escaping (
            MediaViewportMetrics
        ) -> Void = { _ in }
    ) {
        self.mediaID = mediaID
        self.image = image
        self.resetGeneration = resetGeneration
        self.reduceMotion = reduceMotion
        self.ownershipController = ownershipController
        self.surfaceAccessibilityIdentifier =
            surfaceAccessibilityIdentifier
        self.surfaceAccessibilityLabel = surfaceAccessibilityLabel
        self.surfaceAccessibilityValue = surfaceAccessibilityValue
        self.surfaceAccessibilityHint = surfaceAccessibilityHint
        self.onSingleTap = onSingleTap
        self.onCapabilityChanged = onCapabilityChanged
        self.onInputMetricsChanged = onInputMetricsChanged
        self.onViewportMetricsChanged = onViewportMetricsChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MediaZoomScrollView {
        let scrollView = MediaZoomScrollView()
        context.coordinator.install(on: scrollView)
        scrollView.configure(
            image: image,
            mediaID: mediaID,
            resetGeneration: resetGeneration,
            surfaceAccessibilityIdentifier: surfaceAccessibilityIdentifier,
            surfaceAccessibilityLabel: surfaceAccessibilityLabel,
            surfaceAccessibilityValue: surfaceAccessibilityValue,
            surfaceAccessibilityHint: surfaceAccessibilityHint
        )
        return scrollView
    }

    func updateUIView(
        _ scrollView: MediaZoomScrollView,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.synchronizeContent(on: scrollView)
        context.coordinator.synchronizeRegistration(on: scrollView)
    }

    static func dismantleUIView(
        _ scrollView: MediaZoomScrollView,
        coordinator: Coordinator
    ) {
        coordinator.dismantle(scrollView)
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: MediaZoomImageView

        private weak var scrollView: MediaZoomScrollView?
        private var singleTapRecognizer: UITapGestureRecognizer?
        private var doubleTapRecognizer: UITapGestureRecognizer?
        private var registeredMediaID: String?
        private weak var registeredOwnershipController:
            MediaGestureOwnershipController<String>?
        private var inputMetrics = MediaInputMetrics()

        init(parent: MediaZoomImageView) {
            self.parent = parent
        }

        func install(on scrollView: MediaZoomScrollView) {
            self.scrollView = scrollView
            scrollView.delegate = self

            let singleTap = UITapGestureRecognizer(
                target: self,
                action: #selector(singleTapped)
            )
            singleTap.numberOfTapsRequired = 1

            let doubleTap = UITapGestureRecognizer(
                target: self,
                action: #selector(doubleTapped(_:))
            )
            doubleTap.numberOfTapsRequired = 2
            singleTap.require(toFail: doubleTap)
            singleTap.require(toFail: scrollView.panGestureRecognizer)

            scrollView.addGestureRecognizer(singleTap)
            scrollView.addGestureRecognizer(doubleTap)
            scrollView.panGestureRecognizer.addTarget(
                self,
                action: #selector(panChanged(_:))
            )
            scrollView.onLayoutMetricsChanged = { [weak self, weak scrollView] metrics in
                guard let self else {
                    return
                }
                parent.onViewportMetricsChanged(metrics)
                if let scrollView {
                    parent.onCapabilityChanged(
                        scrollView.capability,
                        Double(scrollView.zoomScale)
                    )
                }
            }
            singleTapRecognizer = singleTap
            doubleTapRecognizer = doubleTap
            synchronizeRegistration(on: scrollView)
        }

        func synchronizeRegistration(on scrollView: MediaZoomScrollView) {
            let ownershipController = parent.ownershipController
            let registrationChanged = registeredMediaID != parent.mediaID
                || registeredOwnershipController !== ownershipController
            if registrationChanged {
                if let registeredMediaID,
                   let registeredOwnershipController {
                    registeredOwnershipController.unregister(
                        mediaID: registeredMediaID,
                        scrollView: scrollView
                    )
                }
                self.registeredMediaID = nil
                registeredOwnershipController = nil
            }
            guard registeredMediaID == nil,
                  let ownershipController else {
                return
            }
            ownershipController.register(
                mediaID: parent.mediaID,
                scrollView: scrollView
            )
            registeredMediaID = parent.mediaID
            registeredOwnershipController = ownershipController
        }

        func synchronizeContent(on scrollView: MediaZoomScrollView) {
            let imageChanged = scrollView.mediaImageView.image
                !== parent.image
            if scrollView.mediaID != parent.mediaID || imageChanged {
                scrollView.configure(
                    image: parent.image,
                    mediaID: parent.mediaID,
                    resetGeneration: parent.resetGeneration,
                    surfaceAccessibilityIdentifier:
                        parent.surfaceAccessibilityIdentifier,
                    surfaceAccessibilityLabel:
                        parent.surfaceAccessibilityLabel,
                    surfaceAccessibilityValue:
                        parent.surfaceAccessibilityValue,
                    surfaceAccessibilityHint:
                        parent.surfaceAccessibilityHint
                )
            } else {
                scrollView.applyResetGeneration(parent.resetGeneration)
                scrollView.configureAccessibility(
                    identifier: parent.surfaceAccessibilityIdentifier
                        ?? "interaction.media.zoom-surface.\(parent.mediaID)",
                    label: parent.surfaceAccessibilityLabel,
                    value: parent.surfaceAccessibilityValue,
                    hint: parent.surfaceAccessibilityHint
                )
            }
        }

        func dismantle(_ scrollView: MediaZoomScrollView) {
            if let registeredMediaID,
               let registeredOwnershipController {
                registeredOwnershipController.unregister(
                    mediaID: registeredMediaID,
                    scrollView: scrollView
                )
            }
            if let singleTapRecognizer {
                scrollView.removeGestureRecognizer(singleTapRecognizer)
            }
            if let doubleTapRecognizer {
                scrollView.removeGestureRecognizer(doubleTapRecognizer)
            }
            scrollView.panGestureRecognizer.removeTarget(
                self,
                action: #selector(panChanged(_:))
            )
            scrollView.onLayoutMetricsChanged = nil
            scrollView.delegate = nil
            singleTapRecognizer = nil
            doubleTapRecognizer = nil
            registeredMediaID = nil
            registeredOwnershipController = nil
            self.scrollView = nil
        }

        func viewForZooming(
            in scrollView: UIScrollView
        ) -> UIView? {
            (scrollView as? MediaZoomScrollView)?.mediaImageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? MediaZoomScrollView else {
                return
            }
            scrollView.centerZoomedImage()
            reportCapability(scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? MediaZoomScrollView else {
                return
            }
            reportCapability(scrollView)
        }

        func scrollViewDidEndDragging(
            _ scrollView: UIScrollView,
            willDecelerate decelerate: Bool
        ) {
            guard !decelerate,
                  let scrollView = scrollView
                    as? MediaZoomScrollView else {
                return
            }
            reportCapability(scrollView)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? MediaZoomScrollView else {
                return
            }
            reportCapability(scrollView)
        }

        func reportCapability(_ scrollView: MediaZoomScrollView) {
            guard !scrollView.isPerformingGeometryUpdate,
                  scrollView.hasUsableBaseGeometry else {
                return
            }
            let capability = scrollView.capability
            parent.onCapabilityChanged(
                capability,
                Double(scrollView.zoomScale)
            )
            parent.onViewportMetricsChanged(scrollView.viewportMetrics)
        }

        @objc
        private func singleTapped() {
            inputMetrics.eventSequence &+= 1
            inputMetrics.singleTapCount &+= 1
            parent.onInputMetricsChanged(inputMetrics)
            parent.onSingleTap()
        }

        @objc
        private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else {
                return
            }
            inputMetrics.eventSequence &+= 1
            inputMetrics.doubleTapCount &+= 1
            parent.onInputMetricsChanged(inputMetrics)
            if scrollView.zoomScale >
                scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(
                    scrollView.minimumZoomScale,
                    animated: parent.animatesZoomTransition
                )
            } else {
                let targetScale = min(
                    scrollView.maximumZoomScale,
                    scrollView.minimumZoomScale * 2.5
                )
                let point = recognizer.location(
                    in: scrollView.mediaImageView
                )
                let width = scrollView.bounds.width / targetScale
                let height = scrollView.bounds.height / targetScale
                let zoomRect = CGRect(
                    x: point.x - width / 2,
                    y: point.y - height / 2,
                    width: width,
                    height: height
                )
                scrollView.zoom(
                    to: zoomRect,
                    animated: parent.animatesZoomTransition
                )
            }
        }

        @objc
        private func panChanged(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                inputMetrics.eventSequence &+= 1
                inputMetrics.panBeginCount &+= 1
                parent.onInputMetricsChanged(inputMetrics)
            case .ended, .cancelled, .failed:
                inputMetrics.eventSequence &+= 1
                inputMetrics.panEndCount &+= 1
                parent.onInputMetricsChanged(inputMetrics)
            case .possible, .changed:
                break
            @unknown default:
                break
            }
        }
    }

    var animatesZoomTransition: Bool {
        !reduceMotion
    }
}

#if DEBUG
@MainActor
private enum DebugGeneratedMedia {
    static let small = render(
        size: CGSize(width: 320, height: 240),
        colors: [.systemTeal, .systemBlue],
        label: "SMALL 320×240"
    )
    static let large = render(
        size: CGSize(width: 2048, height: 2048),
        colors: [.systemIndigo, .systemPurple],
        label: "LARGE 2048×2048"
    )
    static let delayed = render(
        size: CGSize(width: 1280, height: 720),
        colors: [.systemOrange, .systemRed],
        label: "DELAYED LOCAL FIXTURE"
    )

    private static func render(
        size: CGSize,
        colors: [UIColor],
        label: String
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            colors[0].setFill()
            context.fill(bounds)

            colors[1].setStroke()
            context.cgContext.setLineWidth(max(4, size.width / 128))
            let step = max(40, size.width / 8)
            stride(from: CGFloat.zero, through: size.width, by: step)
                .forEach { value in
                    context.cgContext.move(to: CGPoint(x: value, y: 0))
                    context.cgContext.addLine(
                        to: CGPoint(x: size.width - value, y: size.height)
                    )
                }
            context.cgContext.strokePath()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(
                    ofSize: max(24, size.width / 20)
                ),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let textRect = CGRect(
                x: 0,
                y: size.height / 2 - size.height / 12,
                width: size.width,
                height: size.height / 6
            )
            NSString(string: label).draw(
                in: textRect,
                withAttributes: attributes
            )
        }
    }
}
#endif
