import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct MediaGestureSessionBoundaryTests {
    @Test
    func cancelledAndStaleEndedRuntimeSessionsCannotResolvePager() throws {
        var currentID: String? = "large"
        let ownership = MediaGestureOwnershipController<String>()
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let pagerPan = UIPanGestureRecognizer()
        root.addGestureRecognizer(pagerPan)
        ownership.install(
            on: root,
            pagerPanRecognizer: pagerPan,
            currentMediaID: { currentID }
        )
        let gate = try #require(ownership.ownershipGateRecognizer)
        gate.testingVelocity = CGPoint(x: -360, y: 10)
        gate.testingTranslation = CGPoint(x: -30, y: 1)

        #expect(ownership.gestureRecognizerShouldBegin(gate))
        let cancelled = try #require(ownership.activeSession)
        #expect(cancelled.owner == .pager)
        ownership.finishActiveSession(as: .cancelled)
        #expect(ownership.activeSession == nil)
        #expect(ownership.lastSession?.phase == .cancelled)
        #expect(
            !ownership.allowsPagerResolution(
                sessionID: cancelled.gestureSessionID,
                sourceID: "large",
                completed: true
            )
        )

        gate.reset()
        #expect(ownership.activeSession == nil)
        #expect(ownership.lastSession?.phase == .cancelled)

        #expect(ownership.gestureRecognizerShouldBegin(gate))
        let ended = try #require(ownership.activeSession)
        #expect(
            ended.gestureSessionID == cancelled.gestureSessionID + 1
        )
        #expect(ended.phase == .active)
        #expect(ownership.lastSession == ended)
        #expect(
            !ownership.allowsPagerResolution(
                sessionID: cancelled.gestureSessionID,
                sourceID: "large",
                completed: true
            )
        )
        ownership.finishActiveSession(as: .ended)
        currentID = "small"
        ownership.mediaDidChange(to: currentID)
        #expect(
            !ownership.allowsPagerResolution(
                sessionID: ended.gestureSessionID,
                sourceID: "large",
                completed: true
            )
        )
        ownership.uninstall()
    }
}
