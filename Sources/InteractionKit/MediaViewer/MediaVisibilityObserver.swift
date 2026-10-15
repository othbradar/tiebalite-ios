import SwiftUI
import UIKit

/// Watches actual clipping in UIKit-hosted rows too; SwiftUI ScrollView visibility alone does not cover UITableView.
struct MediaVisibilityObserver: UIViewRepresentable {
    var minimumVisibleFraction: CGFloat = 0
    let onChange: (Bool) -> Void

    func makeUIView(context: Context) -> MediaVisibilityProbe {
        let view = MediaVisibilityProbe()
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        view.onChange = onChange
        view.minimumVisibleFraction = minimumVisibleFraction
        return view
    }

    func updateUIView(_ view: MediaVisibilityProbe, context: Context) {
        view.onChange = onChange
        view.minimumVisibleFraction = minimumVisibleFraction
    }

    static func dismantleUIView(_ view: MediaVisibilityProbe, coordinator: ()) {
        MediaVisibilityHub.shared.remove(view)
        view.onChange = nil
    }
}

final class MediaVisibilityProbe: UIView {
    var onChange: ((Bool) -> Void)?
    var minimumVisibleFraction: CGFloat = 0
    private var lastValue: Bool?
    private var visibilityUpdate: Task<Void, Never>?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { MediaVisibilityHub.shared.add(self) } else { MediaVisibilityHub.shared.remove(self) }
        visibilityUpdate?.cancel()
        // A detached, retained hosting cell must stop too. Deliver after UIKit's hierarchy update,
        // not synchronously inside SwiftUI updateUIView and not after an arbitrary delay.
        visibilityUpdate = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            self?.sample()
        }
    }

    func sample() {
        var visible = false
        if let window, !bounds.isEmpty {
            let mediaRect = convert(bounds, to: window)
            var viewport = window.bounds
            var ancestor: UIView? = self
            while let view = ancestor {
                if view.isHidden || view.alpha < 0.01 { viewport = .null; break }
                if view !== self, view.clipsToBounds { viewport = viewport.intersection(view.convert(view.bounds, to: window)) }
                ancestor = view.superview
            }
            let rect = mediaRect.intersection(viewport)
            let area = min(mediaRect.width, viewport.width) * min(mediaRect.height, viewport.height)
            visible = !rect.isNull && rect.width > 1 && rect.height > 1 && area > 0
                && rect.width * rect.height / area >= minimumVisibleFraction
        }
        if lastValue != visible { lastValue = visible; onChange?(visible) }
    }
}

@MainActor
private final class MediaVisibilityHub: NSObject {
    static let shared = MediaVisibilityHub()
    private let probes = NSHashTable<MediaVisibilityProbe>.weakObjects()
    private var displayLink: CADisplayLink?

    func add(_ probe: MediaVisibilityProbe) {
        probes.add(probe)
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(sample))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 5, maximum: 10, preferred: 10)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func remove(_ probe: MediaVisibilityProbe) {
        probes.remove(probe)
        if probes.allObjects.isEmpty { displayLink?.invalidate(); displayLink = nil }
    }

    @objc private func sample() {
        let views = probes.allObjects
        if views.isEmpty { displayLink?.invalidate(); displayLink = nil }
        for view in views { view.sample() }
    }
}
