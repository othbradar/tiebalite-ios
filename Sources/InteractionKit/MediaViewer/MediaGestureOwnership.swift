import UIKit

enum MediaHorizontalBoundary: Equatable, Sendable {
    case both
    case interior
    case leading
    case trailing
}

enum MediaHorizontalIntent: Equatable, Sendable {
    case towardNext
    case towardPrevious
    case verticalOrAmbiguous
}

enum MediaGestureOwner: Equatable, Sendable {
    case none
    case pager
    case mediaPan
}

enum MediaGestureDecisionReason: Equatable, Sendable {
    case ambiguousAtMinimumZoom
    case minimumZoomHorizontal
    case zoomedBoundaryOutward
    case zoomedMediaPan
}

enum MediaGestureSessionPhase: Equatable, Sendable {
    case active
    case ended
    case cancelled
    case failed
    case invalidated
}

struct MediaPageCapability: Equatable, Sendable {
    static let minimumZoom = MediaPageCapability(
        atMinimumZoom: true,
        horizontalBoundary: .both
    )

    let atMinimumZoom: Bool
    let horizontalBoundary: MediaHorizontalBoundary
}

struct MediaGestureBeginEvidence: Equatable, Sendable {
    let zoomScale: Double
    let contentOffset: CGPoint
    let velocity: CGPoint
    let translation: CGPoint
    let capability: MediaPageCapability
    let intent: MediaHorizontalIntent
}

struct MediaGestureSession<MediaID>: Equatable, Sendable
where MediaID: Hashable & Sendable {
    let gestureSessionID: UInt64
    let generation: UInt64
    let mediaID: MediaID
    let beganZoomScale: Double
    let beganContentOffsetX: Double
    let beganContentOffsetY: Double
    let initialVelocityX: Double
    let initialVelocityY: Double
    let initialTranslationX: Double
    let initialTranslationY: Double
    let initialIntent: MediaHorizontalIntent
    let initialCapability: MediaPageCapability
    let owner: MediaGestureOwner
    let decisionReason: MediaGestureDecisionReason
    private(set) var latestCapability: MediaPageCapability
    private(set) var phase: MediaGestureSessionPhase

    static func begin(
        gestureSessionID: UInt64,
        generation: UInt64,
        mediaID: MediaID,
        evidence: MediaGestureBeginEvidence
    ) -> Self {
        let decision = decision(
            capability: evidence.capability,
            intent: evidence.intent
        )
        return Self(
            gestureSessionID: gestureSessionID,
            generation: generation,
            mediaID: mediaID,
            beganZoomScale: evidence.zoomScale,
            beganContentOffsetX: Double(evidence.contentOffset.x),
            beganContentOffsetY: Double(evidence.contentOffset.y),
            initialVelocityX: Double(evidence.velocity.x),
            initialVelocityY: Double(evidence.velocity.y),
            initialTranslationX: Double(evidence.translation.x),
            initialTranslationY: Double(evidence.translation.y),
            initialIntent: evidence.intent,
            initialCapability: evidence.capability,
            owner: decision.owner,
            decisionReason: decision.reason,
            latestCapability: evidence.capability,
            phase: .active
        )
    }

    static func begin(
        mediaID: MediaID,
        capability: MediaPageCapability,
        intent: MediaHorizontalIntent
    ) -> Self {
        begin(
            gestureSessionID: 0,
            generation: 0,
            mediaID: mediaID,
            evidence: MediaGestureBeginEvidence(
                zoomScale: capability.atMinimumZoom ? 1 : 2,
                contentOffset: .zero,
                velocity: .zero,
                translation: .zero,
                capability: capability,
                intent: intent
            )
        )
    }

    func updatingCapability(
        _ capability: MediaPageCapability
    ) -> Self {
        var copy = self
        copy.latestCapability = capability
        return copy
    }

    func finishing(as phase: MediaGestureSessionPhase) -> Self {
        precondition(phase != .active)
        var copy = self
        copy.phase = phase
        return copy
    }

    private static func decision(
        capability: MediaPageCapability,
        intent: MediaHorizontalIntent
    ) -> (owner: MediaGestureOwner, reason: MediaGestureDecisionReason) {
        if capability.atMinimumZoom {
            guard intent != .verticalOrAmbiguous else {
                return (.none, .ambiguousAtMinimumZoom)
            }
            return (.pager, .minimumZoomHorizontal)
        }

        switch (capability.horizontalBoundary, intent) {
        case (.both, .towardNext),
             (.both, .towardPrevious),
             (.leading, .towardPrevious),
             (.trailing, .towardNext):
            return (.pager, .zoomedBoundaryOutward)
        case (.interior, _),
             (.leading, .towardNext),
             (.leading, .verticalOrAmbiguous),
             (.trailing, .towardPrevious),
             (.trailing, .verticalOrAmbiguous),
             (.both, .verticalOrAmbiguous):
            return (.mediaPan, .zoomedMediaPan)
        }
    }
}

struct MediaZoomStateRegistry<MediaID>: Equatable, Sendable
where MediaID: Hashable & Sendable {
    private var capabilities: [MediaID: MediaPageCapability] = [:]

    var trackedIDs: Set<MediaID> {
        Set(capabilities.keys)
    }

    mutating func update(
        _ capability: MediaPageCapability,
        for mediaID: MediaID
    ) {
        capabilities[mediaID] = capability
    }

    func capability(for mediaID: MediaID) -> MediaPageCapability {
        capabilities[mediaID] ?? .minimumZoom
    }

    mutating func resolveDeparture(
        sourceID: MediaID,
        targetID: MediaID,
        completed: Bool
    ) {
        guard completed else {
            return
        }
        capabilities[sourceID] = .minimumZoom
        if capabilities[targetID] == nil {
            capabilities[targetID] = .minimumZoom
        }
    }

    mutating func close() {
        capabilities.removeAll(keepingCapacity: false)
    }
}

enum MediaGestureIntentPolicy {
    static func intent(
        velocity: CGPoint,
        translation: CGPoint
    ) -> MediaHorizontalIntent {
        let vector = abs(velocity.x) + abs(velocity.y) > 1
            ? velocity
            : translation
        let horizontal = abs(vector.x)
        let vertical = abs(vector.y)
        guard horizontal >= 24,
              horizontal > vertical * 1.15 else {
            return .verticalOrAmbiguous
        }
        return vector.x < 0 ? .towardNext : .towardPrevious
    }
}

@MainActor
protocol MediaGestureGateRouting: AnyObject {
    func gateCanPrevent(_ other: UIGestureRecognizer) -> Bool
    func gateCanBePrevented(by other: UIGestureRecognizer) -> Bool
    func gateDidReset()
}

@MainActor
final class MediaOwnershipPanGestureRecognizer: UIPanGestureRecognizer {
    weak var routing: (any MediaGestureGateRouting)?
    var testingVelocity: CGPoint?
    var testingTranslation: CGPoint?

    override func velocity(in view: UIView?) -> CGPoint {
        testingVelocity ?? super.velocity(in: view)
    }

    override func translation(in view: UIView?) -> CGPoint {
        testingTranslation ?? super.translation(in: view)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        routing?.gateCanPrevent(preventedGestureRecognizer) ?? false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        routing?.gateCanBePrevented(by: preventingGestureRecognizer)
            ?? super.canBePrevented(by: preventingGestureRecognizer)
    }

    override func reset() {
        super.reset()
        routing?.gateDidReset()
    }
}

@MainActor
final class MediaGestureOwnershipController<MediaID>:
    NSObject,
    UIGestureRecognizerDelegate,
    MediaGestureGateRouting
where MediaID: Hashable & Sendable {
    typealias Session = MediaGestureSession<MediaID>

    private final class WeakZoomReference {
        weak var scrollView: MediaZoomScrollView?

        init(_ scrollView: MediaZoomScrollView) {
            self.scrollView = scrollView
        }
    }

    private var zoomScrollViews: [MediaID: WeakZoomReference] = [:]
    private weak var pagerPanRecognizer: UIPanGestureRecognizer?
    private weak var installedView: UIView?
    private var originalPagerMaximumTouches: Int?
    private var currentMediaID: () -> MediaID? = { nil }
    private var nextSessionID: UInt64 = 1
    private(set) var generation: UInt64 = 1

    private(set) var ownershipGateRecognizer: MediaOwnershipPanGestureRecognizer?
    private(set) var activeSession: Session?
    private(set) var lastSession: Session?
    private(set) var pagerCoordinatorSequence: UInt64 = 0
    var onSessionChanged: (Session?) -> Void = { _ in }
    private weak var pagerRendezvousObserver:
        MediaGestureOwnershipRendezvousObserver<MediaID>?

    func observePagerRendezvous(
        with observer: MediaGestureOwnershipRendezvousObserver<MediaID>
    ) {
        pagerRendezvousObserver = observer
    }

    func stopObservingPagerRendezvous(
        with observer: MediaGestureOwnershipRendezvousObserver<MediaID>
    ) {
        guard pagerRendezvousObserver === observer else {
            return
        }
        pagerRendezvousObserver = nil
    }

    func install(
        on view: UIView,
        pagerPanRecognizer: UIPanGestureRecognizer,
        pagerCoordinatorSequence: UInt64 = 0,
        currentMediaID: @escaping () -> MediaID?
    ) {
        if installedView === view,
           self.pagerPanRecognizer === pagerPanRecognizer,
           ownershipGateRecognizer != nil {
            self.currentMediaID = currentMediaID
            self.pagerCoordinatorSequence = pagerCoordinatorSequence
            return
        }
        uninstall()
        self.currentMediaID = currentMediaID
        self.pagerPanRecognizer = pagerPanRecognizer
        self.pagerCoordinatorSequence = pagerCoordinatorSequence
        originalPagerMaximumTouches = pagerPanRecognizer.maximumNumberOfTouches
        pagerPanRecognizer.maximumNumberOfTouches = 1

        let gate = MediaOwnershipPanGestureRecognizer(
            target: self,
            action: #selector(gateChanged(_:))
        )
        gate.maximumNumberOfTouches = 1
        gate.cancelsTouchesInView = false
        gate.delegate = self
        gate.routing = self
        view.addGestureRecognizer(gate)
        installedView = view
        ownershipGateRecognizer = gate
    }

    func uninstall() {
        invalidateActiveSession()
        if let pagerPanRecognizer,
           let originalPagerMaximumTouches {
            pagerPanRecognizer.maximumNumberOfTouches =
                originalPagerMaximumTouches
        }
        if let gate = ownershipGateRecognizer {
            gate.delegate = nil
            gate.routing = nil
            installedView?.removeGestureRecognizer(gate)
        }
        ownershipGateRecognizer = nil
        installedView = nil
        pagerPanRecognizer = nil
        originalPagerMaximumTouches = nil
        pagerCoordinatorSequence = 0
        currentMediaID = { nil }
    }

    func uninstall(from view: UIView) {
        guard installedView === view else {
            return
        }
        uninstall()
    }

    func register(
        mediaID: MediaID,
        scrollView: MediaZoomScrollView
    ) {
        zoomScrollViews[mediaID] = WeakZoomReference(scrollView)
    }

    func unregister(
        mediaID: MediaID,
        scrollView: MediaZoomScrollView
    ) {
        guard zoomScrollViews[mediaID]?.scrollView === scrollView else {
            return
        }
        zoomScrollViews[mediaID] = nil
        if activeSession?.mediaID == mediaID {
            invalidateActiveSession()
        }
    }

    func mediaDidChange(to mediaID: MediaID?) {
        if activeSession != nil {
            invalidateActiveSession()
        }
        generation &+= 1
    }

    func invalidateActiveSession() {
        finishActiveSession(as: .invalidated)
    }

    func finishActiveSession(as phase: MediaGestureSessionPhase) {
        guard phase != .active,
              let activeSession else {
            return
        }
        finish(activeSession, as: phase)
    }

    func allowsPagerResolution(
        sessionID: UInt64,
        sourceID: MediaID,
        completed: Bool
    ) -> Bool {
        guard completed,
              let lastSession,
              lastSession.gestureSessionID == sessionID,
              lastSession.generation == generation,
              lastSession.mediaID == sourceID,
              lastSession.owner == .pager,
              lastSession.phase == .ended else {
            return false
        }
        return true
    }

    func refreshActiveSessionCapability() {
        guard let activeSession else {
            return
        }
        let capability = zoomScrollViews[activeSession.mediaID]?
            .scrollView?.capability ?? activeSession.latestCapability
        let updated = activeSession.updatingCapability(capability)
        self.activeSession = updated
        lastSession = updated
        notifySessionChanged(updated)
    }

    func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === ownershipGateRecognizer,
              let gate = gestureRecognizer
                as? MediaOwnershipPanGestureRecognizer,
              let mediaID = currentMediaID() else {
            return false
        }

        if activeSession != nil {
            invalidateActiveSession()
        }
        let scrollView = zoomScrollViews[mediaID]?.scrollView
        let velocity = gate.velocity(in: gate.view)
        let translation = gate.translation(in: gate.view)
        let intent = MediaGestureIntentPolicy.intent(
            velocity: velocity,
            translation: translation
        )
        let capability = scrollView?.capability ?? .minimumZoom
        let session = Session.begin(
            gestureSessionID: nextSessionID,
            generation: generation,
            mediaID: mediaID,
            evidence: MediaGestureBeginEvidence(
                zoomScale: Double(scrollView?.zoomScale ?? 1),
                contentOffset: scrollView?.contentOffset ?? .zero,
                velocity: velocity,
                translation: translation,
                capability: capability,
                intent: intent
            )
        )
        nextSessionID &+= 1
        activeSession = session
        lastSession = session
        notifySessionChanged(session)
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === ownershipGateRecognizer
                || otherGestureRecognizer === ownershipGateRecognizer,
              let session = activeSession else {
            return false
        }
        let other = gestureRecognizer === ownershipGateRecognizer
            ? otherGestureRecognizer
            : gestureRecognizer
        switch session.owner {
        case .none:
            return false
        case .pager:
            return other === pagerPanRecognizer
        case .mediaPan:
            return other === zoomScrollViews[session.mediaID]?
                .scrollView?.panGestureRecognizer
        }
    }

    func gateCanPrevent(_ other: UIGestureRecognizer) -> Bool {
        guard let session = activeSession else {
            return false
        }
        let mediaPan = zoomScrollViews[session.mediaID]?
            .scrollView?.panGestureRecognizer
        switch session.owner {
        case .none:
            return other === pagerPanRecognizer || other === mediaPan
        case .pager:
            return other === mediaPan
        case .mediaPan:
            return other === pagerPanRecognizer
        }
    }

    func gateCanBePrevented(by other: UIGestureRecognizer) -> Bool {
        let isRegisteredMediaPan = zoomScrollViews.values.contains {
            $0.scrollView?.panGestureRecognizer === other
        }
        if other === pagerPanRecognizer || isRegisteredMediaPan {
            return false
        }
        return true
    }

    func gateDidReset() {
        finishActiveSession(as: .failed)
    }

    @objc
    private func gateChanged(_ gate: MediaOwnershipPanGestureRecognizer) {
        guard activeSession != nil else {
            return
        }
        switch gate.state {
        case .began:
            break
        case .changed:
            refreshActiveSessionCapability()
        case .ended:
            finishActiveSession(as: .ended)
        case .cancelled:
            finishActiveSession(as: .cancelled)
        case .failed:
            finishActiveSession(as: .failed)
        case .possible:
            break
        @unknown default:
            finishActiveSession(as: .failed)
        }
    }

    private func finish(
        _ session: Session,
        as phase: MediaGestureSessionPhase
    ) {
        let finished = session.finishing(as: phase)
        lastSession = finished
        activeSession = nil
        notifySessionChanged(finished)
    }

    private func notifySessionChanged(_ session: Session?) {
        onSessionChanged(session)
        pagerRendezvousObserver?.receive(session)
    }
}
