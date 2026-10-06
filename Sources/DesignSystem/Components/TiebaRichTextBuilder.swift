import UIKit

@MainActor
enum TiebaRichTextBuilder {
    static let alternativeKey = NSAttributedString.Key("TiebaEmoticonAlternative")
    static let nodeIDKey = NSAttributedString.Key("TiebaSourceNodeID")

    static func image(resourceID: String) -> UIImage? {
        guard TiebaEmoticonRegistry.bundledResourceIDs.contains(resourceID) else { return nil }
        // UIImage's bundled-resource cache; no remote loader, URL construction or second image pipeline.
        return UIImage(named: "TiebaEmoticons/\(resourceID).webp", in: .main, compatibleWith: nil)
            ?? UIImage(named: "TiebaEmoticons/\(resourceID).png", in: .main, compatibleWith: nil)
    }

    static func build(runs: [TiebaRichTextRun], font: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for run in runs {
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
            switch run {
            case let .text(_, bold):
                if bold { attributes[.font] = UIFont.systemFont(ofSize: font.pointSize, weight: .bold) }
            case .mention:
                attributes[.foregroundColor] = UIColor.systemBlue
            case let .identifiedMention(nodeID, _, _):
                // TextKit marker only. The delegate resolves the original typed identity,
                // never sends this marker to an external URL handler.
                attributes[.link] = URL(string: "tiebalite-mention:\(nodeID.stableKey)")
                attributes[nodeIDKey] = nodeID.stableKey
                attributes[.foregroundColor] = UIColor.systemBlue
            case let .link(intent):
                // Only the already validated destination is attached. The delegate delivers the original intent.
                attributes[.link] = URL(string: intent.destination.absoluteString)
                attributes[nodeIDKey] = intent.sourceNodeID.stableKey
                attributes[.foregroundColor] = UIColor.systemBlue
            case let .emoticon(emoticon, alternative):
                if let image = image(resourceID: emoticon.resourceID) {
                    let attachment = NSTextAttachment()
                    let side = font.lineHeight * 0.9
                    attachment.image = image
                    attachment.bounds = CGRect(x: 0, y: (font.ascender + font.descender - side) / 2, width: side, height: side)
                    let inline = NSMutableAttributedString(attachment: attachment)
                    inline.addAttributes(attributes, range: NSRange(location: 0, length: inline.length))
                    inline.addAttribute(alternativeKey, value: alternative, range: NSRange(location: 0, length: inline.length))
                    result.append(inline)
                    continue
                }
            }
            result.append(NSAttributedString(string: run.alternativeText, attributes: attributes))
        }
        return result
    }

    static func copyText(_ text: NSAttributedString) -> String {
        var result = ""
        text.enumerateAttribute(alternativeKey, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            result += value as? String ?? (text.string as NSString).substring(with: range)
        }
        return result
    }
}
