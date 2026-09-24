import SwiftUI
import UIKit

/// The same responder owns both the system keyboard and this input view.
/// UIKit supplies its width/placement; the hosted grid only lays out inside that viewport.
final class ComposerEmoticonInputController: UIInputViewController {
    var insert: ((TiebaEmoticon) -> Void)?
    private var host: UIHostingController<ComposerEmoticonPanel>?

    override func loadView() {
        let input = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: 216), inputViewStyle: .keyboard)
        // The responder supplies the scene width; the grid never determines its input viewport.
        input.autoresizingMask = [.flexibleWidth]
        input.clipsToBounds = true
        input.backgroundColor = .secondarySystemBackground
        inputView = input

        let host = UIHostingController(rootView: ComposerEmoticonPanel { [weak self] in self?.insert?($0) })
        // This view IS the input region. Avoiding the keyboard here would avoid itself.
        host.safeAreaRegions = .container
        self.host = host
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        input.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: input.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: input.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: input.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: input.bottomAnchor),
            input.heightAnchor.constraint(equalToConstant: 216)
        ])
        host.didMove(toParent: self)
    }

    func tearDown() {
        insert = nil
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()
        host = nil
    }
}
