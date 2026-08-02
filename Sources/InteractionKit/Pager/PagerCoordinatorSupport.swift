import UIKit

extension PagerContainer.Coordinator {
    var cachedControllerCount: Int {
        controllers.count
    }

    var isInstalled: Bool {
        installedController != nil
    }

    func adjacentController(
        to viewController: UIViewController,
        offset: Int
    ) -> UIViewController? {
        guard let host = viewController
            as? PagerHostingController<PageID, PageContent>,
              controllers[host.pageID] === host else {
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
        let adjacentID = activeOrder[adjacentIndex]
        guard admittedControllerIDs().contains(adjacentID) else {
            return nil
        }
        return controller(for: adjacentID)
    }

    func controller(
        for pageID: PageID
    ) -> PagerHostingController<PageID, PageContent>? {
        guard admittedControllerIDs().contains(pageID) else {
            return nil
        }
        if let cached = controllers[pageID] {
            return cached
        }
        let instanceSequence = PagerHostSequenceSource.next()
        let generation = parent.contentGeneration?(pageID) ?? 0
        let pageContent = parent.content(pageID)
        contentBuildCount += 1
        let controller = PagerHostingController(
            pageID: pageID,
            instanceSequence: instanceSequence,
            contentGeneration: generation,
            rootView: PagerHostedPage(
                controllerSequence: instanceSequence,
                content: pageContent
            )
        )
        controller.view.backgroundColor = parent.backgroundColor
        controllers[pageID] = controller
        createdControllerCount += 1
        return controller
    }

    func refreshCachedContent() {
        for (pageID, controller) in controllers {
            guard state.displayedOrder.contains(pageID) else {
                continue
            }
            let generation = parent.contentGeneration?(pageID)
            if let generation,
               generation <= controller.contentGeneration {
                continue
            }
            let pageContent = parent.content(pageID)
            contentBuildCount += 1
            controller.update(
                content: pageContent,
                generation: generation ?? controller.contentGeneration
            )
        }
    }

    func showCommittedPageIfNeeded(
        in controller: UIPageViewController,
        animated: Bool
    ) {
        guard let committedID = state.committedID else {
            if !(controller.viewControllers ?? []).isEmpty {
                replacePagerHostWithOpaqueSentinel(in: controller)
            }
            return
        }

        if let visible = controller.viewControllers?.first
            as? PagerHostingController<PageID, PageContent>,
           visible.pageID == committedID,
           controllers[committedID] === visible {
            return
        }

        let direction = navigationDirection(to: committedID)
        controller.setViewControllers(
            self.controller(for: committedID).map { [$0] } ?? [],
            direction: direction,
            animated: animated
        )
    }

    func navigationDirection(
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

    func trimControllerCache() {
        let liveIDs = admittedControllerIDs()
        let previousCount = controllers.count
        controllers = controllers.filter { liveIDs.contains($0.key) }
        evictedControllerCount += previousCount - controllers.count
    }

    func install(on controller: UIPageViewController) {
        if let installedController,
           installedController !== controller {
            invalidateActiveRendezvousWithoutPublishing(
                reason: .transitionInvalidated
            )
            invalidateSettledSnapshot()
            detach(from: installedController, clearChildren: true)
            lastEmittedSettledSnapshot = nil
        }
        if installedController !== controller {
            controllerInstallationGeneration &+= 1
        }
        installedController = controller
        controller.dataSource = self
        controller.delegate = self
        controller.view.backgroundColor = parent.backgroundColor
        configureInternalScrollViews(in: controller)
    }

    func synchronize(_ controller: UIPageViewController) {
        guard controller === installedController else {
            return
        }
        invalidateDeferredSelectionCommit()
        controller.view.backgroundColor = parent.backgroundColor
        configureInternalScrollViews(in: controller)

        if parent.contentGeneration != nil {
            _ = state.updatePages(parent.pageIDs)
            refreshCachedContent()
        } else {
            refreshCachedContent()
            _ = state.updatePages(parent.pageIDs)
        }

        _ = recordExternalSelectionChangeIfNeeded()

        guard state.transition == nil else {
            emitTransitionSnapshotIfChanged()
            return
        }

        lastEmittedTransitionSnapshot = nil

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
        scheduleSettledSnapshot()
    }

    func emitTransitionSnapshotIfChanged() {
        guard let onTransitionSnapshot = parent.onTransitionSnapshot else {
            return
        }
        let transitionSnapshot = snapshot()
        guard transitionSnapshot != lastEmittedTransitionSnapshot else {
            return
        }
        lastEmittedTransitionSnapshot = transitionSnapshot
        onTransitionSnapshot(transitionSnapshot)
    }

    func dismantle(_ controller: UIPageViewController) {
        guard controller === installedController else {
            return
        }
        invalidateDeferredSelectionCommit()
        invalidateSettledSnapshot()
        invalidateActiveRendezvousWithoutPublishing(
            reason: .transitionInvalidated
        )
        detach(from: controller, clearChildren: true)
        controllers.removeAll(keepingCapacity: false)
        lastEmittedTransitionSnapshot = nil
        installedController = nil
    }

    func detach(
        from controller: UIPageViewController,
        clearChildren: Bool
    ) {
        uninstallPagerPanObserver()
        uninstallPagerContentOffsetObserver()
        stopObservingMediaOwnership()
        installedMediaGestureOwnership?.uninstall(from: controller.view)
        installedMediaGestureOwnership = nil
        controller.delegate = nil
        controller.dataSource = nil
        if clearChildren,
           !(controller.viewControllers ?? []).isEmpty {
            replacePagerHostWithOpaqueSentinel(in: controller)
        }
    }

    func replacePagerHostWithOpaqueSentinel(
        in controller: UIPageViewController
    ) {
        guard controller.viewControllers?.first
            is PagerHostingController<PageID, PageContent> else {
            return
        }
        let sentinel = PagerTeardownViewController()
        sentinel.view.backgroundColor = parent.backgroundColor
        controller.setViewControllers(
            [sentinel],
            direction: .forward,
            animated: false
        )
    }

    func scheduleSelectionCommit(_ selection: PageID?) {
        selectionCommitTask?.cancel()
        let binding = parent.$selection
        let expectedSource = binding.wrappedValue
        selectionCommitGeneration &+= 1
        let generation = selectionCommitGeneration
        selectionCommitTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self,
                  !Task.isCancelled,
                  self.selectionCommitGeneration == generation,
                  binding.wrappedValue == expectedSource,
                  binding.wrappedValue != selection else {
                return
            }
            binding.wrappedValue = selection
            if self.selectionCommitGeneration == generation {
                self.selectionCommitTask = nil
            }
        }
    }

    func invalidateDeferredSelectionCommit() {
        selectionCommitGeneration &+= 1
        selectionCommitTask?.cancel()
        selectionCommitTask = nil
    }

    func scheduleSettledSnapshot() {
        guard parent.onSettledSnapshot != nil,
              let expectedController = installedController else {
            return
        }
        invalidateSettledSnapshot()
        settledSnapshotGeneration &+= 1
        let generation = settledSnapshotGeneration
        settledSnapshotTask = Task { @MainActor [weak self, weak expectedController] in
            await Task.yield()
            guard let self else {
                return
            }
            defer {
                if self.settledSnapshotGeneration == generation {
                    self.settledSnapshotTask = nil
                }
            }
            guard !Task.isCancelled,
                  self.settledSnapshotGeneration == generation,
                  self.installedController === expectedController,
                  self.state.transition == nil else {
                return
            }
            let snapshot = self.snapshot()
            guard snapshot != self.lastEmittedSettledSnapshot else {
                return
            }
            self.lastEmittedSettledSnapshot = snapshot
            self.parent.onSettledSnapshot?(snapshot)
        }
    }

    func invalidateSettledSnapshot() {
        settledSnapshotGeneration &+= 1
        settledSnapshotTask?.cancel()
        settledSnapshotTask = nil
    }

    func configureInternalScrollViews(
        in controller: UIPageViewController
    ) {
        if installedMediaGestureOwnership !== parent.mediaGestureOwnership {
            invalidateActiveRendezvousWithoutPublishing(
                reason: .ownershipInvalidated
            )
            stopObservingMediaOwnership()
            installedMediaGestureOwnership?.uninstall(from: controller.view)
            installedMediaGestureOwnership = parent.mediaGestureOwnership
            observeInstalledMediaOwnership()
        }
        for case let scrollView as UIScrollView in controller.view.subviews {
            scrollView.backgroundColor = parent.backgroundColor
            scrollView.isScrollEnabled = parent.pagingEnabled
            installPagerPanObserver(scrollView.panGestureRecognizer)
            installPagerContentOffsetObserver(scrollView)
            parent.mediaGestureOwnership?.install(
                on: controller.view,
                pagerPanRecognizer: scrollView.panGestureRecognizer,
                pagerCoordinatorSequence: coordinatorSequence,
                currentMediaID: { [weak self] in
                    self?.parent.selection
                }
            )
        }
    }

    func observeInstalledMediaOwnership() {
        guard let ownership = installedMediaGestureOwnership else {
            mediaOwnershipObserver = nil
            return
        }
        let observer = MediaGestureOwnershipRendezvousObserver<PageID> { [weak self] session in
            self?.mediaOwnershipSessionChanged(session)
        }
        mediaOwnershipObserver = observer
        ownership.observePagerRendezvous(with: observer)
    }

    func stopObservingMediaOwnership() {
        guard let observer = mediaOwnershipObserver else {
            return
        }
        installedMediaGestureOwnership?
            .stopObservingPagerRendezvous(with: observer)
        mediaOwnershipObserver = nil
    }
}
