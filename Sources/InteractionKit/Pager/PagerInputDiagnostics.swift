import Foundation

enum PagerPanTerminalPhase: Equatable, Sendable {
    case active
    case ended
    case cancelled
    case failed
}

struct PagerGestureTrace: Equatable, Sendable {
    private(set) var sampleCount = 1
    private(set) var minimumProgress = 0.0
    private(set) var maximumProgress = 0.0
    private(set) var terminalProgress = 0.0
    private(set) var terminalVelocityPagesPerSecond = 0.0
    private(set) var terminalPhase = PagerPanTerminalPhase.active
    private(set) var reversalCount = 0

    var peakProgress: Double {
        max(abs(minimumProgress), abs(maximumProgress))
    }

    private var previousProgress = 0.0
    private var previousMovementSign = 0

    mutating func record(progress: Double) {
        guard progress.isFinite else {
            return
        }
        let delta = progress - previousProgress
        let movementSign: Int
        if delta > 0.000_1 {
            movementSign = 1
        } else if delta < -0.000_1 {
            movementSign = -1
        } else {
            movementSign = 0
        }
        if movementSign != 0,
           previousMovementSign != 0,
           movementSign != previousMovementSign {
            reversalCount += 1
        }
        if movementSign != 0 {
            previousMovementSign = movementSign
        }
        previousProgress = progress
        terminalProgress = progress
        minimumProgress = min(minimumProgress, progress)
        maximumProgress = max(maximumProgress, progress)
        sampleCount += 1
    }

    mutating func finish(
        phase: PagerPanTerminalPhase,
        progress: Double,
        velocityPagesPerSecond: Double
    ) {
        record(progress: progress)
        terminalVelocityPagesPerSecond = velocityPagesPerSecond.isFinite
            ? velocityPagesPerSecond
            : 0
        terminalPhase = phase
    }
}

struct PagerTerminalGestureRecord: Equatable, Sendable {
    let inputSequence: UInt64
    let trace: PagerGestureTrace
}

enum PagerTransitionDirection: Equatable, Sendable {
    case forward
    case reverse
}

struct PagerMediaOwnershipIdentity<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let sessionID: UInt64
    let generation: UInt64
    let sourceID: PageID
    let owner: MediaGestureOwner
    let pagerCoordinatorSequence: UInt64
}

enum PagerMediaOwnershipEvidence<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    case notRequired
    case pending(PagerMediaOwnershipIdentity<PageID>)
    case ended(PagerMediaOwnershipIdentity<PageID>)
    case cancelled(PagerMediaOwnershipIdentity<PageID>)
    case failed(PagerMediaOwnershipIdentity<PageID>)
    case invalidated(PagerMediaOwnershipIdentity<PageID>?)

    func matches(
        _ expected: PagerMediaOwnershipIdentity<PageID>
    ) -> Bool {
        switch self {
        case .notRequired:
            return false
        case let .pending(identity),
             let .ended(identity),
             let .cancelled(identity),
             let .failed(identity):
            return identity == expected
        case let .invalidated(identity):
            return identity == expected
        }
    }
}

enum PagerTransitionRendezvousResult: Equatable, Sendable {
    case pending
    case committed
    case cancelled
    case invalidated
}

enum PagerCallbackIgnoredReason: Equatable, Sendable {
    case noActiveContext
    case wrongPageViewController
    case staleTransition
    case terminalNotObserved
    case terminalPhaseMismatch
    case previousSourceMismatch
    case previousControllerMismatch
    case visiblePageMismatch
    case visibleControllerMismatch
    case targetControllerMismatch
    case directionMismatch
    case externalSelectionChanged
    case duplicateDelegate
    case duplicateOrStaleTerminal
}

enum PagerTransitionRendezvousReason: Equatable, Sendable {
    case transitionStarted
    case waitingForDelegate
    case waitingForPagerTerminal
    case waitingForOwnershipTerminal
    case delegateAccepted
    case committed
    case systemBailout
    case pagerCancelled
    case pagerFailed
    case ownershipCancelled
    case ownershipFailed
    case ownershipInvalidated
    case ownershipRejected
    case externalSelectionChanged
    case transitionInvalidated
    case ignoredCallback(PagerCallbackIgnoredReason)
}

enum PagerCallbackResolutionReason: Equatable, Sendable {
    case committed
    case systemBailout
    case animationInterrupted
    case panCancelled
    case panFailed
    case missingPanTerminal
    case staleToken
    case previousSourceMismatch
    case visiblePageMismatch
    case endedWithoutTransition
    case ownershipCancelled
    case ownershipFailed
    case ownershipInvalidated
    case ownershipRejected
    case externalSelectionChanged
    case transitionInvalidated
}

struct PagerCallbackResolution: Equatable, Sendable {
    let completed: Bool
    let reason: PagerCallbackResolutionReason
}

struct PagerTransitionCallbackEvidence<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let tokenSequence: UInt64
    let panTerminal: PagerPanTerminalPhase
    let finished: Bool
    let transitionCompleted: Bool
    let previousID: PageID?
    let visibleID: PageID?
}

struct PagerTransitionCallbackExpectation<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let tokenSequence: UInt64
    let sourceID: PageID
    let targetID: PageID

    func resolve(
        _ evidence: PagerTransitionCallbackEvidence<PageID>
    ) -> PagerCallbackResolution {
        guard evidence.tokenSequence == tokenSequence else {
            return PagerCallbackResolution(
                completed: false,
                reason: .staleToken
            )
        }
        switch evidence.panTerminal {
        case .cancelled:
            return PagerCallbackResolution(
                completed: false,
                reason: .panCancelled
            )
        case .failed:
            return PagerCallbackResolution(
                completed: false,
                reason: .panFailed
            )
        case .active:
            return PagerCallbackResolution(
                completed: false,
                reason: .missingPanTerminal
            )
        case .ended:
            break
        }
        guard evidence.finished else {
            return PagerCallbackResolution(
                completed: false,
                reason: .animationInterrupted
            )
        }
        guard evidence.previousID == sourceID else {
            return PagerCallbackResolution(
                completed: false,
                reason: .previousSourceMismatch
            )
        }
        let expectedVisibleID = evidence.transitionCompleted
            ? targetID
            : sourceID
        guard evidence.visibleID == expectedVisibleID else {
            return PagerCallbackResolution(
                completed: false,
                reason: .visiblePageMismatch
            )
        }
        guard evidence.transitionCompleted else {
            return PagerCallbackResolution(
                completed: false,
                reason: .systemBailout
            )
        }
        return PagerCallbackResolution(
            completed: true,
            reason: .committed
        )
    }
}

struct PagerTransitionCallbackContext<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let transition: PagerTransition<PageID>
    let expectation: PagerTransitionCallbackExpectation<PageID>
    let inputSequence: UInt64
    let direction: PagerTransitionDirection
    let externalSelectionGeneration: UInt64
    let controllerInstallationGeneration: UInt64
    let sourceControllerSequence: UInt64
    let targetControllerSequence: UInt64
    let ownershipIdentity: PagerMediaOwnershipIdentity<PageID>?

    init(
        transition: PagerTransition<PageID>,
        inputSequence: UInt64,
        direction: PagerTransitionDirection,
        externalSelectionGeneration: UInt64,
        controllerInstallationGeneration: UInt64,
        sourceControllerSequence: UInt64,
        targetControllerSequence: UInt64,
        ownershipIdentity: PagerMediaOwnershipIdentity<PageID>?
    ) {
        self.transition = transition
        expectation = PagerTransitionCallbackExpectation(
            tokenSequence: transition.token.sequence,
            sourceID: transition.sourceID,
            targetID: transition.targetID
        )
        self.inputSequence = inputSequence
        self.direction = direction
        self.externalSelectionGeneration = externalSelectionGeneration
        self.controllerInstallationGeneration =
            controllerInstallationGeneration
        self.sourceControllerSequence = sourceControllerSequence
        self.targetControllerSequence = targetControllerSequence
        self.ownershipIdentity = ownershipIdentity
    }
}

struct PagerTransitionDelegateRecord<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let transitionTokenSequence: UInt64
    let inputSequence: UInt64
    let terminalPhaseObservedAtCallback: PagerPanTerminalPhase?
    let finished: Bool
    let transitionCompleted: Bool
    let previousID: PageID?
    let previousControllerSequence: UInt64?
    let callbackVisibleID: PageID?
    let callbackVisibleControllerSequence: UInt64?
    let direction: PagerTransitionDirection
    let externalSelectionGeneration: UInt64
    let controllerInstallationGeneration: UInt64
}

struct PagerTransitionRendezvous<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let context: PagerTransitionCallbackContext<PageID>
    var delegateEvidence: PagerTransitionDelegateRecord<PageID>?
    var pagerTerminal: PagerTerminalGestureRecord?
    var ownershipEvidence: PagerMediaOwnershipEvidence<PageID>
    var externalSelectionSuperseded: Bool
    var result: PagerTransitionRendezvousResult
    var didPublish: Bool
    var reason: PagerTransitionRendezvousReason

    init(
        context: PagerTransitionCallbackContext<PageID>,
        pagerTerminal: PagerTerminalGestureRecord?,
        ownershipEvidence: PagerMediaOwnershipEvidence<PageID>
    ) {
        self.context = context
        delegateEvidence = nil
        self.pagerTerminal = pagerTerminal
        self.ownershipEvidence = ownershipEvidence
        externalSelectionSuperseded = false
        result = .pending
        didPublish = false
        reason = .transitionStarted
    }
}

struct PagerInputDiagnostic<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let inputSequence: UInt64
    let sourceID: PageID
    let targetID: PageID?
    let transitionTokenSequence: UInt64?
    let trace: PagerGestureTrace
    let systemCompleted: Bool
    let businessCompleted: Bool
    let resolutionReason: PagerCallbackResolutionReason
    let previousID: PageID?
    let callbackVisibleID: PageID?
    let visibleID: PageID?
    let committedID: PageID?
}
