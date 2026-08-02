#if DEBUG
import UIKit

extension PagerContainer.Coordinator {
    func transitionDirectionSign(
        _ transition: PagerTransition<PageID>
    ) -> Double {
        guard let sourceIndex = transition.frozenOrder.firstIndex(
            of: transition.sourceID
        ),
              let targetIndex = transition.frozenOrder.firstIndex(
                of: transition.targetID
              ) else {
            return inputDirectionSign
        }
        return targetIndex > sourceIndex ? -1 : 1
    }

    func beginInputTraceIfNeeded() {
        guard activeInputSequence == nil else {
            return
        }
        activeInputSequence = nextInputSequence
        nextInputSequence &+= 1
        activeGestureTrace = PagerGestureTrace()
        lastTerminalGestureRecord = nil
        if let recognizer = observedPagerPanRecognizer {
            recordGestureSample(recognizer)
        }
    }

    func recordGestureSample(
        _ recognizer: UIPanGestureRecognizer
    ) {
        guard var trace = activeGestureTrace else {
            return
        }
        if inputDirectionSign == 0 {
            let velocity = recognizer.velocity(in: recognizer.view)
            let translation = recognizer.translation(in: recognizer.view)
            let vector = abs(velocity.x) > 1
                ? velocity.x
                : translation.x
            guard abs(vector) > 1 else {
                return
            }
            inputDirectionSign = vector < 0 ? -1 : 1
        }
        trace.record(progress: normalizedProgress(recognizer))
        activeGestureTrace = trace
    }

    func finishGestureTrace(
        _ recognizer: UIPanGestureRecognizer,
        phase: PagerPanTerminalPhase
    ) {
        beginInputTraceIfNeeded()
        guard var trace = activeGestureTrace,
              let inputSequence = activeInputSequence else {
            return
        }
        let width = max(
            Double(installedController?.view.bounds.width ?? 0),
            1
        )
        let velocity = Double(
            recognizer.velocity(in: recognizer.view).x
        ) * inputDirectionSign / width
        trace.finish(
            phase: phase,
            progress: normalizedProgress(recognizer),
            velocityPagesPerSecond: velocity
        )
        activeGestureTrace = nil
        let terminalRecord = PagerTerminalGestureRecord(
            inputSequence: inputSequence,
            trace: trace
        )
        lastTerminalGestureRecord = terminalRecord

        if recordPagerTerminalEvidence(terminalRecord) {
            return
        }

        guard state.transition == nil,
              let sourceID = state.committedID else {
            return
        }
        if parent.inputDiagnosticsEnabled {
            parent.onInputDiagnostic(
                PagerInputDiagnostic(
                    inputSequence: inputSequence,
                    sourceID: sourceID,
                    targetID: nil,
                    transitionTokenSequence: nil,
                    trace: trace,
                    systemCompleted: false,
                    businessCompleted: false,
                    resolutionReason: .endedWithoutTransition,
                    previousID: nil,
                    callbackVisibleID: sourceID,
                    visibleID: sourceID,
                    committedID: state.committedID
                )
            )
        }
        clearResolvedInputTrace()
    }

    private func normalizedProgress(
        _ recognizer: UIPanGestureRecognizer
    ) -> Double {
        let width = max(
            Double(installedController?.view.bounds.width ?? 0),
            1
        )
        return Double(
            recognizer.translation(in: recognizer.view).x
        ) * inputDirectionSign / width
    }

    var lastGestureTrace: PagerGestureTrace? {
        get {
            lastTerminalGestureRecord?.trace
        }
        set {
            guard let newValue else {
                lastTerminalGestureRecord = nil
                return
            }
            guard let inputSequence = transitionInputSequence
                ?? activeInputSequence else {
                return
            }
            let terminalRecord = PagerTerminalGestureRecord(
                inputSequence: inputSequence,
                trace: newValue
            )
            lastTerminalGestureRecord = terminalRecord
            _ = recordPagerTerminalEvidence(terminalRecord)
        }
    }

    func terminalRecord(
        matching context: PagerTransitionCallbackContext<PageID>
    ) -> PagerTerminalGestureRecord? {
        guard state.transition?.token == context.transition.token,
              let terminalRecord = activeRendezvous?.pagerTerminal,
              terminalRecord.inputSequence == context.inputSequence else {
            return nil
        }
        return terminalRecord
    }

    func emitInputDiagnostic(
        context: PagerTransitionCallbackContext<PageID>,
        trace: PagerGestureTrace,
        resolution: PagerCallbackResolution,
        evidence: PagerTransitionCallbackEvidence<PageID>,
        finalVisibleID: PageID?
    ) {
        let transition = context.transition
        parent.onInputDiagnostic(
            PagerInputDiagnostic(
                inputSequence: context.inputSequence,
                sourceID: transition.sourceID,
                targetID: transition.targetID,
                transitionTokenSequence: transition.token.sequence,
                trace: trace,
                systemCompleted: evidence.transitionCompleted,
                businessCompleted: resolution.completed,
                resolutionReason: resolution.reason,
                previousID: evidence.previousID,
                callbackVisibleID: evidence.visibleID,
                visibleID: finalVisibleID,
                committedID: state.committedID
            )
        )
    }

    func clearResolvedInputTrace() {
        activeInputSequence = nil
        transitionInputSequence = nil
        activeGestureTrace = nil
        lastTerminalGestureRecord = nil
        inputDirectionSign = 0
    }

    func installPagerPanObserver(
        _ recognizer: UIPanGestureRecognizer
    ) {
        guard observedPagerPanRecognizer !== recognizer else {
            return
        }
        if observedPagerPanRecognizer != nil {
            invalidateActiveRendezvousWithoutPublishing(
                reason: .transitionInvalidated
            )
        }
        uninstallPagerPanObserver()
        recognizer.addTarget(
            self,
            action: #selector(pagerPanChanged(_:))
        )
        observedPagerPanRecognizer = recognizer
    }

    func uninstallPagerPanObserver() {
        observedPagerPanRecognizer?.removeTarget(
            self,
            action: #selector(pagerPanChanged(_:))
        )
        observedPagerPanRecognizer = nil
        clearResolvedInputTrace()
    }

    func installPagerContentOffsetObserver(_ scrollView: UIScrollView) {
        guard observedPagerScrollView !== scrollView else {
            return
        }
        uninstallPagerContentOffsetObserver()
        observedPagerScrollView = scrollView
        pagerContentOffsetObservation = scrollView.observe(
            \.contentOffset,
            options: [.new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self,
                      self.state.transition == nil,
                      self.snapshot().geometry?.coversPagerBounds == true else {
                    return
                }
                self.scheduleSettledSnapshot()
            }
        }
    }

    func uninstallPagerContentOffsetObserver() {
        pagerContentOffsetObservation?.invalidate()
        pagerContentOffsetObservation = nil
        observedPagerScrollView = nil
    }
}
#endif
