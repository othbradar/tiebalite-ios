import SwiftUI
import UIKit

/// One non-scrolling inline surface for body, previews and summaries. Parent lists own scrolling.
struct TiebaRichTextView: View {
    let runs: [TiebaRichTextRun]
    let lineLimit: Int
    let interactive: Bool
    let onOpenExternalLink: (ExternalLinkIntent) -> Void
    @ScaledMetric(relativeTo: .body) private var pointSize: CGFloat = 17

    init(
        runs: [TiebaRichTextRun], fontSize: CGFloat = 17, lineLimit: Int = 0, interactive: Bool = true,
        onOpenExternalLink: @escaping (ExternalLinkIntent) -> Void = { _ in }
    ) {
        self.runs = runs
        self.lineLimit = lineLimit
        self.interactive = interactive
        self.onOpenExternalLink = onOpenExternalLink
        _pointSize = ScaledMetric(wrappedValue: fontSize, relativeTo: .body)
    }

    var body: some View {
        TiebaRichTextRepresentable(runs: runs, pointSize: pointSize, lineLimit: lineLimit,
                                   interactive: interactive, onOpenExternalLink: onOpenExternalLink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(interactive)
    }
}

private struct TiebaRichTextRepresentable: UIViewRepresentable {
    let runs: [TiebaRichTextRun]
    let pointSize: CGFloat
    let lineLimit: Int
    let interactive: Bool
    let onOpenExternalLink: (ExternalLinkIntent) -> Void

    func makeUIView(context: Context) -> TiebaSelectableTextView { TiebaSelectableTextView() }

    func updateUIView(_ uiView: TiebaSelectableTextView, context: Context) {
        uiView.onOpenExternalLink = onOpenExternalLink
        uiView.apply(runs: runs, pointSize: pointSize, lineLimit: lineLimit, interactive: interactive)
    }

    static func dismantleUIView(_ uiView: TiebaSelectableTextView, coordinator: ()) {
        uiView.delegate = nil
        uiView.onOpenExternalLink = { _ in }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TiebaSelectableTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }
}

@MainActor
final class TiebaSelectableTextView: UITextView, UITextViewDelegate {
    var onOpenExternalLink: (ExternalLinkIntent) -> Void = { _ in }
    private var currentRuns: [TiebaRichTextRun] = []
    private var currentSize: CGFloat = 0

    init() {
        super.init(frame: .zero, textContainer: nil)
        isScrollEnabled = false
        isEditable = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byTruncatingTail
        contentInset = .zero
        adjustsFontForContentSizeCategory = false // SwiftUI ScaledMetric owns the selected reading size.
        dataDetectorTypes = []
        delegate = self
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        linkTextAttributes = [.foregroundColor: UIColor.systemBlue]
    }

    required init?(coder: NSCoder) { nil }

    func apply(runs: [TiebaRichTextRun], pointSize: CGFloat, lineLimit: Int, interactive: Bool) {
        isSelectable = interactive
        isUserInteractionEnabled = interactive
        if textContainer.maximumNumberOfLines != lineLimit { textContainer.maximumNumberOfLines = lineLimit }
        guard runs != currentRuns || pointSize != currentSize else { return }
        currentRuns = runs
        currentSize = pointSize
        attributedText = TiebaRichTextBuilder.build(runs: runs, font: .systemFont(ofSize: pointSize))
        accessibilityLabel = runs.map(\.spokenText).joined()
    }

    override func copy(_ sender: Any?) {
        guard selectedRange.length > 0, NSMaxRange(selectedRange) <= attributedText.length else { return }
        UIPasteboard.general.string = TiebaRichTextBuilder.copyText(attributedText.attributedSubstring(from: selectedRange))
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard textItem.range.location < attributedText.length,
              let key = attributedText.attribute(TiebaRichTextBuilder.nodeIDKey, at: textItem.range.location,
                                                 effectiveRange: nil) as? String,
              let intent = currentRuns.compactMap(\.linkIntent).first(where: { $0.sourceNodeID.stableKey == key }) else {
            return nil
        }

        // UIKit may query this action without activating it (selection, scrolling, accessibility).
        // Only the action handler delivers the intent; updateUIView supplies the current callback.
        return UIAction { [weak self] _ in
            self?.onOpenExternalLink(intent)
        }
    }

    func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem,
                  defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
        return nil
    }
}
