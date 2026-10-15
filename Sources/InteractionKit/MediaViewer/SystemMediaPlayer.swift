import AVKit
import SwiftUI

/// UIHostingConfiguration supports UIViewRepresentable, but rejects controller representables.
struct SystemMediaPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> InlineMediaPlayerView {
        let view = InlineMediaPlayerView()
        view.controller.player = player
        return view
    }

    func updateUIView(_ view: InlineMediaPlayerView, context: Context) {
        if view.controller.player !== player { view.controller.player = player }
    }

    static func dismantleUIView(_ view: InlineMediaPlayerView, coordinator: ()) {
        view.detachController()
        view.controller.player = nil
    }
}

final class InlineMediaPlayerView: UIView {
    let controller = AVPlayerViewController()

    init() {
        super.init(frame: .zero)
        backgroundColor = .black
        controller.allowsPictureInPicturePlayback = false
        controller.entersFullScreenWhenPlaybackBegins = false
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { detachController(); return }
        var responder: UIResponder? = superview
        while let current = responder {
            if let parent = current as? UIViewController {
                guard controller.parent !== parent else { return }
                detachController()
                parent.addChild(controller)
                addSubview(controller.view)
                controller.view.frame = bounds
                controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                controller.didMove(toParent: parent)
                return
            }
            responder = current.next
        }
    }

    func detachController() {
        guard controller.parent != nil else { return }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }
}
