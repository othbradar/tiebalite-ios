#if DEBUG
import CoreGraphics
import Foundation

enum DebugMediaCoordinateSpace {
    static let root = "debug.media.viewer.root"
}

struct DebugMediaRootGeometry: Equatable, Sendable {
    static let zero = DebugMediaRootGeometry(
        width: 0,
        height: 0,
        safeTop: 0,
        safeLeft: 0,
        safeBottom: 0,
        safeRight: 0
    )

    let width: Double
    let height: Double
    let safeTop: Double
    let safeLeft: Double
    let safeBottom: Double
    let safeRight: Double

    var hasUsableSafeFrame: Bool {
        let values = [
            width,
            height,
            safeTop,
            safeLeft,
            safeBottom,
            safeRight
        ]
        return values.allSatisfy(\.isFinite)
            && width > 0
            && height > 0
            && safeTop >= 0
            && safeLeft >= 0
            && safeBottom >= 0
            && safeRight >= 0
            && safeLeft + safeRight < width
            && safeTop + safeBottom < height
    }

    var safeFrame: CGRect {
        CGRect(
            x: safeLeft,
            y: safeTop,
            width: max(0, width - safeLeft - safeRight),
            height: max(0, height - safeTop - safeBottom)
        )
    }
}

struct DebugMediaChromeGeometry: Equatable, Sendable {
    let frame: CGRect
    let root: DebugMediaRootGeometry
}

enum DebugMediaDiagnostics {
    static func sessionText(
        _ session: MediaGestureSession<String>?
    ) -> String {
        guard let session else {
            return "session=none"
        }
        return "session=\(session.gestureSessionID) "
            + "generation=\(session.generation) "
            + "media=\(session.mediaID) "
            + "phase=\(phaseText(session.phase)) "
            + "reason=\(reasonText(session.decisionReason)) "
            + String(format: "beginZoom=%.2f", session.beganZoomScale)
    }

    static func inputText(
        _ metrics: MediaInputMetrics,
        totalPanBeginCount: UInt64,
        totalPanEndCount: UInt64
    ) -> String {
        "sequence=\(metrics.eventSequence) "
            + "single=\(metrics.singleTapCount) "
            + "double=\(metrics.doubleTapCount) "
            + "panBegin=\(metrics.panBeginCount) "
            + "panEnd=\(metrics.panEndCount) "
            + "totalPanBegin=\(totalPanBeginCount) "
            + "totalPanEnd=\(totalPanEndCount)"
    }

    static func layoutText(
        _ metrics: MediaViewportMetrics?,
        pagerCoordinatorSequence: UInt64,
        invalidViewportCount: UInt64,
        lastInvalidViewport: String
    ) -> String {
        guard let metrics else {
            return "layout=unavailable"
        }
        return String(
            format: "layout=%llu viewport=%.1fx%.1f offset=%.1f,%.1f "
                + "content=%.1fx%.1f focal=%.4f,%.4f retained=%.4f,%.4f "
                + "frame=%.1fx%.1f "
                + "legalX=%.1f...%.1f legalY=%.1f...%.1f "
                + "window=%.1fx%.1f coordinator=%llu invalidViewport=%llu "
                + "attached=%@ valid=%@",
            metrics.layoutGeneration,
            metrics.viewportWidth,
            metrics.viewportHeight,
            metrics.contentOffsetX,
            metrics.contentOffsetY,
            metrics.contentSizeWidth,
            metrics.contentSizeHeight,
            metrics.visibleFocalPointX,
            metrics.visibleFocalPointY,
            metrics.retainedFocalPointX,
            metrics.retainedFocalPointY,
            metrics.imageFrameWidth,
            metrics.imageFrameHeight,
            metrics.minimumOffsetX,
            metrics.maximumOffsetX,
            metrics.minimumOffsetY,
            metrics.maximumOffsetY,
            metrics.windowWidth,
            metrics.windowHeight,
            pagerCoordinatorSequence,
            invalidViewportCount,
            metrics.attachedToWindow ? "true" : "false",
            metrics.hasFiniteLegalGeometry ? "true" : "false"
        ) + " lastInvalid=\(lastInvalidViewport)"
    }

    static func viewportText(_ metrics: MediaViewportMetrics) -> String {
        String(
            format: "zoom:%.2f,viewport:%.1fx%.1f,offset:%.1f:%.1f,"
                + "legalX:%.1f:%.1f,legalY:%.1f:%.1f,frame:%.1fx%.1f",
            metrics.zoomScale,
            metrics.viewportWidth,
            metrics.viewportHeight,
            metrics.contentOffsetX,
            metrics.contentOffsetY,
            metrics.minimumOffsetX,
            metrics.maximumOffsetX,
            metrics.minimumOffsetY,
            metrics.maximumOffsetY,
            metrics.imageFrameWidth,
            metrics.imageFrameHeight
        )
    }

    static func chromeText(
        visible: Bool,
        frame: CGRect,
        root: DebugMediaRootGeometry,
        chromeLayoutGeneration: UInt64,
        invalidChromeCount: UInt64
    ) -> String {
        String(
            format: "visible=%@ frame=%.1f,%.1f,%.1f,%.1f "
                + "root=%.1fx%.1f safe=%.1f,%.1f,%.1f,%.1f "
                + "chromeLayout=%llu invalidChrome=%llu valid=%@",
            visible ? "true" : "false",
            frame.minX,
            frame.minY,
            frame.width,
            frame.height,
            root.width,
            root.height,
            root.safeTop,
            root.safeLeft,
            root.safeBottom,
            root.safeRight,
            chromeLayoutGeneration,
            invalidChromeCount,
            chromeFrameIsValid(frame, root: root) ? "true" : "false"
        )
    }

    static func chromeFrameIsValid(
        _ frame: CGRect,
        root: DebugMediaRootGeometry
    ) -> Bool {
        let values = [
            frame.minX,
            frame.minY,
            frame.maxX,
            frame.maxY,
            root.width,
            root.height
        ]
        return root.hasUsableSafeFrame
            && values.allSatisfy(\.isFinite)
            && frame.width > 0
            && frame.height > 0
            && root.safeFrame.insetBy(dx: -0.5, dy: -0.5).contains(frame)
    }

    static func shouldCountInvalidViewport(
        _ metrics: MediaViewportMetrics,
        monitoringArmed: Bool,
        isCurrentMedia: Bool
    ) -> Bool {
        monitoringArmed
            && isCurrentMedia
            && !metrics.hasFiniteLegalGeometry
    }

    static func shouldCountInvalidChrome(
        frame: CGRect,
        root: DebugMediaRootGeometry,
        monitoringArmed: Bool
    ) -> Bool {
        monitoringArmed && !chromeFrameIsValid(frame, root: root)
    }

    private static func phaseText(_ phase: MediaGestureSessionPhase) -> String {
        switch phase {
        case .active:
            "active"
        case .ended:
            "ended"
        case .cancelled:
            "cancelled"
        case .failed:
            "failed"
        case .invalidated:
            "invalidated"
        }
    }

    private static func reasonText(
        _ reason: MediaGestureDecisionReason
    ) -> String {
        switch reason {
        case .ambiguousAtMinimumZoom:
            "ambiguous-minimum"
        case .minimumZoomHorizontal:
            "minimum-horizontal"
        case .zoomedBoundaryOutward:
            "boundary-outward"
        case .zoomedMediaPan:
            "zoomed-media-pan"
        }
    }
}
#endif
