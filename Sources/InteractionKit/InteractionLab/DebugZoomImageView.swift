#if DEBUG
import SwiftUI
import UIKit

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

@MainActor
struct DebugZoomImageView: UIViewRepresentable {
    let mediaID: String
    let image: UIImage
    let resetGeneration: UInt64
    let reduceMotion: Bool
    let onSingleTap: () -> Void
    let onCapabilityChanged: (MediaPageCapability, Double) -> Void

    init(
        mediaID: String,
        image: UIImage,
        resetGeneration: UInt64 = 0,
        reduceMotion: Bool = false,
        onSingleTap: @escaping () -> Void,
        onCapabilityChanged: @escaping (
            MediaPageCapability,
            Double
        ) -> Void
    ) {
        self.mediaID = mediaID
        self.image = image
        self.resetGeneration = resetGeneration
        self.reduceMotion = reduceMotion
        self.onSingleTap = onSingleTap
        self.onCapabilityChanged = onCapabilityChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> DebugZoomScrollView {
        let scrollView = DebugZoomScrollView()
        context.coordinator.install(on: scrollView)
        scrollView.configure(
            image: image,
            mediaID: mediaID,
            resetGeneration: resetGeneration
        )
        return scrollView
    }

    func updateUIView(
        _ scrollView: DebugZoomScrollView,
        context: Context
    ) {
        context.coordinator.parent = self
        if scrollView.mediaID != mediaID {
            scrollView.configure(
                image: image,
                mediaID: mediaID,
                resetGeneration: resetGeneration
            )
        } else {
            scrollView.applyResetGeneration(resetGeneration)
        }
        context.coordinator.reportCapability(scrollView)
    }

    static func dismantleUIView(
        _ scrollView: DebugZoomScrollView,
        coordinator: Coordinator
    ) {
        coordinator.dismantle(scrollView)
    }

    @MainActor
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: DebugZoomImageView

        private weak var scrollView: DebugZoomScrollView?
        private var singleTapRecognizer: UITapGestureRecognizer?
        private var doubleTapRecognizer: UITapGestureRecognizer?

        init(parent: DebugZoomImageView) {
            self.parent = parent
        }

        func install(on scrollView: DebugZoomScrollView) {
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

            scrollView.addGestureRecognizer(singleTap)
            scrollView.addGestureRecognizer(doubleTap)
            singleTapRecognizer = singleTap
            doubleTapRecognizer = doubleTap
        }

        func dismantle(_ scrollView: DebugZoomScrollView) {
            if let singleTapRecognizer {
                scrollView.removeGestureRecognizer(singleTapRecognizer)
            }
            if let doubleTapRecognizer {
                scrollView.removeGestureRecognizer(doubleTapRecognizer)
            }
            scrollView.delegate = nil
            singleTapRecognizer = nil
            doubleTapRecognizer = nil
            self.scrollView = nil
        }

        func viewForZooming(
            in scrollView: UIScrollView
        ) -> UIView? {
            (scrollView as? DebugZoomScrollView)?.mediaImageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? DebugZoomScrollView else {
                return
            }
            scrollView.centerZoomedImage()
            reportCapability(scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? DebugZoomScrollView else {
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
                    as? DebugZoomScrollView else {
                return
            }
            reportCapability(scrollView)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let scrollView = scrollView as? DebugZoomScrollView else {
                return
            }
            reportCapability(scrollView)
        }

        func reportCapability(_ scrollView: DebugZoomScrollView) {
            let capability = scrollView.capability
            scrollView.panGestureRecognizer.isEnabled =
                !capability.atMinimumZoom
            parent.onCapabilityChanged(
                capability,
                Double(scrollView.zoomScale)
            )
        }

        @objc
        private func singleTapped() {
            parent.onSingleTap()
        }

        @objc
        private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else {
                return
            }
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
    }

    var animatesZoomTransition: Bool {
        !reduceMotion
    }
}

@MainActor
final class DebugZoomScrollView: UIScrollView {
    let mediaImageView = UIImageView()
    private(set) var mediaID: String?
    private(set) var appliedResetGeneration: UInt64 = 0

    private var previousBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        minimumZoomScale = 1
        maximumZoomScale = 4
        bouncesZoom = true
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        isDirectionalLockEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delaysContentTouches = false

        mediaImageView.backgroundColor = .black
        mediaImageView.contentMode = .scaleAspectFit
        mediaImageView.isAccessibilityElement = false
        addSubview(mediaImageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size.width > 0,
              bounds.size.height > 0,
              bounds.size != previousBoundsSize else {
            centerZoomedImage()
            return
        }

        let retainedScale = max(
            minimumZoomScale,
            min(zoomScale, maximumZoomScale)
        )
        setZoomScale(minimumZoomScale, animated: false)
        mediaImageView.frame = CGRect(origin: .zero, size: bounds.size)
        contentSize = bounds.size
        previousBoundsSize = bounds.size
        setZoomScale(retainedScale, animated: false)
        centerZoomedImage()
    }

    func configure(
        image: UIImage,
        mediaID: String,
        resetGeneration: UInt64 = 0
    ) {
        self.mediaID = mediaID
        appliedResetGeneration = resetGeneration
        mediaImageView.image = image
        accessibilityIdentifier = "interaction.media.zoom-surface.\(mediaID)"
        setZoomScale(minimumZoomScale, animated: false)
        contentOffset = .zero
        setNeedsLayout()
    }

    func applyResetGeneration(_ resetGeneration: UInt64) {
        guard resetGeneration != appliedResetGeneration else {
            return
        }
        appliedResetGeneration = resetGeneration
        setZoomScale(minimumZoomScale, animated: false)
        contentOffset = .zero
        centerZoomedImage()
    }

    func centerZoomedImage() {
        let horizontalInset = max(
            0,
            (bounds.width - mediaImageView.frame.width) / 2
        )
        let verticalInset = max(
            0,
            (bounds.height - mediaImageView.frame.height) / 2
        )
        contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    var capability: MediaPageCapability {
        let atMinimum = zoomScale <= minimumZoomScale + 0.01
        guard !atMinimum else {
            return .minimumZoom
        }

        let minimumX = -adjustedContentInset.left
        let maximumX = max(
            minimumX,
            contentSize.width - bounds.width + adjustedContentInset.right
        )
        let atLeading = contentOffset.x <= minimumX + 1
        let atTrailing = contentOffset.x >= maximumX - 1
        let boundary: MediaHorizontalBoundary
        switch (atLeading, atTrailing) {
        case (true, true):
            boundary = .both
        case (true, false):
            boundary = .leading
        case (false, true):
            boundary = .trailing
        case (false, false):
            boundary = .interior
        }
        return MediaPageCapability(
            atMinimumZoom: false,
            horizontalBoundary: boundary
        )
    }
}

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
