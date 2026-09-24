import SwiftUI
import UIKit

/// One native editor displays attachments; the draft retains the original transport tokens.
struct ComposerTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var focused: Bool
    let enabled: Bool
    var showsEmoticons = false
    var insertEmoticon: (TiebaEmoticon) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ComposerEditableTextView {
        let view = ComposerEditableTextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.accessibilityLabel = "正文"
        view.accessibilityIdentifier = "composer.body"
        view.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        view.keyboardDismissMode = .interactive
        return view
    }
    func updateUIView(_ view: ComposerEditableTextView, context: Context) {
        context.coordinator.parent = self
        view.isEditable = enabled
        context.coordinator.synchronizeInput(in: view)
        if view.markedTextRange == nil {
            context.coordinator.render(text, selection: selection, in: view)
        }
        if focused && !view.isFirstResponder { view.becomeFirstResponder() }
        if !focused && view.isFirstResponder { view.resignFirstResponder() }
    }
    static func dismantleUIView(_ view: ComposerEditableTextView, coordinator: Coordinator) {
        view.delegate = nil
        view.resignFirstResponder()
        view.inputView = nil
        view.emoticonInputController = nil
        coordinator.tearDown()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerTextEditor
        var isUpdating = false
        private var renderedWire: String?
        private var renderedFont: UIFont?
        private var inputController: ComposerEmoticonInputController?
        init(_ parent: ComposerTextEditor) { self.parent = parent }

        func synchronizeInput(in view: ComposerEditableTextView) {
            if parent.showsEmoticons, inputController == nil {
                let controller = ComposerEmoticonInputController()
                controller.insert = { [weak self] emoticon in
                    guard let self, self.parent.enabled else { return }
                    self.parent.insertEmoticon(emoticon)
                }
                inputController = controller
            }
            let next = parent.showsEmoticons ? inputController : nil
            guard view.emoticonInputController !== next else { return }
            view.emoticonInputController = next
            next?.loadViewIfNeeded()
            view.inputView = next?.inputView
            view.sizeEmoticonInput()
            if view.isFirstResponder { view.reloadInputViews() }
        }

        func tearDown() {
            inputController?.tearDown()
            inputController = nil
        }

        func render(_ wire: String, selection: NSRange, in view: ComposerEditableTextView) {
            let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: view.traitCollection)
            isUpdating = true
            defer { isUpdating = false }
            if renderedWire != wire || renderedFont != font {
                let content = TiebaRichTextBuilder.build(runs: TiebaRichText.parse(wire), font: font)
                if !view.attributedText.isEqual(to: content) { view.textStorage.setAttributedString(content) }
                renderedWire = wire
                renderedFont = font
            }
            let native = view.document.nativeRange(from: selection)
            if view.selectedRange != native { view.selectedRange = native }
            resetTypingAttributes(view)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating, let view = textView as? ComposerEditableTextView else { return }
            let wire = view.document.wireText
            let selection = view.document.wireRange(from: view.selectedRange)
            if view.markedTextRange == nil { render(wire, selection: selection, in: view) }
            parent.selection = selection
            parent.text = wire
        }
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdating, textView.markedTextRange == nil, let view = textView as? ComposerEditableTextView else { return }
            parent.selection = view.document.wireRange(from: view.selectedRange)
            resetTypingAttributes(view)
        }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            resetTypingAttributes(textView)
            return true
        }
        private func resetTypingAttributes(_ view: UITextView) {
            view.typingAttributes = [.font: UIFont.preferredFont(forTextStyle: .body, compatibleWith: view.traitCollection),
                                     .foregroundColor: UIColor.label]
        }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.focused = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.focused = false }
    }
}
