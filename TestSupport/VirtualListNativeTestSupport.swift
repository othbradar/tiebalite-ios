#if TEST_SUPPORT
import UIKit

/// Waits for an observable native output on a display turn, with a bounded deadline.
/// A SwiftUI task starting is deliberately not considered a rendered result.
@MainActor
final class VirtualListNativeCondition: NSObject {
    private var link: CADisplayLink?
    private var continuation: CheckedContinuation<Bool, Never>?
    private var predicate: (() -> Bool)?
    private var deadline: CFTimeInterval = 0

    static func wait(until predicate: @escaping () -> Bool) async -> Bool {
        let observer = VirtualListNativeCondition()
        return await observer.observe(predicate)
    }

    private func observe(_ predicate: @escaping () -> Bool) async -> Bool {
        self.predicate = predicate
        deadline = CACurrentMediaTime() + 3
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let link = CADisplayLink(target: self, selector: #selector(tick))
            self.link = link
            link.add(to: .main, forMode: .common)
        }
    }

    @objc private func tick() {
        let satisfied = predicate?() == true
        guard satisfied || CACurrentMediaTime() >= deadline else { return }
        link?.invalidate()
        link = nil
        predicate = nil
        let waiting = continuation
        continuation = nil
        waiting?.resume(returning: satisfied)
    }
}

@MainActor
func virtualListVisibleLabels(in view: UIView) -> [UILabel] {
    guard let window = view.window, window.windowScene != nil else { return [] }
    var visibleRect = view.convert(view.bounds, to: window).intersection(window.bounds)
    var ancestor: UIView? = view
    while let current = ancestor {
        guard !current.isHidden, current.alpha > 0.01 else { return [] }
        if current.clipsToBounds {
            visibleRect = visibleRect.intersection(current.convert(current.bounds, to: window))
        }
        ancestor = current.superview
    }
    guard !visibleRect.isNull, !visibleRect.isEmpty else { return [] }
    let ownLabel = (view as? UILabel).map { [$0] } ?? []
    return ownLabel + view.subviews.flatMap(virtualListVisibleLabels)
}
#endif
