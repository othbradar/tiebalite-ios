import SwiftUI
import UIKit

enum PagerContainerEvent<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    case began(PagerTransition<PageID>)
#if DEBUG
    case resolved(
        snapshot: PagerContainerSnapshot<PageID>,
        completed: Bool
    )
#else
    case resolved(completed: Bool)
#endif

    var completedResolution: Bool? {
        switch self {
        case .began:
            nil
#if DEBUG
        case let .resolved(_, completed):
            completed
#else
        case let .resolved(completed):
            completed
#endif
        }
    }
}

@MainActor
struct PagerContainer<PageID, PageContent>: UIViewControllerRepresentable
where PageID: Hashable & Sendable, PageContent: View {
    let pageIDs: [PageID]
    @Binding var selection: PageID?
    let backgroundColor: UIColor
    let reduceMotion: Bool
    let pagingEnabled: Bool
    let mediaGestureOwnership: MediaGestureOwnershipController<PageID>?
    @Binding var externalSelectionGeneration: UInt64
    let contentGeneration: ((PageID) -> UInt64)?
#if DEBUG
    let inputDiagnosticsEnabled: Bool
#endif
    let onEvent: (PagerContainerEvent<PageID>) -> Void
#if DEBUG
    let onSettledSnapshot: ((PagerContainerSnapshot<PageID>) -> Void)?
    let onTransitionSnapshot: ((PagerContainerSnapshot<PageID>) -> Void)?
    let onInputDiagnostic: (PagerInputDiagnostic<PageID>) -> Void
#endif
    @ViewBuilder let content: (PageID) -> PageContent

#if DEBUG
    init(
        pageIDs: [PageID],
        selection: Binding<PageID?>,
        backgroundColor: UIColor,
        reduceMotion: Bool,
        pagingEnabled: Bool = true,
        mediaGestureOwnership: MediaGestureOwnershipController<PageID>? = nil,
        externalSelectionGeneration: Binding<UInt64> = .constant(0),
        contentGeneration: ((PageID) -> UInt64)? = nil,
        inputDiagnosticsEnabled: Bool = false,
        onEvent: @escaping (PagerContainerEvent<PageID>) -> Void = { _ in },
        onSettledSnapshot: ((
            PagerContainerSnapshot<PageID>
        ) -> Void)? = nil,
        onTransitionSnapshot: ((
            PagerContainerSnapshot<PageID>
        ) -> Void)? = nil,
        onInputDiagnostic: @escaping (
            PagerInputDiagnostic<PageID>
        ) -> Void = { _ in },
        @ViewBuilder content: @escaping (PageID) -> PageContent
    ) {
        self.pageIDs = pageIDs
        _selection = selection
        self.backgroundColor = backgroundColor
        self.reduceMotion = reduceMotion
        self.pagingEnabled = pagingEnabled
        self.mediaGestureOwnership = mediaGestureOwnership
        _externalSelectionGeneration = externalSelectionGeneration
        self.contentGeneration = contentGeneration
        self.inputDiagnosticsEnabled = inputDiagnosticsEnabled
        self.onEvent = onEvent
        self.onSettledSnapshot = onSettledSnapshot
        self.onTransitionSnapshot = onTransitionSnapshot
        self.onInputDiagnostic = onInputDiagnostic
        self.content = content
    }
#else
    init(
        pageIDs: [PageID],
        selection: Binding<PageID?>,
        backgroundColor: UIColor,
        reduceMotion: Bool,
        pagingEnabled: Bool = true,
        mediaGestureOwnership: MediaGestureOwnershipController<PageID>? = nil,
        externalSelectionGeneration: Binding<UInt64> = .constant(0),
        contentGeneration: ((PageID) -> UInt64)? = nil,
        onEvent: @escaping (PagerContainerEvent<PageID>) -> Void = { _ in },
        @ViewBuilder content: @escaping (PageID) -> PageContent
    ) {
        self.pageIDs = pageIDs
        _selection = selection
        self.backgroundColor = backgroundColor
        self.reduceMotion = reduceMotion
        self.pagingEnabled = pagingEnabled
        self.mediaGestureOwnership = mediaGestureOwnership
        _externalSelectionGeneration = externalSelectionGeneration
        self.contentGeneration = contentGeneration
        self.onEvent = onEvent
        self.content = content
    }
#endif

    @MainActor
    final class Coordinator:
        NSObject,
        UIPageViewControllerDataSource,
        UIPageViewControllerDelegate {
        var parent: PagerContainer

        var state: PagerStateMachine<PageID>
        var controllers: [
            PageID: PagerHostingController<PageID, PageContent>
        ] = [:]
        weak var installedController: UIPageViewController?
        weak var installedMediaGestureOwnership:
            MediaGestureOwnershipController<PageID>?
        weak var observedPagerPanRecognizer: UIPanGestureRecognizer?
#if DEBUG
        weak var observedPagerScrollView: UIScrollView?
        var pagerContentOffsetObservation: NSKeyValueObservation?
#endif
        var selectionCommitTask: Task<Void, Never>?
        var selectionCommitGeneration: UInt64 = 0
#if DEBUG
        var settledSnapshotTask: Task<Void, Never>?
        var settledSnapshotGeneration: UInt64 = 0
        var lastEmittedSettledSnapshot: PagerContainerSnapshot<PageID>?
        var lastEmittedTransitionSnapshot: PagerContainerSnapshot<PageID>?
#endif
        var mediaOwnershipObserver:
            MediaGestureOwnershipRendezvousObserver<PageID>?
        var activeRendezvous: PagerTransitionRendezvous<PageID>?
#if DEBUG
        var lastResolvedRendezvous: PagerTransitionRendezvous<PageID>?
        var lastIgnoredCallbackReason: PagerCallbackIgnoredReason?
#endif
        var controllerInstallationGeneration: UInt64 = 0
        var nextInputSequence: UInt64 = 1
        var activeInputSequence: UInt64?
        var transitionInputSequence: UInt64?
        var activeGestureTrace: PagerGestureTrace?
        var lastTerminalGestureRecord: PagerTerminalGestureRecord?
        var pendingCallbackContext:
            PagerTransitionCallbackContext<PageID>? {
            activeRendezvous?.context
        }
        var pendingDelegateRecord:
            PagerTransitionDelegateRecord<PageID>? {
            activeRendezvous?.delegateEvidence
        }
        var inputDirectionSign = 0.0
#if DEBUG
        var rejectedOverlappingTransitionCount = 0
        var maximumActiveCallbackDepth = 0
        var createdControllerCount = 0
        var contentBuildCount = 0
        var evictedControllerCount = 0
#endif
        let coordinatorSequence: UInt64

        init(parent: PagerContainer) {
            self.parent = parent
            coordinatorSequence = PagerCoordinatorSequenceSource.next()
            state = PagerStateMachine(
                pageIDs: parent.pageIDs,
                committedID: parent.selection
            )
        }

        @objc
        func pagerPanChanged(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                beginInputTraceIfNeeded()
            case .changed:
                beginInputTraceIfNeeded()
                recordGestureSample(recognizer)
            case .ended:
                finishGestureTrace(recognizer, phase: .ended)
            case .cancelled:
                finishGestureTrace(recognizer, phase: .cancelled)
            case .failed:
                finishGestureTrace(recognizer, phase: .failed)
            case .possible:
                break
            @unknown default:
                finishGestureTrace(recognizer, phase: .failed)
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard pageViewController === installedController else {
                return nil
            }
            return adjacentController(
                to: viewController,
                offset: -1
            )
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard pageViewController === installedController else {
                return nil
            }
            return adjacentController(
                to: viewController,
                offset: 1
            )
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            guard pageViewController === installedController else {
                return
            }
            guard pendingCallbackContext == nil,
                  state.transition == nil else {
#if DEBUG
                rejectedOverlappingTransitionCount += 1
#endif
                return
            }
            guard let source = pageViewController.viewControllers?.first
                    as? PagerHostingController<PageID, PageContent>,
                  controllers[source.pageID] === source,
                  let target = pendingViewControllers.first
                as? PagerHostingController<PageID, PageContent>,
                  controllers[target.pageID] === target,
                  let token = state.beginTransition(to: target.pageID),
                  let transition = state.transition,
                  transition.token == token else {
                return
            }
#if DEBUG
            invalidateSettledSnapshot()
#endif
            beginInputTraceIfNeeded()
            guard let inputSequence = activeInputSequence else {
                _ = state.resolveTransition(
                    token: transition.token,
                    completed: false
                )
                return
            }
            transitionInputSequence = inputSequence
            inputDirectionSign = transitionDirectionSign(transition)
            guard beginTransitionRendezvous(
                transition: transition,
                inputSequence: inputSequence,
                source: source,
                target: target
            ) else {
                _ = state.resolveTransition(
                    token: transition.token,
                    completed: false
                )
                clearResolvedInputTrace()
                return
            }
#if DEBUG
            maximumActiveCallbackDepth = max(
                maximumActiveCallbackDepth,
                pendingCallbackContext == nil ? 0 : 1
            )
            lastEmittedTransitionSnapshot = snapshot()
#endif
            parent.onEvent(.began(transition))
            refreshCachedContent()
#if DEBUG
            emitTransitionSnapshotIfChanged()
#endif
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            recordDelegateCompletion(
                in: pageViewController,
                finished: finished,
                previousViewControllers: previousViewControllers,
                transitionCompleted: completed,
                terminalPhaseObservedAtCallback:
                    observedTerminalPanPhase()
            )
        }

    }
}

extension PagerContainer {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        context.coordinator.install(on: controller)
        context.coordinator.synchronize(controller)
        return controller
    }

    func updateUIViewController(
        _ pageViewController: UIPageViewController,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.synchronize(pageViewController)
    }

    static func dismantleUIViewController(
        _ pageViewController: UIPageViewController,
        coordinator: Coordinator
    ) {
        coordinator.dismantle(pageViewController)
    }
}
