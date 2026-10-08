import Foundation

/// Inputs to 22.11.1's reply-compose submit plugin, captured for one submission.
/// Editor attachment conversion and runtime choice of legacy/compose UI happen
/// upstream. This value never selects that experiment or replays verification.
struct NativeReplyComposeContent: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let supportsServerText: Bool
    let serverText: String?
    let visibleText: String?
    let isFloor: Bool
    let recipientPrompt: String?
    let portrait: String?
    let displayName: String?

    var description: String { "NativeReplyComposeContent(redacted)" }
    var debugDescription: String { description }

    /// TBCReplyComposeSubmitPlugin.generatePbReplyContent, 0x1023deab0.
    /// No trimming, Unicode normalization, token replacement or legacy 140-unit
    /// truncation belongs to this method. Preserve the captured editor values.
    func preparedText() -> String {
        let text: String
        if supportsServerText, let serverText, !serverText.isEmpty {
            text = serverText
        } else {
            text = visibleText ?? ""
        }
        guard isFloor, let recipientPrompt, !recipientPrompt.isEmpty,
              NSPredicate(format: "SELF MATCHES %@", #"回复 [\s\S]* :"#).evaluate(with: recipientPrompt) else {
            return text
        }
        return "回复 #(reply, \(portrait ?? ""), \(displayName ?? "")) :" + text
    }
}
