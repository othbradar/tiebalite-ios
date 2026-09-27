import UIKit

/// Maps the editable attachment string to the original UTF-16 wire tokens, never to spoken labels.
@MainActor
struct ComposerEditorDocument {
    let attributed: NSAttributedString

    var wireText: String {
        var text = ""
        enumerate { _, _, value in text += value }
        return text
    }

    func wireRange(from native: NSRange) -> NSRange {
        let start = wireOffset(native.location)
        return NSRange(location: start, length: wireOffset(NSMaxRange(native)) - start)
    }

    func nativeRange(from wire: NSRange) -> NSRange {
        let start = nativeOffset(wire.location, trailing: false)
        let end = nativeOffset(NSMaxRange(wire), trailing: wire.length > 0)
        return NSRange(location: start, length: max(0, end - start))
    }

    private func wireOffset(_ offset: Int) -> Int {
        var result = 0
        enumerate { native, wire, _ in
            if offset >= NSMaxRange(native) {
                result = NSMaxRange(wire)
            } else if offset > native.location {
                result = wire.location + min(offset - native.location, wire.length)
            }
        }
        return result
    }

    private func nativeOffset(_ offset: Int, trailing: Bool) -> Int {
        var result = 0
        enumerate { native, wire, _ in
            if offset >= NSMaxRange(wire) {
                result = NSMaxRange(native)
            } else if offset > wire.location {
                result = native.length == wire.length ? native.location + offset - wire.location
                    : native.location + (trailing ? native.length : 0)
            }
        }
        return result
    }

    private func enumerate(_ visit: (NSRange, NSRange, String) -> Void) {
        var wireOffset = 0
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, native, _ in
            let alternative = attrs[.attachment] is NSTextAttachment
                ? attrs[TiebaRichTextBuilder.alternativeKey] as? String : nil
            let value = alternative ?? (attributed.string as NSString).substring(with: native)
            let wire = NSRange(location: wireOffset, length: (value as NSString).length)
            visit(native, wire, value)
            wireOffset = NSMaxRange(wire)
        }
    }
}

final class ComposerEditableTextView: UITextView {
    var emoticonInputController: ComposerEmoticonInputController?
    var pasteboard: UIPasteboard = .general
    var document: ComposerEditorDocument { .init(attributed: attributedText ?? NSAttributedString()) }

    override func layoutSubviews() {
        super.layoutSubviews()
        sizeEmoticonInput()
    }

    func sizeEmoticonInput() {
        guard let inputView, let window, window.bounds.width > 0,
              inputView.frame.width != window.bounds.width else { return }
        // A custom input view belongs to the scene's keyboard, including an iPad sheet.
        // Give it the actual scene width; an unattached, zero-width grid cannot infer it.
        inputView.frame.size.width = window.bounds.width
    }

    override func copy(_ sender: Any?) {
        guard selectedRange.length > 0 else { return }
        pasteboard.string = ComposerEditorDocument(
            attributed: attributedText.attributedSubstring(from: selectedRange)).wireText
    }

    override func cut(_ sender: Any?) {
        guard isEditable, selectedRange.length > 0 else { return }
        copy(sender)
        insertText("")
    }

    override func paste(_ sender: Any?) {
        guard isEditable, let text = pasteboard.string else { return }
        insertText(text)
    }
}
