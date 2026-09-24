import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct R10ComposerEditorTests {
    @Test func inputModeKeepsOneControllerSelectionAndCurrentCallback() throws {
        var originalCalls = 0
        var currentCalls = 0
        var wrapper = ComposerTextEditor(text: .constant("甲#(笑眼)乙"),
                                         selection: .constant(NSRange(location: 6, length: 0)),
                                         focused: .constant(false), enabled: true, showsEmoticons: true,
                                         insertEmoticon: { _ in originalCalls += 1 })
        let coordinator = wrapper.makeCoordinator()
        let view = ComposerEditableTextView()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.addSubview(view)
        coordinator.render("甲#(笑眼)乙", selection: NSRange(location: 6, length: 0), in: view)
        coordinator.synchronizeInput(in: view)
        let controller = try #require(view.emoticonInputController)
        controller.loadViewIfNeeded()
        #expect(controller.children.count == 1)
        #expect(controller.inputView?.frame.width == 402)
        window.frame.size.width = 874
        view.setNeedsLayout()
        view.layoutIfNeeded()
        #expect(controller.inputView?.frame.width == 874)
        let measured = controller.view.systemLayoutSizeFitting(CGSize(width: 402, height: 0),
                                                               withHorizontalFittingPriority: .required,
                                                               verticalFittingPriority: .fittingSizeLevel)
        #expect(measured == CGSize(width: 402, height: 216))
        for _ in 1...3 {
            wrapper.showsEmoticons = false
            coordinator.parent = wrapper
            coordinator.synchronizeInput(in: view)
            #expect(view.inputView == nil)
            wrapper.showsEmoticons = true
            wrapper.insertEmoticon = { _ in currentCalls += 1 }
            coordinator.parent = wrapper
            coordinator.synchronizeInput(in: view)
            #expect(view.emoticonInputController === controller)
            #expect(view.inputView === controller.inputView)
            #expect(view.selectedRange == NSRange(location: 2, length: 0))
            controller.insert?(try #require(TiebaEmoticonRegistry.named("笑眼")))
        }
        #expect(originalCalls == 0 && currentCalls == 3)
        coordinator.parent = ComposerTextEditor(text: .constant(""), selection: .constant(NSRange()),
                                                focused: .constant(false), enabled: false, showsEmoticons: true,
                                                insertEmoticon: { _ in currentCalls += 1 })
        controller.insert?(try #require(TiebaEmoticonRegistry.named("笑眼")))
        #expect(currentCalls == 3)
        ComposerTextEditor.dismantleUIView(view, coordinator: coordinator)
        #expect(view.inputView == nil && view.emoticonInputController == nil)
        #expect(controller.insert == nil && controller.children.isEmpty)
    }

    @Test func cursorDeletionCopyAndRepeatedTokensRetainWireText() {
        var text = "甲😀#(笑眼)#(笑眼)乙"
        var selection = NSRange(location: 8, length: 0)
        var focused = false
        let wrapper = ComposerTextEditor(text: Binding(get: { text }, set: { text = $0 }),
                                         selection: Binding(get: { selection }, set: { selection = $0 }),
                                         focused: Binding(get: { focused }, set: { focused = $0 }), enabled: true)
        let coordinator = wrapper.makeCoordinator()
        let view = ComposerEditableTextView()
        view.delegate = coordinator
        coordinator.render(text, selection: selection, in: view)
        #expect(view.selectedRange == NSRange(location: 4, length: 0))
        #expect(view.document.wireText == text)
        view.insertText("中")
        #expect(text == "甲😀#(笑眼)中#(笑眼)乙")
        view.deleteBackward()
        view.deleteBackward()
        #expect(text == "甲😀#(笑眼)乙")
        #expect(selection == NSRange(location: 3, length: 0))
        view.selectedRange = NSRange(location: 3, length: 1)
        #expect(selection == NSRange(location: 3, length: 5))
        let pasteboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = pasteboard }
        view.copy(nil)
        #expect(UIPasteboard.general.string == "#(笑眼)")
        view.cut(nil)
        #expect(text == "甲😀乙")
        view.paste(nil)
        #expect(text == "甲😀#(笑眼)乙")
        #expect(view.attributedText.attribute(.attachment, at: 3, effectiveRange: nil) is NSTextAttachment)
        let storage = view.textStorage
        coordinator.render(text, selection: selection, in: view)
        #expect(view.textStorage === storage)
        #expect(view.selectedRange == NSRange(location: 4, length: 0))
    }

    @Test(arguments: [1, 2, 3])
    func selectedEmoticonsAppearInsideEditableBody(_ repetition: Int) throws {
        let wire = "甲😀#(笑眼)乙#(滑稽)#(捂嘴笑)\n#(未知表情)"
        let host = UIHostingController(rootView: ComposerTextEditor(
            text: .constant(wire), selection: .constant(NSRange(location: 9, length: 0)),
            focused: .constant(false), enabled: true))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 400))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()
        let editor = try #require(findEditor(host.view), "repeat \(repetition)")
        var attachments = 0
        let range = NSRange(location: 0, length: editor.attributedText.length)
        editor.attributedText.enumerateAttribute(.attachment, in: range) { value, _, _ in
            if value is NSTextAttachment { attachments += 1 }
        }
        #expect(attachments == 3)
        #expect(TiebaRichTextBuilder.copyText(editor.attributedText) == wire)
        #expect(editor.text == "甲😀\u{FFFC}乙\u{FFFC}\u{FFFC}\n#(未知表情)")
        #expect(editor.isEditable && editor.isSelectable)
    }

    private func findEditor(_ view: UIView) -> UITextView? {
        if let editor = view as? UITextView { return editor }
        return view.subviews.lazy.compactMap { findEditor($0) }.first
    }
}
