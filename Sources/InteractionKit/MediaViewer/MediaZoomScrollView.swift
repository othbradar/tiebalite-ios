import UIKit

struct MediaContentOffsetRange: Equatable, Sendable {
    let minimumX: CGFloat
    let maximumX: CGFloat
    let minimumY: CGFloat
    let maximumY: CGFloat
}

@MainActor
final class MediaZoomScrollView: UIScrollView {
    let mediaImageView = UIImageView()
    private(set) var mediaID: String?
    private(set) var appliedResetGeneration: UInt64 = 0
    var onLayoutMetricsChanged: ((MediaViewportMetrics) -> Void)?

    private var previousBoundsSize: CGSize = .zero
    private var retainedFocalPoint = CGPoint(x: 0.5, y: 0.5)
    private var layoutGeneration: UInt64 = 0
    private var isUpdatingResizeLayout = false
    private var requiresBaseGeometryUpdate = true

    var isPerformingGeometryUpdate: Bool {
        isUpdatingResizeLayout
    }

    var hasUsableBaseGeometry: Bool {
        !requiresBaseGeometryUpdate
            && bounds.width > 0
            && bounds.height > 0
            && mediaImageView.frame.width > 0
            && mediaImageView.frame.height > 0
    }

    override var contentOffset: CGPoint {
        didSet {
            guard !isUpdatingResizeLayout,
                  previousBoundsSize == bounds.size,
                  previousBoundsSize.width > 0,
                  previousBoundsSize.height > 0 else {
                return
            }
            retainedFocalPoint = normalizedVisibleCenter(
                viewportSize: previousBoundsSize
            )
        }
    }

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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil,
              hasUsableBaseGeometry,
              !isUpdatingResizeLayout else {
            return
        }
        onLayoutMetricsChanged?(viewportMetrics)
    }

    override func layoutSubviews() {
        guard !isUpdatingResizeLayout else {
            super.layoutSubviews()
            return
        }
        let hasValidBounds = bounds.size.width > 0
            && bounds.size.height > 0
        let geometryChanged = hasValidBounds
            && (bounds.size != previousBoundsSize
                || requiresBaseGeometryUpdate)
        let focalPoint = retainedFocalPoint
        let retainedScale = max(
            minimumZoomScale,
            min(zoomScale, maximumZoomScale)
        )
        super.layoutSubviews()
        guard hasValidBounds else {
            onLayoutMetricsChanged?(viewportMetrics)
            return
        }
        guard geometryChanged else {
            centerZoomedImage()
            clampContentOffset()
            onLayoutMetricsChanged?(viewportMetrics)
            return
        }

        isUpdatingResizeLayout = true
        setZoomScale(minimumZoomScale, animated: false)
        let fittedSize = aspectFitSize(in: bounds.size)
        mediaImageView.frame = CGRect(origin: .zero, size: fittedSize)
        contentSize = fittedSize
        previousBoundsSize = bounds.size
        requiresBaseGeometryUpdate = false
        setZoomScale(retainedScale, animated: false)
        super.layoutSubviews()
        centerZoomedImage()
        restoreVisibleCenter(focalPoint)
        clampContentOffset()
        retainedFocalPoint = focalPoint
        layoutGeneration &+= 1
        isUpdatingResizeLayout = false
        onLayoutMetricsChanged?(viewportMetrics)
    }

    func configure(
        image: UIImage,
        mediaID: String,
        resetGeneration: UInt64 = 0,
        surfaceAccessibilityIdentifier: String? = nil,
        surfaceAccessibilityLabel: String? = nil,
        surfaceAccessibilityValue: String? = nil,
        surfaceAccessibilityHint: String? = nil
    ) {
        isUpdatingResizeLayout = true
        self.mediaID = mediaID
        appliedResetGeneration = resetGeneration
        mediaImageView.image = image
        requiresBaseGeometryUpdate = true
        configureAccessibility(
            identifier: surfaceAccessibilityIdentifier
                ?? "interaction.media.zoom-surface.\(mediaID)",
            label: surfaceAccessibilityLabel,
            value: surfaceAccessibilityValue,
            hint: surfaceAccessibilityHint
        )
        setZoomScale(minimumZoomScale, animated: false)
        contentOffset = .zero
        retainedFocalPoint = CGPoint(x: 0.5, y: 0.5)
        isUpdatingResizeLayout = false
        setNeedsLayout()
    }

    func configureAccessibility(
        identifier: String?,
        label: String?,
        value: String?,
        hint: String?
    ) {
        accessibilityIdentifier = identifier
        accessibilityLabel = label
        accessibilityValue = value
        accessibilityHint = hint
        isAccessibilityElement = label != nil
    }

    func applyResetGeneration(_ resetGeneration: UInt64) {
        guard resetGeneration != appliedResetGeneration else {
            return
        }
        isUpdatingResizeLayout = true
        appliedResetGeneration = resetGeneration
        setZoomScale(minimumZoomScale, animated: false)
        contentOffset = .zero
        retainedFocalPoint = CGPoint(x: 0.5, y: 0.5)
        centerZoomedImage()
        clampContentOffset()
        isUpdatingResizeLayout = false
        setNeedsLayout()
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

    var viewportMetrics: MediaViewportMetrics {
        let range = legalContentOffsetRange
        let visibleFocalPoint = normalizedVisibleCenter(
            viewportSize: bounds.size
        )
        return MediaViewportMetrics(
            layoutGeneration: layoutGeneration,
            zoomScale: Double(zoomScale),
            viewportWidth: Double(bounds.width),
            viewportHeight: Double(bounds.height),
            contentOffsetX: Double(contentOffset.x),
            contentOffsetY: Double(contentOffset.y),
            contentSizeWidth: Double(contentSize.width),
            contentSizeHeight: Double(contentSize.height),
            minimumOffsetX: Double(range.minimumX),
            maximumOffsetX: Double(range.maximumX),
            minimumOffsetY: Double(range.minimumY),
            maximumOffsetY: Double(range.maximumY),
            imageFrameWidth: Double(mediaImageView.frame.width),
            imageFrameHeight: Double(mediaImageView.frame.height),
            visibleFocalPointX: Double(visibleFocalPoint.x),
            visibleFocalPointY: Double(visibleFocalPoint.y),
            retainedFocalPointX: Double(retainedFocalPoint.x),
            retainedFocalPointY: Double(retainedFocalPoint.y),
            safeAreaTop: Double(safeAreaInsets.top),
            safeAreaLeft: Double(safeAreaInsets.left),
            safeAreaBottom: Double(safeAreaInsets.bottom),
            safeAreaRight: Double(safeAreaInsets.right),
            windowWidth: Double(window?.bounds.width ?? 0),
            windowHeight: Double(window?.bounds.height ?? 0),
            attachedToWindow: window != nil
        )
    }

    var legalContentOffsetRange: MediaContentOffsetRange {
        let minimumX = -adjustedContentInset.left
        let maximumX = max(
            minimumX,
            contentSize.width - bounds.width + adjustedContentInset.right
        )
        let minimumY = -adjustedContentInset.top
        let maximumY = max(
            minimumY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        return MediaContentOffsetRange(
            minimumX: minimumX,
            maximumX: maximumX,
            minimumY: minimumY,
            maximumY: maximumY
        )
    }

    private func normalizedVisibleCenter(viewportSize: CGSize) -> CGPoint {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              contentSize.width > 0,
              contentSize.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(
            x: min(
                1,
                max(
                    0,
                    (contentOffset.x + viewportSize.width / 2)
                        / contentSize.width
                )
            ),
            y: min(
                1,
                max(
                    0,
                    (contentOffset.y + viewportSize.height / 2)
                        / contentSize.height
                )
            )
        )
    }

    private func aspectFitSize(in viewportSize: CGSize) -> CGSize {
        guard let imageSize = mediaImageView.image?.size,
              imageSize.width.isFinite,
              imageSize.height.isFinite,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return viewportSize
        }
        let scale = min(
            viewportSize.width / imageSize.width,
            viewportSize.height / imageSize.height
        )
        guard scale.isFinite, scale > 0 else {
            return viewportSize
        }
        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    private func restoreVisibleCenter(_ focalPoint: CGPoint) {
        contentOffset = CGPoint(
            x: focalPoint.x * contentSize.width - bounds.width / 2,
            y: focalPoint.y * contentSize.height - bounds.height / 2
        )
    }

    private func clampContentOffset() {
        let range = legalContentOffsetRange
        let clamped = CGPoint(
            x: min(range.maximumX, max(range.minimumX, contentOffset.x)),
            y: min(range.maximumY, max(range.minimumY, contentOffset.y))
        )
        if contentOffset != clamped {
            contentOffset = clamped
        }
    }

    var capability: MediaPageCapability {
        let atMinimum = zoomScale <= minimumZoomScale + 0.01
        guard !atMinimum else {
            return .minimumZoom
        }

        let range = legalContentOffsetRange
        let atLeading = contentOffset.x <= range.minimumX + 1
        let atTrailing = contentOffset.x >= range.maximumX - 1
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
