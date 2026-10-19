import UIKit

/// Opt-in ordinary-text action. Native links, text selection and ancestor scrolling retain ownership.
@MainActor
final class TiebaTextBodyTap: NSObject, UIGestureRecognizerDelegate {
    private weak var textView: TiebaSelectableTextView?
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(activate))

    func update(in view: TiebaSelectableTextView, enabled: Bool) {
        guard enabled || tap.view != nil else { return }
        textView = view
        if tap.view == nil {
            tap.cancelsTouchesInView = false
            tap.delegate = self
            view.addGestureRecognizer(tap)
        }
        tap.isEnabled = enabled
        // A double tap or long press belongs to UIKit's selection/copy interaction.
        for recognizer in view.gestureRecognizers ?? [] where recognizer !== tap {
            if recognizer is UILongPressGestureRecognizer
                || ((recognizer as? UITapGestureRecognizer)?.numberOfTapsRequired ?? 0) > 1 {
                tap.require(toFail: recognizer)
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let textView else { return false }
        return acceptsBodyTap(at: touch.location(in: textView))
    }

    func acceptsBodyTap(at point: CGPoint) -> Bool {
        guard let textView, textView.onBodyTap != nil, textView.selectedRange.length == 0 else { return false }
        guard let range = textView.characterRange(at: point) else { return true }
        let index = textView.offset(from: textView.beginningOfDocument, to: range.start)
        guard index >= 0, index < textView.attributedText.length else { return true }
        return textView.attributedText.attribute(.link, at: index, effectiveRange: nil) == nil
    }

    @objc private func activate() {
        guard tap.state == .ended, let textView, acceptsBodyTap(at: tap.location(in: textView)) else { return }
        textView.onBodyTap?()
    }
}
