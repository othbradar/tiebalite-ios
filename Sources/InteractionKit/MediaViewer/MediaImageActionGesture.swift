import UIKit

/// A stationary, one-finger image action. UIKit's pan and pinch keep their own delegates.
@MainActor
final class MediaImageActionGesture: NSObject, UIGestureRecognizerDelegate {
    private weak var scrollView: MediaZoomScrollView?
    private let action: () -> Void
    private(set) var recognizer: UILongPressGestureRecognizer?

    init(on scrollView: MediaZoomScrollView, action: @escaping () -> Void) {
        self.scrollView = scrollView
        self.action = action
        super.init()
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.numberOfTouchesRequired = 1
        press.delegate = self
        scrollView.addGestureRecognizer(press)
        recognizer = press
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let scrollView, scrollView.capability.atMinimumZoom else { return false }
        let point = gestureRecognizer.location(in: scrollView.mediaImageView)
        return scrollView.mediaImageView.bounds.contains(point)
    }

    func dismantle() {
        guard let recognizer else { return }
        recognizer.delegate = nil
        scrollView?.removeGestureRecognizer(recognizer)
        self.recognizer = nil
        scrollView = nil
    }

    @objc private func pressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, scrollView?.capability.atMinimumZoom == true else { return }
        action()
    }
}
