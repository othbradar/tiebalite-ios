import Testing
@testable import TiebaLite
import UIKit

struct MediaInteractionStateTests {
    @Test
    func minimumZoomHorizontalGestureBelongsToPager() {
        let session = MediaGestureSession.begin(
            mediaID: "small",
            capability: .minimumZoom,
            intent: .towardNext
        )

        #expect(session.owner == .pager)
    }

    @Test
    func zoomedInteriorGestureStaysWithZoomPageEvenAfterReachingBoundary() {
        let session = MediaGestureSession.begin(
            mediaID: "large",
            capability: MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .interior
            ),
            intent: .towardNext
        )

        let afterBoundaryChange = session.updatingCapability(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .trailing
            )
        )

        #expect(session.owner == .mediaPan)
        #expect(afterBoundaryChange.owner == .mediaPan)
        #expect(session.decisionReason == .zoomedMediaPan)
    }

    @Test
    func nextGestureAtMatchingZoomBoundaryMayBelongToPager() {
        let towardPrevious = MediaGestureSession.begin(
            mediaID: "large",
            capability: MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .leading
            ),
            intent: .towardPrevious
        )
        let towardContent = MediaGestureSession.begin(
            mediaID: "large",
            capability: MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .leading
            ),
            intent: .towardNext
        )

        #expect(towardPrevious.owner == .pager)
        #expect(towardContent.owner == .mediaPan)
    }

    @Test
    func ambiguousOrVerticalIntentNeverStartsPaging() {
        let session = MediaGestureSession.begin(
            mediaID: "small",
            capability: .minimumZoom,
            intent: .verticalOrAmbiguous
        )

        #expect(session.owner == .none)
        #expect(session.decisionReason == .ambiguousAtMinimumZoom)
    }

    @Test
    func sessionRecordsBeginEvidenceAndOwnerNeverChanges() {
        let session = MediaGestureSession<String>.begin(
            gestureSessionID: 41,
            generation: 7,
            mediaID: "large",
            evidence: MediaGestureBeginEvidence(
                zoomScale: 2.5,
                contentOffset: CGPoint(x: 120, y: 80),
                velocity: CGPoint(x: -420, y: 20),
                translation: CGPoint(x: -32, y: 2),
                capability: MediaPageCapability(
                    atMinimumZoom: false,
                    horizontalBoundary: .interior
                ),
                intent: .towardNext
            )
        )
        let atBoundary = session.updatingCapability(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .trailing
            )
        )

        #expect(session.gestureSessionID == 41)
        #expect(session.generation == 7)
        #expect(session.beganZoomScale == 2.5)
        #expect(session.beganContentOffsetX == 120)
        #expect(session.initialVelocityX == -420)
        #expect(atBoundary.owner == .mediaPan)
        #expect(atBoundary.initialCapability.horizontalBoundary == .interior)
        #expect(atBoundary.latestCapability.horizontalBoundary == .trailing)
    }

    @Test
    func cancelledAndFailedSessionsCannotRemainActive() {
        let session = MediaGestureSession.begin(
            mediaID: "large",
            capability: .minimumZoom,
            intent: .towardNext
        )

        #expect(session.finishing(as: .cancelled).phase == .cancelled)
        #expect(session.finishing(as: .failed).phase == .failed)
    }

    @Test
    @MainActor
    func runtimeGateShouldBeginCallsOwnershipPolicyAndExcludesLoser() throws {
        var currentID: String? = "large"
        let ownership = MediaGestureOwnershipController<String>()
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let pagerPan = UIPanGestureRecognizer()
        root.addGestureRecognizer(pagerPan)
        let zoom = MediaZoomScrollView(frame: root.bounds)
        root.addSubview(zoom)
        let zoomView = MediaZoomImageView(
            mediaID: "large",
            image: UIGraphicsImageRenderer(
                size: CGSize(width: 64, height: 64)
            ).image { _ in },
            ownershipController: ownership,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
        let zoomCoordinator = zoomView.makeCoordinator()
        zoomCoordinator.install(on: zoom)
        zoom.configure(
            image: zoomView.image,
            mediaID: "large"
        )
        zoom.layoutIfNeeded()
        zoom.setZoomScale(2, animated: false)
        ownership.register(mediaID: "large", scrollView: zoom)
        ownership.install(
            on: root,
            pagerPanRecognizer: pagerPan,
            currentMediaID: { currentID }
        )
        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)

        #expect(!ownership.gateCanBePrevented(by: pagerPan))
        #expect(!ownership.gateCanBePrevented(by: zoom.panGestureRecognizer))
        #expect(ownership.gestureRecognizerShouldBegin(gate))
        let session = try #require(ownership.activeSession)
        #expect(session.mediaID == "large")
        #expect(session.owner == .mediaPan)
        #expect(ownership.gateCanPrevent(pagerPan))
        #expect(!ownership.gateCanPrevent(zoom.panGestureRecognizer))

        let range = zoom.legalContentOffsetRange
        zoom.contentOffset = CGPoint(
            x: range.maximumX,
            y: zoom.contentOffset.y
        )
        ownership.refreshActiveSessionCapability()
        let updatedSession = try #require(ownership.activeSession)
        #expect(updatedSession.owner == .mediaPan)
        #expect(updatedSession.initialCapability == session.initialCapability)
        #expect(updatedSession.latestCapability.horizontalBoundary == .trailing)

        currentID = "small"
        ownership.mediaDidChange(to: currentID)
        #expect(ownership.activeSession == nil)
        #expect(ownership.lastSession?.phase == .invalidated)
        #expect(
            !ownership.allowsPagerResolution(
                sessionID: session.gestureSessionID,
                sourceID: "large",
                completed: true
            )
        )
        zoomCoordinator.dismantle(zoom)
        ownership.uninstall()
    }

    @Test
    @MainActor
    func runtimeAmbiguousDirectionSuppressesBothPagerAndMediaPan() throws {
        let ownership = MediaGestureOwnershipController<String>()
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let pagerPan = UIPanGestureRecognizer()
        root.addGestureRecognizer(pagerPan)
        let zoom = MediaZoomScrollView(frame: root.bounds)
        root.addSubview(zoom)
        ownership.register(mediaID: "small", scrollView: zoom)
        ownership.install(
            on: root,
            pagerPanRecognizer: pagerPan,
            currentMediaID: { "small" }
        )
        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: 30, y: 90)
        gate.testingTranslation = CGPoint(x: 4, y: 30)

        #expect(ownership.gestureRecognizerShouldBegin(gate))
        let session = try #require(ownership.activeSession)
        #expect(session.owner == MediaGestureOwner.none)
        #expect(ownership.gateCanPrevent(pagerPan))
        #expect(ownership.gateCanPrevent(zoom.panGestureRecognizer))
        #expect(
            !ownership.gestureRecognizer(
                gate,
                shouldRecognizeSimultaneouslyWith: pagerPan
            )
        )
        #expect(
            !ownership.gestureRecognizer(
                gate,
                shouldRecognizeSimultaneouslyWith: zoom.panGestureRecognizer
            )
        )
        ownership.uninstall()
    }

    @Test
    @MainActor
    func reduceMotionDoesNotChangeRuntimeOwnerDecision() throws {
        let standard = runtimeOwner(reduceMotion: false)
        let reduced = runtimeOwner(reduceMotion: true)

        #expect(standard == .pager)
        #expect(reduced == standard)
    }

    @Test
    func committedDepartureResetsOnlyTheSourceMediaID() {
        var registry = MediaZoomStateRegistry<String>()
        registry.update(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .trailing
            ),
            for: "large"
        )
        registry.update(.minimumZoom, for: "small")

        registry.resolveDeparture(
            sourceID: "large",
            targetID: "small",
            completed: true
        )

        #expect(registry.capability(for: "large") == .minimumZoom)
        #expect(registry.capability(for: "small") == .minimumZoom)
    }

    @Test
    func cancelledDeparturePreservesZoomAndNeverLeaksItToAnotherID() {
        var registry = MediaZoomStateRegistry<String>()
        let zoomed = MediaPageCapability(
            atMinimumZoom: false,
            horizontalBoundary: .interior
        )
        registry.update(zoomed, for: "large")

        registry.resolveDeparture(
            sourceID: "large",
            targetID: "small",
            completed: false
        )

        #expect(registry.capability(for: "large") == zoomed)
        #expect(registry.capability(for: "small") == .minimumZoom)
    }

    @Test
    func closingViewerClearsEveryPerIDCapability() {
        var registry = MediaZoomStateRegistry<String>()
        registry.update(
            MediaPageCapability(
                atMinimumZoom: false,
                horizontalBoundary: .both
            ),
            for: "large"
        )
        registry.close()

        #expect(registry.trackedIDs.isEmpty)
        #expect(registry.capability(for: "large") == .minimumZoom)
    }

    @MainActor
    private func runtimeOwner(reduceMotion: Bool) -> MediaGestureOwner? {
        let ownership = MediaGestureOwnershipController<String>()
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let pagerPan = UIPanGestureRecognizer()
        root.addGestureRecognizer(pagerPan)
        ownership.install(
            on: root,
            pagerPanRecognizer: pagerPan,
            currentMediaID: { "small" }
        )
        let gate = ownership.ownershipGateRecognizer
        gate?.testingVelocity = CGPoint(x: -300, y: 5)
        gate?.testingTranslation = CGPoint(x: -30, y: 1)
        if let gate {
            _ = ownership.gestureRecognizerShouldBegin(gate)
        }
        let owner = ownership.activeSession?.owner
        let view = MediaZoomImageView(
            mediaID: reduceMotion ? "reduced" : "standard",
            image: UIGraphicsImageRenderer(
                size: CGSize(width: 8, height: 8)
            ).image { _ in },
            reduceMotion: reduceMotion,
            onSingleTap: {},
            onCapabilityChanged: { _, _ in }
        )
        #expect(view.animatesZoomTransition == !reduceMotion)
        ownership.uninstall()
        return owner
    }
}
