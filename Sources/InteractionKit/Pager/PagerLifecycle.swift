import SwiftUI
import UIKit

#if DEBUG
struct PagerGeometrySnapshot<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let pageID: PageID
    let controllerSequence: UInt64
    let stateGeneration: UInt64
    let rootFrame: CGRect
    let pagerBounds: CGRect
    let coversPagerBounds: Bool
    let hasOpaqueBackground: Bool

    static func == (
        lhs: PagerGeometrySnapshot,
        rhs: PagerGeometrySnapshot
    ) -> Bool {
        guard lhs.pageID == rhs.pageID,
              lhs.controllerSequence == rhs.controllerSequence,
              lhs.stateGeneration == rhs.stateGeneration,
              lhs.pagerBounds == rhs.pagerBounds,
              lhs.coversPagerBounds == rhs.coversPagerBounds,
              lhs.hasOpaqueBackground == rhs.hasOpaqueBackground else {
            return false
        }
        if lhs.coversPagerBounds {
            return true
        }
        return lhs.rootFrame == rhs.rootFrame
    }
}
#endif

#if DEBUG
struct PagerContainerSnapshot<PageID>: Equatable, Sendable
where PageID: Hashable & Sendable {
    let committedID: PageID?
    let liveIDs: [PageID]
    let resolvedTransitionCount: Int
    let controllerCount: Int
    let coordinatorSequence: UInt64
    let cachedControllerSequences: [PageID: UInt64]
    let visiblePageID: PageID?
    let visibleControllerSequence: UInt64?
    let createdControllerCount: Int
    let contentBuildCount: Int
    let evictedControllerCount: Int
    let orphanChildControllerCount: Int
    let activeCallbackDepth: Int
    let maximumActiveCallbackDepth: Int
    let rejectedOverlappingTransitionCount: Int
    let teardownSentinelVisible: Bool
    let geometry: PagerGeometrySnapshot<PageID>?
}

extension PagerContainer.Coordinator {
    func cachedController(for pageID: PageID) -> UIViewController? {
        controllers[pageID]
    }

    func diagnosticSnapshot() -> PagerContainerSnapshot<PageID> {
        snapshot()
    }

    func snapshot() -> PagerContainerSnapshot<PageID> {
        let visible = installedController?.viewControllers?.first
            as? PagerHostingController<PageID, PageContent>
        return PagerContainerSnapshot(
            committedID: state.committedID,
            liveIDs: PagerCachePolicy.liveIDs(
                pageIDs: state.displayedOrder,
                committedID: state.committedID,
                transition: state.transition
            ),
            resolvedTransitionCount: state.resolvedTransitionCount,
            controllerCount: controllers.count,
            coordinatorSequence: coordinatorSequence,
            cachedControllerSequences: controllers.mapValues(
                \.instanceSequence
            ),
            visiblePageID: visible?.pageID,
            visibleControllerSequence: visible?.instanceSequence,
            createdControllerCount: createdControllerCount,
            contentBuildCount: contentBuildCount,
            evictedControllerCount: evictedControllerCount,
            orphanChildControllerCount: orphanChildControllerCount(),
            activeCallbackDepth: pendingCallbackContext == nil ? 0 : 1,
            maximumActiveCallbackDepth: maximumActiveCallbackDepth,
            rejectedOverlappingTransitionCount:
                rejectedOverlappingTransitionCount,
            teardownSentinelVisible: installedController?
                .viewControllers?.first is PagerTeardownViewController,
            geometry: geometrySnapshot(visible: visible)
        )
    }

    private func orphanChildControllerCount() -> Int {
        guard let installedController else {
            return 0
        }
        return installedController.children.reduce(into: 0) { count, child in
            guard let host = child
                as? PagerHostingController<PageID, PageContent>,
                  controllers[host.pageID] !== host else {
                return
            }
            count += 1
        }
    }

    private func geometrySnapshot(
        visible: PagerHostingController<PageID, PageContent>?
    ) -> PagerGeometrySnapshot<PageID>? {
        guard let installedController,
              let visible else {
            return nil
        }
        installedController.view.layoutIfNeeded()
        visible.view.layoutIfNeeded()
        let pagerBounds = installedController.view.bounds.standardized
        let rootFrame = visible.view.convert(
            visible.view.bounds,
            to: installedController.view
        ).standardized
        let tolerance = 1.0
        let coversPagerBounds =
            abs(rootFrame.minX - pagerBounds.minX) <= tolerance
            && abs(rootFrame.minY - pagerBounds.minY) <= tolerance
            && abs(rootFrame.width - pagerBounds.width) <= tolerance
            && abs(rootFrame.height - pagerBounds.height) <= tolerance
        let containerAlpha = installedController.view.backgroundColor?
            .cgColor.alpha ?? 0
        let rootAlpha = visible.view.backgroundColor?.cgColor.alpha ?? 0
        return PagerGeometrySnapshot(
            pageID: visible.pageID,
            controllerSequence: visible.instanceSequence,
            stateGeneration: visible.contentGeneration,
            rootFrame: rootFrame,
            pagerBounds: pagerBounds,
            coversPagerBounds: coversPagerBounds,
            hasOpaqueBackground: containerAlpha >= 0.999
                && rootAlpha >= 0.999
        )
    }
}
#endif

extension PagerContainer.Coordinator {
    func admittedControllerIDs() -> Set<PageID> {
        Set(
            PagerCachePolicy.liveIDs(
                pageIDs: state.displayedOrder,
                committedID: state.committedID,
                transition: state.transition
            )
        )
    }
}

@MainActor
enum PagerCoordinatorSequenceSource {
    private static var nextSequence: UInt64 = 1

    static func next() -> UInt64 {
        defer { nextSequence &+= 1 }
        return nextSequence
    }
}

@MainActor
enum PagerHostSequenceSource {
    private static var nextSequence: UInt64 = 1

    static func next() -> UInt64 {
        defer { nextSequence &+= 1 }
        return nextSequence
    }
}

@MainActor
final class PagerTeardownViewController: UIViewController {}

#if DEBUG
private struct DebugPagerControllerSequenceKey: EnvironmentKey {
    static let defaultValue: UInt64 = 0
}

extension EnvironmentValues {
    var debugPagerControllerSequence: UInt64 {
        get { self[DebugPagerControllerSequenceKey.self] }
        set { self[DebugPagerControllerSequenceKey.self] = newValue }
    }
}
#endif

struct PagerHostedPage<Content: View>: View {
    let controllerSequence: UInt64
    let content: Content

    @ViewBuilder
    var body: some View {
#if DEBUG
        content.environment(
            \.debugPagerControllerSequence,
            controllerSequence
        )
#else
        content
#endif
    }
}

@MainActor
final class PagerHostingController<PageID, Content>:
    UIHostingController<PagerHostedPage<Content>>
where PageID: Hashable & Sendable, Content: View {
    let pageID: PageID
    let instanceSequence: UInt64
    private(set) var contentGeneration: UInt64

    init(
        pageID: PageID,
        instanceSequence: UInt64,
        contentGeneration: UInt64,
        rootView: PagerHostedPage<Content>
    ) {
        self.pageID = pageID
        self.instanceSequence = instanceSequence
        self.contentGeneration = contentGeneration
        super.init(rootView: rootView)
    }

    func update(content: Content, generation: UInt64) {
        contentGeneration = generation
        rootView = PagerHostedPage(
            controllerSequence: instanceSequence,
            content: content
        )
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder: NSCoder) {
        nil
    }
}
