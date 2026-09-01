import UIKit

enum PagerOwnershipDecision {
    case pending
    case allow
    case reject(
        result: PagerTransitionRendezvousResult,
        reason: PagerTransitionRendezvousReason,
        callbackReason: PagerCallbackResolutionReason
    )
}

private struct PagerResolvedCallbackJoin<PageID>
where PageID: Hashable & Sendable {
    let rendezvous: PagerTransitionRendezvous<PageID>
    let evidence: PagerTransitionCallbackEvidence<PageID>
    let resolution: PagerCallbackResolution
    let result: PagerTransitionRendezvousResult
}

private struct PagerResolvedOutcome {
    let resolution: PagerCallbackResolution
    let result: PagerTransitionRendezvousResult
    let reason: PagerTransitionRendezvousReason
}

extension PagerContainer.Coordinator {
    func beginTransitionRendezvous(
        transition: PagerTransition<PageID>,
        inputSequence: UInt64,
        source: PagerHostingController<PageID, PageContent>,
        target: PagerHostingController<PageID, PageContent>
    ) -> Bool {
        guard activeRendezvous == nil,
              state.transition?.token == transition.token,
              source.pageID == transition.sourceID,
              target.pageID == transition.targetID,
              controllers[source.pageID] === source,
              controllers[target.pageID] === target,
              let direction = transitionDirection(for: transition) else {
            return false
        }
        let ownershipEvidence = parent.mediaGestureOwnership?
            .pagerTransitionOwnershipEvidence(sourceID: transition.sourceID)
            ?? .notRequired
        let ownershipIdentity: PagerMediaOwnershipIdentity<PageID>?
        if case let .pending(identity) = ownershipEvidence {
            ownershipIdentity = identity
        } else {
            ownershipIdentity = nil
        }
        let context = PagerTransitionCallbackContext(
            transition: transition,
            inputSequence: inputSequence,
            direction: direction,
            externalSelectionGeneration:
                parent.externalSelectionGeneration,
            controllerInstallationGeneration:
                controllerInstallationGeneration,
            sourceControllerSequence: source.instanceSequence,
            targetControllerSequence: target.instanceSequence,
            ownershipIdentity: ownershipIdentity
        )
        let terminal = lastTerminalGestureRecord.flatMap { record in
            record.inputSequence == inputSequence ? record : nil
        }
        activeRendezvous = PagerTransitionRendezvous(
            context: context,
            pagerTerminal: terminal,
            ownershipEvidence: ownershipEvidence
        )
#if DEBUG
        lastIgnoredCallbackReason = nil
#endif
        return true
    }

    func observedTerminalPanPhase() -> PagerPanTerminalPhase? {
        guard let recognizer = observedPagerPanRecognizer else {
            return nil
        }
        switch recognizer.state {
        case .ended:
            return .ended
        case .cancelled:
            return .cancelled
        case .failed:
            return .failed
        case .possible, .began, .changed:
            return nil
        @unknown default:
            return .failed
        }
    }

    func recordDelegateCompletion(
        in pageViewController: UIPageViewController,
        finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted: Bool,
        terminalPhaseObservedAtCallback: PagerPanTerminalPhase?
    ) {
        guard pageViewController === installedController else {
            recordIgnoredCallback(.wrongPageViewController)
            return
        }
        guard var rendezvous = activeRendezvous,
              rendezvous.result == .pending else {
            recordIgnoredCallback(.noActiveContext)
            showCommittedPageIfNeeded(
                in: pageViewController,
                animated: false
            )
            return
        }
        if hasExternalSelectionChanged(from: rendezvous.context) {
            _ = recordExternalSelectionChangeIfNeeded()
            guard let updated = activeRendezvous else {
                return
            }
            rendezvous = updated
        }
        guard prepareDelegateSlot(
            &rendezvous,
            in: pageViewController
        ) else {
            return
        }
        let terminalAlreadyRecorded = rendezvous.pagerTerminal != nil
        guard terminalAlreadyRecorded
                || terminalPhaseObservedAtCallback != nil else {
            recordIgnoredCallback(.terminalNotObserved)
            return
        }
        if let terminal = rendezvous.pagerTerminal,
           let observed = terminalPhaseObservedAtCallback,
           terminal.trace.terminalPhase != observed {
            recordIgnoredCallback(.terminalPhaseMismatch)
            return
        }
        guard let previous = previousViewControllers.pagerOnlyElement
                as? PagerHostingController<PageID, PageContent>,
              let visible = pageViewController.viewControllers?
                .pagerOnlyElement
                as? PagerHostingController<PageID, PageContent> else {
            recordIgnoredCallback(.previousControllerMismatch)
            return
        }
        if let failure = callbackValidationFailure(
            rendezvous.context,
            previous: previous,
            visible: visible,
            transitionCompleted: transitionCompleted,
            externalSelectionSuperseded:
                rendezvous.externalSelectionSuperseded
        ) {
            recordIgnoredCallback(failure)
            return
        }
        let context = rendezvous.context
        rendezvous.delegateEvidence = PagerTransitionDelegateRecord(
            transitionTokenSequence:
                context.transition.token.sequence,
            inputSequence: context.inputSequence,
            terminalPhaseObservedAtCallback:
                terminalPhaseObservedAtCallback,
            finished: finished,
            transitionCompleted: transitionCompleted,
            previousID: previous.pageID,
            previousControllerSequence: previous.instanceSequence,
            callbackVisibleID: visible.pageID,
            callbackVisibleControllerSequence: visible.instanceSequence,
            direction: context.direction,
            externalSelectionGeneration:
                context.externalSelectionGeneration,
            controllerInstallationGeneration:
                context.controllerInstallationGeneration
        )
        rendezvous.reason = .delegateAccepted
        activeRendezvous = rendezvous
        _ = resolvePendingCallbackIfReady()
    }

    @discardableResult
    func recordPagerTerminalEvidence(
        _ terminal: PagerTerminalGestureRecord
    ) -> Bool {
        guard var rendezvous = activeRendezvous,
              rendezvous.result == .pending,
              terminal.inputSequence == rendezvous.context.inputSequence,
              state.transition?.token
                == rendezvous.context.transition.token else {
            return false
        }
        guard rendezvous.pagerTerminal == nil else {
            recordIgnoredCallback(.duplicateOrStaleTerminal)
            return false
        }
        rendezvous.pagerTerminal = terminal
        activeRendezvous = rendezvous
        return resolvePendingCallbackIfReady()
    }

    func mediaOwnershipSessionChanged(
        _ session: MediaGestureSession<PageID>?
    ) {
        guard var rendezvous = activeRendezvous,
              rendezvous.result == .pending,
              let expected = rendezvous.context.ownershipIdentity,
              let session else {
            return
        }
        guard let evidence = installedMediaGestureOwnership?
            .pagerRendezvousEvidence(
                for: session,
                coordinatorSequence: coordinatorSequence
            ),
              evidence.matches(expected) else {
            return
        }
        rendezvous.ownershipEvidence = evidence
        activeRendezvous = rendezvous
        _ = resolvePendingCallbackIfReady()
    }

    @discardableResult
    func resolvePendingCallbackIfReady() -> Bool {
        _ = recordExternalSelectionChangeIfNeeded()
        guard let pageViewController = installedController,
              var rendezvous = activeRendezvous,
              rendezvous.result == .pending else {
            return false
        }
        guard state.transition?.token
                == rendezvous.context.transition.token,
              controllerInstallationGeneration
                == rendezvous.context.controllerInstallationGeneration else {
            invalidateActiveRendezvousWithoutPublishing(
                reason: .transitionInvalidated
            )
            return false
        }
        guard let delegate = rendezvous.delegateEvidence else {
            rendezvous.reason = .waitingForDelegate
            activeRendezvous = rendezvous
            return false
        }
        guard let terminal = rendezvous.pagerTerminal else {
            rendezvous.reason = .waitingForPagerTerminal
            activeRendezvous = rendezvous
            return false
        }
        if let observed = delegate.terminalPhaseObservedAtCallback,
           observed != terminal.trace.terminalPhase {
            rejectStoredDelegate(
                .terminalPhaseMismatch,
                in: &rendezvous
            )
            return false
        }
        if let failure = storedDelegateValidationFailure(
            rendezvous,
            in: pageViewController
        ) {
            rejectStoredDelegate(failure, in: &rendezvous)
            return false
        }
        guard let join = resolvedCallbackJoin(
            rendezvous: rendezvous,
            delegate: delegate,
            terminal: terminal
        ) else {
            return false
        }
        return applyResolvedCallback(
            join,
            in: pageViewController
        )
    }

    private func resolvedCallbackJoin(
        rendezvous: PagerTransitionRendezvous<PageID>,
        delegate: PagerTransitionDelegateRecord<PageID>,
        terminal: PagerTerminalGestureRecord
    ) -> PagerResolvedCallbackJoin<PageID>? {
        var rendezvous = rendezvous
        let context = rendezvous.context
        let evidence = PagerTransitionCallbackEvidence(
            tokenSequence: state.transition?.token.sequence ?? 0,
            panTerminal: terminal.trace.terminalPhase,
            finished: delegate.finished,
            transitionCompleted: delegate.transitionCompleted,
            previousID: delegate.previousID,
            visibleID: delegate.callbackVisibleID
        )
        let strictResolution = context.expectation.resolve(evidence)
        if let expected = context.ownershipIdentity,
           installedMediaGestureOwnership?
            .isCurrentPagerRendezvousIdentity(
                expected,
                coordinatorSequence: coordinatorSequence
            ) != true {
            rendezvous.ownershipEvidence = .invalidated(expected)
        }
        let decision = ownershipDecision(
            for: rendezvous.ownershipEvidence,
            context: context
        )
        if case .pending = decision {
            rendezvous.reason = .waitingForOwnershipTerminal
            activeRendezvous = rendezvous
            return nil
        }
        let outcome: PagerResolvedOutcome
        if rendezvous.externalSelectionSuperseded {
            outcome = PagerResolvedOutcome(
                resolution: PagerCallbackResolution(
                    completed: false,
                    reason: .externalSelectionChanged
                ),
                result: .invalidated,
                reason: .externalSelectionChanged
            )
        } else {
            outcome = resolvedOutcome(
                strictResolution: strictResolution,
                ownershipDecision: decision
            )
        }
        rendezvous.result = outcome.result
        rendezvous.reason = outcome.reason
        return PagerResolvedCallbackJoin(
            rendezvous: rendezvous,
            evidence: evidence,
            resolution: outcome.resolution,
            result: outcome.result
        )
    }

    private func resolvedOutcome(
        strictResolution: PagerCallbackResolution,
        ownershipDecision: PagerOwnershipDecision
    ) -> PagerResolvedOutcome {
        guard strictResolution.completed else {
            return PagerResolvedOutcome(
                resolution: strictResolution,
                result: .cancelled,
                reason: rendezvousReason(for: strictResolution.reason)
            )
        }
        switch ownershipDecision {
        case .allow:
            return PagerResolvedOutcome(
                resolution: strictResolution,
                result: .committed,
                reason: .committed
            )
        case let .reject(result, reason, callbackReason):
            return PagerResolvedOutcome(
                resolution: PagerCallbackResolution(
                    completed: false,
                    reason: callbackReason
                ),
                result: result,
                reason: reason
            )
        case .pending:
            return PagerResolvedOutcome(
                resolution: PagerCallbackResolution(
                    completed: false,
                    reason: .missingPanTerminal
                ),
                result: .invalidated,
                reason: .transitionInvalidated
            )
        }
    }

    @discardableResult
    func recordExternalSelectionChangeIfNeeded() -> Bool {
        guard var rendezvous = activeRendezvous,
              rendezvous.result == .pending,
              hasExternalSelectionChanged(from: rendezvous.context),
              !rendezvous.externalSelectionSuperseded else {
            return false
        }
        rendezvous.externalSelectionSuperseded = true
        rendezvous.reason = .externalSelectionChanged
        activeRendezvous = rendezvous
        return true
    }

    func invalidateActiveRendezvousWithoutPublishing(
        reason: PagerTransitionRendezvousReason
    ) {
        guard var rendezvous = activeRendezvous else {
            return
        }
        _ = state.resolveTransition(
            token: rendezvous.context.transition.token,
            completed: false
        )
        rendezvous.result = .invalidated
        rendezvous.reason = reason
        rendezvous.didPublish = false
        activeRendezvous = nil
#if DEBUG
        lastResolvedRendezvous = rendezvous
#endif
        clearResolvedInputTrace()
    }

    private func applyResolvedCallback(
        _ join: PagerResolvedCallbackJoin<PageID>,
        in pageViewController: UIPageViewController
    ) -> Bool {
        var rendezvous = join.rendezvous
        let completed = join.result == .committed
        guard state.resolveTransition(
            token: rendezvous.context.transition.token,
            completed: completed
        ) else {
            invalidateActiveRendezvousWithoutPublishing(
                reason: .transitionInvalidated
            )
            return false
        }
        if rendezvous.externalSelectionSuperseded {
            applyLatestExternalSelection()
        }
        rendezvous.didPublish = true
        activeRendezvous = nil
#if DEBUG
        lastResolvedRendezvous = rendezvous
#endif
        invalidateDeferredSelectionCommit()
        if parent.selection != state.committedID {
            parent.selection = state.committedID
        }
        showCommittedPageIfNeeded(
            in: pageViewController,
            animated: false
        )
        refreshCachedContent()
        trimControllerCache()
#if DEBUG
        if parent.inputDiagnosticsEnabled,
           let trace = rendezvous.pagerTerminal?.trace {
            emitInputDiagnostic(
                context: rendezvous.context,
                trace: trace,
                resolution: join.resolution,
                evidence: join.evidence,
                finalVisibleID: (pageViewController.viewControllers?.first
                    as? PagerHostingController<PageID, PageContent>)?.pageID
            )
        }
#endif
        clearResolvedInputTrace()
#if DEBUG
        parent.onEvent(
            .resolved(
                snapshot: snapshot(),
                completed: completed
            )
        )
        scheduleSettledSnapshot()
#else
        parent.onEvent(.resolved(completed: completed))
#endif
        return true
    }
}
