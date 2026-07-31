#if DEBUG
import SwiftUI
import UIKit

struct PagerContainerSnapshot<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let committedID: PageID?
    let liveIDs: [PageID]
    let resolvedTransitionCount: Int
    let controllerCount: Int
}

enum PagerContainerEvent<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    case began(PagerTransition<PageID>)
    case resolved(
        snapshot: PagerContainerSnapshot<PageID>,
        completed: Bool
    )
}

@MainActor
struct PagerContainer<PageID, PageContent>: UIViewControllerRepresentable
where PageID: Hashable & Sendable, PageContent: View {
    let pageIDs: [PageID]
    @Binding var selection: PageID?
    let backgroundColor: UIColor
    let reduceMotion: Bool
    let pagingEnabled: Bool
    let onEvent: (PagerContainerEvent<PageID>) -> Void
    @ViewBuilder let content: (PageID) -> PageContent

    init(
        pageIDs: [PageID],
        selection: Binding<PageID?>,
        backgroundColor: UIColor,
        reduceMotion: Bool,
        pagingEnabled: Bool = true,
        onEvent: @escaping (PagerContainerEvent<PageID>) -> Void = { _ in },
        @ViewBuilder content: @escaping (PageID) -> PageContent
    ) {
        self.pageIDs = pageIDs
        _selection = selection
        self.backgroundColor = backgroundColor
        self.reduceMotion = reduceMotion
        self.pagingEnabled = pagingEnabled
        self.onEvent = onEvent
        self.content = content
    }

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

    @MainActor
    final class Coordinator:
        NSObject,
        UIPageViewControllerDataSource,
        UIPageViewControllerDelegate {
        var parent: PagerContainer

        private var state: PagerStateMachine<PageID>
        private var controllers: [
            PageID: PagerHostingController<PageID, PageContent>
        ] = [:]
        private weak var installedController: UIPageViewController?
        private var selectionCommitTask: Task<Void, Never>?

        var cachedControllerCount: Int {
            controllers.count
        }

        var isInstalled: Bool {
            installedController != nil
        }

        init(parent: PagerContainer) {
            self.parent = parent
            state = PagerStateMachine(
                pageIDs: parent.pageIDs,
                committedID: parent.selection
            )
        }

        func install(on controller: UIPageViewController) {
            installedController = controller
            controller.dataSource = self
            controller.delegate = self
            controller.view.backgroundColor = parent.backgroundColor
            configureInternalScrollViews(in: controller)
        }

        func synchronize(_ controller: UIPageViewController) {
            controller.view.backgroundColor = parent.backgroundColor
            configureInternalScrollViews(in: controller)
            refreshCachedContent()
            _ = state.updatePages(parent.pageIDs)

            guard state.transition == nil else {
                return
            }

            if parent.selection != state.committedID,
               parent.selection.map(parent.pageIDs.contains) == true {
                _ = state.selectImmediately(parent.selection)
            }

            if state.committedID != parent.selection {
                scheduleSelectionCommit(state.committedID)
            }

            showCommittedPageIfNeeded(
                in: controller,
                animated: !parent.reduceMotion
            )
            trimControllerCache()
        }

        func dismantle(_ controller: UIPageViewController) {
            selectionCommitTask?.cancel()
            selectionCommitTask = nil
            controller.delegate = nil
            controller.dataSource = nil
            controllers.removeAll(keepingCapacity: false)
            installedController = nil
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            adjacentController(
                to: viewController,
                offset: -1
            )
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            adjacentController(
                to: viewController,
                offset: 1
            )
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            guard let target = pendingViewControllers.first
                as? PagerHostingController<PageID, PageContent>,
                  let token = state.beginTransition(to: target.pageID),
                  let transition = state.transition,
                  transition.token == token else {
                return
            }
            parent.onEvent(.began(transition))
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard let transition = state.transition else {
                return
            }
            guard state.resolveTransition(
                token: transition.token,
                completed: completed
            ) else {
                return
            }

            parent.selection = state.committedID
            showCommittedPageIfNeeded(
                in: pageViewController,
                animated: false
            )
            trimControllerCache()
            parent.onEvent(
                .resolved(
                    snapshot: snapshot(),
                    completed: completed
                )
            )
        }

        private func adjacentController(
            to viewController: UIViewController,
            offset: Int
        ) -> UIViewController? {
            guard let host = viewController
                as? PagerHostingController<PageID, PageContent> else {
                return nil
            }
            let activeOrder = state.transition?.frozenOrder
                ?? state.displayedOrder
            guard let index = activeOrder.firstIndex(of: host.pageID) else {
                return nil
            }
            let adjacentIndex = index + offset
            guard activeOrder.indices.contains(adjacentIndex) else {
                return nil
            }
            return controller(for: activeOrder[adjacentIndex])
        }

        private func controller(
            for pageID: PageID
        ) -> PagerHostingController<PageID, PageContent> {
            if let cached = controllers[pageID] {
                return cached
            }
            let controller = PagerHostingController(
                pageID: pageID,
                rootView: parent.content(pageID)
            )
            controller.view.backgroundColor = parent.backgroundColor
            controllers[pageID] = controller
            return controller
        }

        private func refreshCachedContent() {
            for (pageID, controller) in controllers {
                controller.rootView = parent.content(pageID)
            }
        }

        private func showCommittedPageIfNeeded(
            in controller: UIPageViewController,
            animated: Bool
        ) {
            guard let committedID = state.committedID else {
                if !(controller.viewControllers ?? []).isEmpty {
                    controller.setViewControllers(
                        [],
                        direction: .forward,
                        animated: false
                    )
                }
                return
            }

            if let visible = controller.viewControllers?.first
                as? PagerHostingController<PageID, PageContent>,
               visible.pageID == committedID {
                return
            }

            let direction = navigationDirection(to: committedID)
            controller.setViewControllers(
                [self.controller(for: committedID)],
                direction: direction,
                animated: animated
            )
        }

        private func navigationDirection(
            to pageID: PageID
        ) -> UIPageViewController.NavigationDirection {
            guard let current = installedController?.viewControllers?.first
                    as? PagerHostingController<PageID, PageContent>,
                  let currentIndex = state.displayedOrder.firstIndex(
                    of: current.pageID
                  ),
                  let nextIndex = state.displayedOrder.firstIndex(
                    of: pageID
                  ) else {
                return .forward
            }
            return nextIndex >= currentIndex ? .forward : .reverse
        }

        private func trimControllerCache() {
            let liveIDs = Set(
                PagerCachePolicy.liveIDs(
                    pageIDs: state.displayedOrder,
                    committedID: state.committedID,
                    transition: state.transition
                )
            )
            controllers = controllers.filter { liveIDs.contains($0.key) }
        }

        private func snapshot() -> PagerContainerSnapshot<PageID> {
            PagerContainerSnapshot(
                committedID: state.committedID,
                liveIDs: PagerCachePolicy.liveIDs(
                    pageIDs: state.displayedOrder,
                    committedID: state.committedID,
                    transition: state.transition
                ),
                resolvedTransitionCount: state.resolvedTransitionCount,
                controllerCount: controllers.count
            )
        }

        private func scheduleSelectionCommit(_ selection: PageID?) {
            selectionCommitTask?.cancel()
            let binding = parent.$selection
            selectionCommitTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled,
                      binding.wrappedValue != selection else {
                    return
                }
                binding.wrappedValue = selection
            }
        }

        private func configureInternalScrollViews(
            in controller: UIPageViewController
        ) {
            for case let scrollView as UIScrollView
                in controller.view.subviews {
                scrollView.backgroundColor = parent.backgroundColor
                scrollView.isScrollEnabled = parent.pagingEnabled
            }
        }
    }
}

@MainActor
private final class PagerHostingController<PageID, Content>:
    UIHostingController<Content>
where PageID: Hashable & Sendable, Content: View {
    let pageID: PageID

    init(pageID: PageID, rootView: Content) {
        self.pageID = pageID
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder: NSCoder) {
        nil
    }
}
#endif
