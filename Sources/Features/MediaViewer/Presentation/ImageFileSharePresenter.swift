import SwiftUI
import UIKit

/// A non-interactive presenter anchored inside the Viewer independently of its chrome/menu, including on iPad.
struct ImageFileSharePresenter: UIViewControllerRepresentable {
    let file: ImageExportFile?
    let began: () -> Void
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> ImageShareAnchorController { ImageShareAnchorController() }

    func updateUIViewController(_ controller: ImageShareAnchorController, context: Context) {
        controller.file = file
        controller.began = began
        controller.completion = completion
        controller.presentIfReady()
    }

    static func dismantleUIViewController(_ controller: ImageShareAnchorController, coordinator: Void) {
        if controller.presentedViewController != nil {
            controller.dismiss(animated: false) { controller.finish(completed: false) }
        } else {
            controller.finish(completed: false)
        }
    }
}

@MainActor
final class ImageShareAnchorController: UIViewController, UIAdaptivePresentationControllerDelegate {
    var file: ImageExportFile?
    var began: (() -> Void)?
    var completion: ((Bool) -> Void)?
    private var activeURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentIfReady()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        presentIfReady()
    }

    func presentIfReady() {
        guard let file, activeURL == nil, presentedViewController == nil,
              viewIfLoaded?.window != nil, !view.bounds.isEmpty else { return }
        activeURL = file.url
        began?()
        let activity = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        // Photos writes have a single explicit add-only path and precise completion/error reporting.
        activity.excludedActivityTypes = [.saveToCameraRoll]
        activity.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            self?.finish(completed: completed)
        }
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = [.up, .down]
        }
        activity.presentationController?.delegate = self
        present(activity, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish(completed: false)
    }

    func finish(completed: Bool) {
        guard activeURL != nil || file != nil else { return }
        activeURL = nil
        file = nil
        completion?(completed)
    }
}
