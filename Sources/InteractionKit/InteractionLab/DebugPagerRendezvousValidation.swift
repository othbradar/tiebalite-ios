#if DEBUG
import UIKit

extension PagerContainer.Coordinator {
    func prepareDelegateSlot(
        _ rendezvous: inout PagerTransitionRendezvous<PageID>,
        in pageViewController: UIPageViewController
    ) -> Bool {
        guard rendezvous.delegateEvidence != nil else {
            return true
        }
        guard let failure = storedDelegateValidationFailure(
            rendezvous,
            in: pageViewController
        ) else {
            recordIgnoredCallback(.duplicateDelegate)
            return false
        }
        rejectStoredDelegate(failure, in: &rendezvous)
        guard let updated = activeRendezvous else {
            return false
        }
        rendezvous = updated
        return true
    }

    func transitionDirection(
        for transition: PagerTransition<PageID>
    ) -> PagerTransitionDirection? {
        guard let sourceIndex = transition.frozenOrder.firstIndex(
            of: transition.sourceID
        ),
              let targetIndex = transition.frozenOrder.firstIndex(
                of: transition.targetID
              ),
              abs(sourceIndex - targetIndex) == 1 else {
            return nil
        }
        return targetIndex > sourceIndex ? .forward : .reverse
    }

    func hasExternalSelectionChanged(
        from context: PagerTransitionCallbackContext<PageID>
    ) -> Bool {
        parent.externalSelectionGeneration
            != context.externalSelectionGeneration
            || parent.selection != context.transition.sourceID
    }

    func callbackValidationFailure(
        _ context: PagerTransitionCallbackContext<PageID>,
        previous: PagerHostingController<PageID, PageContent>,
        visible: PagerHostingController<PageID, PageContent>,
        transitionCompleted: Bool,
        externalSelectionSuperseded: Bool
    ) -> PagerCallbackIgnoredReason? {
        guard state.transition?.token == context.transition.token,
              context.controllerInstallationGeneration
                == controllerInstallationGeneration else {
            return .staleTransition
        }
        guard previous.pageID == context.transition.sourceID else {
            return .previousSourceMismatch
        }
        guard previous.instanceSequence
                == context.sourceControllerSequence,
              controllers[previous.pageID] === previous else {
            return .previousControllerMismatch
        }
        let expectedVisibleID = transitionCompleted
            ? context.transition.targetID
            : context.transition.sourceID
        let expectedVisibleSequence = transitionCompleted
            ? context.targetControllerSequence
            : context.sourceControllerSequence
        guard visible.pageID == expectedVisibleID else {
            return .visiblePageMismatch
        }
        guard visible.instanceSequence == expectedVisibleSequence,
              controllers[visible.pageID] === visible else {
            return .visibleControllerMismatch
        }
        guard controllers[context.transition.targetID]?
                .instanceSequence == context.targetControllerSequence else {
            return .targetControllerMismatch
        }
        guard transitionDirection(for: context.transition)
                == context.direction,
              directionSignMatches(context.direction) else {
            return .directionMismatch
        }
        guard externalSelectionSuperseded
                || parent.externalSelectionGeneration
                == context.externalSelectionGeneration else {
            return .externalSelectionChanged
        }
        return nil
    }

    func storedDelegateValidationFailure(
        _ rendezvous: PagerTransitionRendezvous<PageID>,
        in pageViewController: UIPageViewController
    ) -> PagerCallbackIgnoredReason? {
        let context = rendezvous.context
        guard let delegate = rendezvous.delegateEvidence else {
            return .duplicateOrStaleTerminal
        }
        guard delegate.transitionTokenSequence
                == context.transition.token.sequence,
              delegate.inputSequence == context.inputSequence,
              delegate.direction == context.direction,
              delegate.externalSelectionGeneration
                == context.externalSelectionGeneration,
              delegate.controllerInstallationGeneration
                == context.controllerInstallationGeneration else {
            return .staleTransition
        }
        guard let previous = controllers[context.transition.sourceID],
              previous.instanceSequence
                == context.sourceControllerSequence else {
            return .previousControllerMismatch
        }
        guard let target = controllers[context.transition.targetID],
              target.instanceSequence
                == context.targetControllerSequence else {
            return .targetControllerMismatch
        }
        guard delegate.previousID == previous.pageID,
              delegate.previousControllerSequence
                == previous.instanceSequence else {
            return .previousControllerMismatch
        }
        guard let visible = pageViewController.viewControllers?
                .pagerOnlyElement
                as? PagerHostingController<PageID, PageContent> else {
            return .visibleControllerMismatch
        }
        let expectedVisible = delegate.transitionCompleted
            ? target
            : previous
        guard visible.pageID == expectedVisible.pageID,
              delegate.callbackVisibleID == expectedVisible.pageID else {
            return .visiblePageMismatch
        }
        guard visible === expectedVisible,
              visible.instanceSequence == expectedVisible.instanceSequence,
              delegate.callbackVisibleControllerSequence
                == expectedVisible.instanceSequence else {
            return .visibleControllerMismatch
        }
        guard transitionDirection(for: context.transition)
                == context.direction,
              directionSignMatches(context.direction) else {
            return .directionMismatch
        }
        return nil
    }

    func directionSignMatches(
        _ direction: PagerTransitionDirection
    ) -> Bool {
        switch direction {
        case .forward:
            return inputDirectionSign < 0
        case .reverse:
            return inputDirectionSign > 0
        }
    }

    func ownershipDecision(
        for evidence: PagerMediaOwnershipEvidence<PageID>,
        context: PagerTransitionCallbackContext<PageID>
    ) -> PagerOwnershipDecision {
        switch evidence {
        case .notRequired:
            return context.ownershipIdentity == nil ? .allow : .reject(
                result: .invalidated,
                reason: .ownershipInvalidated,
                callbackReason: .ownershipInvalidated
            )
        case .pending:
            return .pending
        case let .ended(identity):
            guard identity == context.ownershipIdentity,
                  identity.owner == .pager else {
                return .reject(
                    result: .cancelled,
                    reason: .ownershipRejected,
                    callbackReason: .ownershipRejected
                )
            }
            return .allow
        case let .cancelled(identity):
            return ownershipRejection(
                identity: identity,
                context: context,
                reason: .ownershipCancelled,
                callbackReason: .ownershipCancelled
            )
        case let .failed(identity):
            return ownershipRejection(
                identity: identity,
                context: context,
                reason: .ownershipFailed,
                callbackReason: .ownershipFailed
            )
        case let .invalidated(identity):
            if let identity,
               identity != context.ownershipIdentity {
                return .pending
            }
            return .reject(
                result: .invalidated,
                reason: .ownershipInvalidated,
                callbackReason: .ownershipInvalidated
            )
        }
    }

    func ownershipRejection(
        identity: PagerMediaOwnershipIdentity<PageID>,
        context: PagerTransitionCallbackContext<PageID>,
        reason: PagerTransitionRendezvousReason,
        callbackReason: PagerCallbackResolutionReason
    ) -> PagerOwnershipDecision {
        guard identity == context.ownershipIdentity else {
            return .pending
        }
        return .reject(
            result: .cancelled,
            reason: reason,
            callbackReason: callbackReason
        )
    }

    func rejectStoredDelegate(
        _ reason: PagerCallbackIgnoredReason,
        in rendezvous: inout PagerTransitionRendezvous<PageID>
    ) {
        rendezvous.delegateEvidence = nil
        rendezvous.reason = .ignoredCallback(reason)
        activeRendezvous = rendezvous
        lastIgnoredCallbackReason = reason
    }

    func recordIgnoredCallback(_ reason: PagerCallbackIgnoredReason) {
        lastIgnoredCallbackReason = reason
        guard var rendezvous = activeRendezvous,
              rendezvous.result == .pending else {
            return
        }
        rendezvous.reason = .ignoredCallback(reason)
        activeRendezvous = rendezvous
    }

    func applyLatestExternalSelection() {
        let latest = parent.selection
        if latest == nil || latest.map(parent.pageIDs.contains) == true {
            _ = state.selectImmediately(latest)
        }
    }

    func rendezvousReason(
        for callbackReason: PagerCallbackResolutionReason
    ) -> PagerTransitionRendezvousReason {
        switch callbackReason {
        case .committed:
            return .committed
        case .systemBailout, .animationInterrupted:
            return .systemBailout
        case .panCancelled:
            return .pagerCancelled
        case .panFailed:
            return .pagerFailed
        case .missingPanTerminal,
             .staleToken,
             .previousSourceMismatch,
             .visiblePageMismatch,
             .endedWithoutTransition,
             .transitionInvalidated:
            return .transitionInvalidated
        case .ownershipCancelled:
            return .ownershipCancelled
        case .ownershipFailed:
            return .ownershipFailed
        case .ownershipInvalidated:
            return .ownershipInvalidated
        case .ownershipRejected:
            return .ownershipRejected
        case .externalSelectionChanged:
            return .externalSelectionChanged
        }
    }
}

extension Collection {
    var pagerOnlyElement: Element? {
        count == 1 ? first : nil
    }
}
#endif
