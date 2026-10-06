import Foundation

// A compact, immutable inline projection. It never changes source node/row identities.
enum TiebaRichTextRun: Equatable, Sendable {
    case text(String, bold: Bool = false)
    case mention(String)
    case identifiedMention(ThreadContentNodeID, userID: Int64, label: String)
    case link(ExternalLinkIntent)
    case emoticon(TiebaEmoticon, alternative: String)

    var alternativeText: String {
        switch self {
        case let .text(text, _), let .mention(text): text
        case let .link(intent): intent.label.isEmpty ? "打开链接" : intent.label
        case let .identifiedMention(_, _, label): label
        case let .emoticon(_, alternative): alternative
        }
    }

    var spokenText: String {
        if case let .emoticon(emoticon, _) = self { return emoticon.name + "表情" }
        return alternativeText
    }

    var emoticonID: String? {
        if case let .emoticon(emoticon, _) = self { return emoticon.resourceID }
        return nil
    }

    var linkIntent: ExternalLinkIntent? {
        if case let .link(intent) = self { return intent }
        return nil
    }

    var profileIntent: (nodeID: ThreadContentNodeID, route: UserProfileRoute)? {
        if case let .identifiedMention(nodeID, userID, label) = self,
           let route = UserProfileRoute(userID: userID, fallbackDisplayName: label) { return (nodeID, route) }
        return nil
    }
}

enum TiebaRichText {
    // Parenthesized Android syntax plus the explicitly requested bare-name compatibility.
    // Match the whole bare token so #滑稽话题 cannot be consumed as #滑稽 + 话题.
    private static let tokens = try? NSRegularExpression(
        pattern: #"#\(([\p{L}\p{N}_~]+)\)|\(#([\p{L}\p{N}_~]+)\)|(?<![a-zA-Z0-9_/:=.?&\\])#([\p{L}\p{N}_~]+)#?"#
    )

    static func parse(_ text: String, bold: Bool = false) -> [TiebaRichTextRun] {
        guard !text.isEmpty else { return [] }
        guard let tokens else { return [.text(text, bold: bold)] }
        let original = text as NSString
        var result: [TiebaRichTextRun] = []
        var end = 0
        for match in tokens.matches(in: text, range: NSRange(location: 0, length: original.length)) {
            let groups = (1...3).filter { match.range(at: $0).location != NSNotFound }
            guard let group = groups.first else { continue }
            let literal = original.substring(with: match.range)
            let name = original.substring(with: match.range(at: group))
            guard !(group == 3 && literal.hasSuffix("#")),
                  let emoticon = TiebaEmoticonRegistry.named(name, webSyntax: group == 2) else { continue }
            if match.range.location > end {
                result.append(.text(original.substring(with: NSRange(location: end, length: match.range.location - end)), bold: bold))
            }
            result.append(.emoticon(emoticon, alternative: literal))
            end = NSMaxRange(match.range)
        }
        if end < original.length {
            result.append(.text(original.substring(from: end), bold: bold))
        }
        return result
    }

    static func runs(nodes: [ThreadContentNode]) -> [TiebaRichTextRun] {
        nodes.flatMap { node -> [TiebaRichTextRun] in
            switch node.payload {
            case let .text(text): parse(text.value)
            case let .emoji(emoji):
                if let value = TiebaEmoticonRegistry.resolve(registryKey: emoji.registryKey, name: emoji.code) {
                    [.emoticon(value, alternative: emoji.fallbackText)]
                } else { [.text(emoji.fallbackText)] }
            case let .link(link):
                if let intent = link.intent { [.link(intent)] } else { [.text(link.label.isEmpty ? "链接不可用" : link.label)] }
            case let .mention(mention):
                if let userID = mention.userID,
                   let route = UserProfileRoute(userID: userID, fallbackDisplayName: mention.label) {
                    [.identifiedMention(node.id, userID: route.userID.rawValue, label: mention.label.isEmpty ? "提及用户" : mention.label)]
                } else { [.mention(mention.label.isEmpty ? "提及用户" : mention.label)] }
            case .image: [.text("[图片]")]
            case .video: [.text("[视频]")]
            case .voice: [.text("[语音]")]
            case .unsupported: [.text("[暂不支持的内容]")]
            }
        }
    }
}
