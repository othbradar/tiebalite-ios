#if DEBUG
import SwiftUI
import UIKit

@MainActor
struct DebugMediaViewer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.motionReductionOverride) private var reductionOverride

    let presentation: DebugMediaPresentation
    let close: () -> Void

    @State private var currentID: String?
    @State private var externalSelectionGeneration: UInt64 = 0
    @State private var chromeVisible = true
    @State private var delayedReleased = false
    @State private var failureRecovered = false
    @State private var capabilityByID: [
        String: MediaPageCapability
    ] = [:]
    @State private var zoomScaleByID: [String: Double] = [:]
    @State private var resetGenerationByID: [String: UInt64] = [:]
    @State private var transitionSourceID: String?
    @State private var ownershipController =
        MediaGestureOwnershipController<String>()
    @State private var gestureSession: MediaGestureSession<String>?
    @State private var inputMetricsByID: [
        String: DebugMediaInputMetrics
    ] = [:]
    @State private var viewportMetricsByID: [
        String: DebugMediaViewportMetrics
    ] = [:]
    @State private var viewportMonitoringArmedIDs: Set<String> = []
    @State private var rootGeometry = DebugMediaRootGeometry.zero
    @State private var chromeFrame: CGRect = .zero
    @State private var chromeRootGeometry = DebugMediaRootGeometry.zero
    @State private var chromeMonitoringArmed = false
    @State private var invalidViewportCount: UInt64 = 0
    @State private var lastInvalidViewport = "none"
    @State private var invalidChromeCount: UInt64 = 0
    @State private var chromeLayoutGeneration: UInt64 = 0
    @State private var isClosing = false

    init(
        presentation: DebugMediaPresentation,
        close: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.close = close
        _currentID = State(initialValue: presentation.initialID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PagerContainer(
                pageIDs: presentation.items.map(\.id),
                selection: $currentID,
                backgroundColor: .black,
                reduceMotion: reduceMotion || reductionOverride,
                pagingEnabled: pagingEnabled,
                mediaGestureOwnership: ownershipController,
                externalSelectionGeneration: $externalSelectionGeneration,
                onEvent: handlePagerEvent
            ) { mediaID in
                mediaPage(for: mediaID)
            }
            .accessibilityLabel("Media Pager")
            .accessibilityValue(positionText)
            .accessibilityAdjustableAction { direction in
                moveMediaAccessibility(direction)
            }

            statusOverlay

            if chromeVisible {
                chrome
            }
        }
        .coordinateSpace(name: DebugMediaCoordinateSpace.root)
        .onGeometryChange(for: DebugMediaRootGeometry.self) { proxy in
            DebugMediaRootGeometry(
                width: Double(proxy.size.width),
                height: Double(proxy.size.height),
                safeTop: Double(proxy.safeAreaInsets.top),
                safeLeft: Double(proxy.safeAreaInsets.leading),
                safeBottom: Double(proxy.safeAreaInsets.bottom),
                safeRight: Double(proxy.safeAreaInsets.trailing)
            )
        } action: { geometry in
            guard !isClosing else {
                return
            }
            rootGeometry = geometry
        }
        .onAppear {
            ownershipController.onSessionChanged = { session in
                gestureSession = session
            }
            ownershipController.mediaDidChange(to: currentID)
        }
        .onChange(of: currentID) { _, newID in
            guard !isClosing else {
                return
            }
            ownershipController.mediaDidChange(to: newID)
        }
        .accessibilityAction(.escape, closeViewer)
    }
}

private extension DebugMediaViewer {
    private var statusOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: Spacing.small) {
                Text("Media Viewer")
                    .accessibilityIdentifier("interaction.media.viewer")
                    .accessibilityValue(layoutMetricsText)
                Text("Current: \(currentID ?? "none")")
                    .accessibilityIdentifier("interaction.media.current-id")
                Text("Position: \(positionText)")
                    .accessibilityIdentifier("interaction.media.position")
                Text("Zoom: \(zoomScaleText)")
                    .accessibilityIdentifier("interaction.media.zoom-state")
                    .accessibilityValue(inputMetricsText)
                Text("Boundary: \(boundaryText)")
                    .accessibilityIdentifier(
                        "interaction.media.horizontal-boundary"
                    )
                Text("Owner: \(ownerText)")
                    .accessibilityIdentifier(
                        "interaction.media.gesture-owner"
                    )
                    .accessibilityValue(sessionMetricsText)
            }
            .font(Typography.font(.caption))
            .foregroundStyle(Color.white)
            .padding(Spacing.small)
            .background(Color.black.opacity(0.78))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(false)
    }

    private var chrome: some View {
        GeometryReader { proxy in
            let chromeRoot = DebugMediaRootGeometry(
                width: Double(proxy.size.width),
                height: Double(proxy.size.height),
                safeTop: Double(proxy.safeAreaInsets.top),
                safeLeft: Double(proxy.safeAreaInsets.leading),
                safeBottom: Double(proxy.safeAreaInsets.bottom),
                safeRight: Double(proxy.safeAreaInsets.trailing)
            )
            VStack {
                HStack(spacing: Spacing.small) {
                    Text("Chrome")

                    Button("关闭", action: closeViewer)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("interaction.media.close")

                    Button("上一张") {
                        moveMedia(by: -1)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canMoveMedia(by: -1))
                    .accessibilityIdentifier(
                        "interaction.media.accessibility.previous"
                    )

                    Button("下一张") {
                        moveMedia(by: 1)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canMoveMedia(by: 1))
                    .accessibilityIdentifier(
                        "interaction.media.accessibility.next"
                    )

                    if currentID == "delayed", !delayedReleased {
                        Button("释放延迟图") {
                            delayedReleased = true
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "interaction.media.release-delayed"
                        )
                    }

                    Spacer()
                }
                .padding(Spacing.medium)
                .background(Color.black.opacity(0.78))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("interaction.media.chrome")
                .accessibilityValue(chromeMetricsText)
                .onGeometryChange(
                    for: DebugMediaChromeGeometry.self
                ) { chromeProxy in
                    DebugMediaChromeGeometry(
                        frame: chromeProxy.frame(
                            in: .named(DebugMediaCoordinateSpace.root)
                        ),
                        root: chromeRoot
                    )
                } action: { geometry in
                    guard !isClosing else {
                        return
                    }
                    chromeFrame = geometry.frame
                    chromeRootGeometry = geometry.root
                    chromeLayoutGeneration &+= 1
                    if DebugMediaDiagnostics.shouldCountInvalidChrome(
                        frame: geometry.frame,
                        root: geometry.root,
                        monitoringArmed: chromeMonitoringArmed
                    ) {
                        invalidChromeCount &+= 1
                    }
                    if DebugMediaDiagnostics.chromeFrameIsValid(
                        geometry.frame,
                        root: geometry.root
                    ) {
                        chromeMonitoringArmed = true
                    }
                }

                Spacer()
            }
            .padding(.top, proxy.safeAreaInsets.top)
            .padding(.leading, proxy.safeAreaInsets.leading)
            .padding(.trailing, proxy.safeAreaInsets.trailing)
        }
    }

    @ViewBuilder
    private func mediaPage(for mediaID: String) -> some View {
        if let fixture = presentation.items.first(where: {
            $0.id == mediaID
        }) {
            DebugMediaPage(
                fixture: fixture,
                delayedReleased: delayedReleased,
                failureRecovered: failureRecovered,
                resetGeneration: resetGenerationByID[mediaID] ?? 0,
                reduceMotion: reduceMotion || reductionOverride,
                ownershipController: ownershipController,
                retryFailure: {
                    failureRecovered = true
                },
                toggleChrome: {
                    chromeVisible.toggle()
                },
                capabilityChanged: { capability, scale in
                    guard !isClosing else {
                        return
                    }
                    capabilityByID[mediaID] = capability
                    zoomScaleByID[mediaID] = scale
                },
                inputMetricsChanged: { metrics in
                    guard !isClosing else {
                        return
                    }
                    inputMetricsByID[mediaID] = metrics
                },
                viewportMetricsChanged: { metrics in
                    guard !isClosing else {
                        return
                    }
                    let monitoringArmed = viewportMonitoringArmedIDs
                        .contains(mediaID)
                    if DebugMediaDiagnostics.shouldCountInvalidViewport(
                        metrics,
                        monitoringArmed: monitoringArmed,
                        isCurrentMedia: currentID == mediaID
                    ) {
                        invalidViewportCount &+= 1
                        lastInvalidViewport = DebugMediaDiagnostics
                            .viewportText(metrics)
                    }
                    if metrics.hasFiniteLegalGeometry {
                        viewportMonitoringArmedIDs.insert(mediaID)
                    }
                    viewportMetricsByID[mediaID] = metrics
                }
            )
        } else {
            Color.black
        }
    }

    private var currentCapability: MediaPageCapability {
        guard let currentID else {
            return .minimumZoom
        }
        return capabilityByID[currentID] ?? .minimumZoom
    }

    private var pagingEnabled: Bool {
        presentation.items.count > 1
    }

    private var positionText: String {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return "0/0"
        }
        return "\(index + 1)/\(presentation.items.count)"
    }

    private var zoomScaleText: String {
        guard let currentID else {
            return "1.00"
        }
        return String(format: "%.2f", zoomScaleByID[currentID] ?? 1)
    }

    private func moveMediaAccessibility(
        _ direction: AccessibilityAdjustmentDirection
    ) {
        switch direction {
        case .increment:
            moveMedia(by: 1)
        case .decrement:
            moveMedia(by: -1)
        @unknown default:
            return
        }
    }

    private func canMoveMedia(by offset: Int) -> Bool {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return false
        }
        return presentation.items.indices.contains(index + offset)
    }

    private func moveMedia(by offset: Int) {
        guard let currentID,
              let index = presentation.items.firstIndex(where: {
                  $0.id == currentID
              }) else {
            return
        }
        let targetIndex = index + offset
        guard presentation.items.indices.contains(targetIndex) else {
            return
        }
        ownershipController.invalidateActiveSession()
        resetTransform(for: currentID)
        externalSelectionGeneration &+= 1
        self.currentID = presentation.items[targetIndex].id
    }

    private var boundaryText: String {
        switch currentCapability.horizontalBoundary {
        case .both:
            "both"
        case .interior:
            "interior"
        case .leading:
            "leading"
        case .trailing:
            "trailing"
        }
    }

    private var ownerText: String {
        switch gestureSession?.owner ?? .none {
        case .none:
            "none"
        case .pager:
            "pager"
        case .mediaPan:
            "media-pan"
        }
    }

    private func handlePagerEvent(
        _ event: PagerContainerEvent<String>
    ) {
        switch event {
        case let .began(transition):
            transitionSourceID = transition.sourceID
        case let .resolved(_, completed):
            guard completed,
                  let transitionSourceID else {
                self.transitionSourceID = nil
                return
            }
            resetTransform(for: transitionSourceID)
            self.transitionSourceID = nil
        }
    }

    private func closeViewer() {
        guard !isClosing else {
            return
        }
        isClosing = true
        ownershipController.onSessionChanged = { _ in }
        ownershipController.invalidateActiveSession()
        capabilityByID.removeAll(keepingCapacity: false)
        zoomScaleByID.removeAll(keepingCapacity: false)
        resetGenerationByID.removeAll(keepingCapacity: false)
        inputMetricsByID.removeAll(keepingCapacity: false)
        viewportMetricsByID.removeAll(keepingCapacity: false)
        viewportMonitoringArmedIDs.removeAll(keepingCapacity: false)
        chromeMonitoringArmed = false
        transitionSourceID = nil
        close()
    }

}

private extension DebugMediaViewer {
    func resetTransform(for mediaID: String) {
        resetGenerationByID[mediaID, default: 0] &+= 1
        capabilityByID[mediaID] = .minimumZoom
        zoomScaleByID[mediaID] = 1
    }

    var sessionMetricsText: String {
        DebugMediaDiagnostics.sessionText(gestureSession)
    }

    var inputMetricsText: String {
        let metrics = currentID.flatMap { inputMetricsByID[$0] }
            ?? DebugMediaInputMetrics()
        let totalPanBeginCount = inputMetricsByID.values.reduce(0) {
            $0 &+ $1.panBeginCount
        }
        let totalPanEndCount = inputMetricsByID.values.reduce(0) {
            $0 &+ $1.panEndCount
        }
        return DebugMediaDiagnostics.inputText(
            metrics,
            totalPanBeginCount: totalPanBeginCount,
            totalPanEndCount: totalPanEndCount
        )
    }

    var layoutMetricsText: String {
        let appearance = colorScheme == .dark ? "dark" : "light"
        let type = String(describing: dynamicTypeSize)
        let motion = reduceMotion || reductionOverride ? "true" : "false"
        return "appearance=\(appearance)"
            + " dynamicType=\(type)"
            + " reduceMotion=\(motion) "
            + DebugMediaDiagnostics.layoutText(
            currentID.flatMap { viewportMetricsByID[$0] },
            pagerCoordinatorSequence:
                ownershipController.pagerCoordinatorSequence,
            invalidViewportCount: invalidViewportCount,
            lastInvalidViewport: lastInvalidViewport
        )
    }

    var chromeMetricsText: String {
        DebugMediaDiagnostics.chromeText(
            visible: chromeVisible,
            frame: chromeFrame,
            root: chromeRootGeometry,
            chromeLayoutGeneration: chromeLayoutGeneration,
            invalidChromeCount: invalidChromeCount
        )
    }
}
#endif
