@MainActor
final class MediaGestureOwnershipRendezvousObserver<MediaID>
where MediaID: Hashable & Sendable {
    private let receiveSession: (MediaGestureSession<MediaID>?) -> Void

    init(
        receiveSession: @escaping (MediaGestureSession<MediaID>?) -> Void
    ) {
        self.receiveSession = receiveSession
    }

    func receive(_ session: MediaGestureSession<MediaID>?) {
        receiveSession(session)
    }
}

extension MediaGestureOwnershipController {
    func pagerTransitionOwnershipEvidence(
        sourceID: MediaID
    ) -> PagerMediaOwnershipEvidence<MediaID> {
        guard let activeSession,
              activeSession.mediaID == sourceID,
              activeSession.phase == .active,
              activeSession.generation == generation,
              pagerCoordinatorSequence != 0 else {
            return .invalidated(nil)
        }
        return .pending(pagerIdentity(for: activeSession))
    }

    func pagerRendezvousEvidence(
        for session: Session,
        coordinatorSequence: UInt64
    ) -> PagerMediaOwnershipEvidence<MediaID>? {
        guard pagerCoordinatorSequence == coordinatorSequence else {
            return nil
        }
        let identity = pagerIdentity(for: session)
        guard session.generation == generation else {
            return .invalidated(identity)
        }
        switch session.phase {
        case .active:
            return .pending(identity)
        case .ended:
            return .ended(identity)
        case .cancelled:
            return .cancelled(identity)
        case .failed:
            return .failed(identity)
        case .invalidated:
            return .invalidated(identity)
        }
    }

    func isCurrentPagerRendezvousIdentity(
        _ identity: PagerMediaOwnershipIdentity<MediaID>,
        coordinatorSequence: UInt64
    ) -> Bool {
        guard pagerCoordinatorSequence == coordinatorSequence,
              identity.pagerCoordinatorSequence == coordinatorSequence,
              identity.generation == generation,
              let lastSession else {
            return false
        }
        return lastSession.gestureSessionID == identity.sessionID
            && lastSession.generation == identity.generation
            && lastSession.mediaID == identity.sourceID
            && lastSession.owner == identity.owner
    }

    private func pagerIdentity(
        for session: Session
    ) -> PagerMediaOwnershipIdentity<MediaID> {
        PagerMediaOwnershipIdentity(
            sessionID: session.gestureSessionID,
            generation: session.generation,
            sourceID: session.mediaID,
            owner: session.owner,
            pagerCoordinatorSequence: pagerCoordinatorSequence
        )
    }
}
