import UIKit

/// Owns only local failure requirements; UIKit owns the navigation transition.
@MainActor
final class NavigationAwarePagerController: UIPageViewController {
    var isAtNavigationBoundary: (() -> Bool)?
    let navigationBack = PagerNavigationBack()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installNavigationBack()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil { installNavigationBack() }
    }

    func installNavigationBack() {
        guard isAtNavigationBoundary != nil,
              let navigationController, navigationController.viewControllers.count > 1,
              let scroll = view.subviews.compactMap({ $0 as? UIScrollView }).first else { return }
        navigationBack.install(on: view, pagerPan: scroll.panGestureRecognizer,
                               navigation: navigationController) { [weak self] in
            self?.isAtNavigationBoundary?() ?? false
        }
    }

    func removeNavigationBack() {
        navigationBack.uninstall()
        isAtNavigationBoundary = nil
    }
}

@MainActor
final class PagerNavigationBack: NSObject, UIGestureRecognizerDelegate {
    private(set) var gate: UIPanGestureRecognizer?
    private weak var navigation: UINavigationController?
    private weak var pagerPan: UIPanGestureRecognizer?
    private var isAtBoundary: () -> Bool = { false }

    func install(on view: UIView, pagerPan: UIPanGestureRecognizer,
                 navigation: UINavigationController, isAtBoundary: @escaping () -> Bool) {
        self.isAtBoundary = isAtBoundary
        guard self.navigation !== navigation || self.pagerPan !== pagerPan else { return }
        uninstall()
        self.isAtBoundary = isAtBoundary
        self.navigation = navigation
        self.pagerPan = pagerPan
        if let edge = navigation.interactivePopGestureRecognizer {
            pagerPan.require(toFail: edge)
        }
        guard #available(iOS 26.0, *), let contentPop = navigation.interactiveContentPopGestureRecognizer else { return }
        let gate = PagerContentPopGate()
        gate.contentPop = contentPop
        gate.cancelsTouchesInView = false
        gate.delegate = self
        view.addGestureRecognizer(gate)
        self.gate = gate
        // Non-first pages let this gate recognize alongside the original Pager.
        // At the boundary it fails, allowing UIKit to own content backswipe.
        contentPop.require(toFail: gate)
        pagerPan.require(toFail: contentPop)
        if let edge = navigation.interactivePopGestureRecognizer { gate.require(toFail: edge) }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === gate, let gate else { return false }
        return reservesHorizontalPaging(velocity: gate.velocity(in: gate.view))
    }

    func reservesHorizontalPaging(velocity: CGPoint) -> Bool {
        return !isAtBoundary() && abs(velocity.x) > abs(velocity.y)
    }

    func uninstall() {
        if let gate {
            gate.delegate = nil
            gate.view?.removeGestureRecognizer(gate)
        }
        gate = nil
        navigation = nil
        pagerPan = nil
        isAtBoundary = { false }
    }
}

/// A gate only for content-pop's failure requirement, never an input owner.
private final class PagerContentPopGate: UIPanGestureRecognizer {
    weak var contentPop: UIGestureRecognizer?

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        preventedGestureRecognizer === contentPop
    }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
