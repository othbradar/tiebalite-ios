import Foundation

enum ThreadContentBlock: Identifiable, Equatable, Sendable {
    case node(ThreadContentNode)
    case images([ThreadContentNode])
    case richText([ThreadContentNode])

    var id: ThreadContentNodeID? {
        switch self {
        case let .node(node): node.id
        case let .images(nodes), let .richText(nodes): nodes.first?.id
        }
    }

    static func make(_ nodes: [ThreadContentNode]) -> [Self] {
        #if UITESTING
        ScrollWorkMetrics.count("text.blocks")
        #endif
        var blocks: [Self] = []
        var images: [ThreadContentNode] = []
        var inline: [ThreadContentNode] = []
        for node in nodes {
            switch node.payload {
            case .image:
                if !inline.isEmpty { blocks.append(.richText(inline)); inline = [] }
                images.append(node)
            case .text, .emoji, .link, .mention:
                if !images.isEmpty { blocks.append(.images(images)); images = [] }
                inline.append(node)
            default:
                if !inline.isEmpty { blocks.append(.richText(inline)); inline = [] }
                if !images.isEmpty { blocks.append(.images(images)); images = [] }
                blocks.append(.node(node))
            }
        }
        if !inline.isEmpty { blocks.append(.richText(inline)) }
        if !images.isEmpty { blocks.append(.images(images)) }
        return blocks
    }

    static func mediaIntent(nodes: [ThreadContentNode], selecting id: ThreadMediaID) -> ThreadMediaIntent? {
        guard let source = nodes.first?.id.source else { return nil }
        return ThreadContentDocument(source: source, availability: .available, nodes: nodes, poll: nil)
            .mediaIntent(selecting: id)
    }
}

/// Owned by the immutable presentation row; text parsing is independent of fonts and callbacks.
struct PreparedThreadContentBlock: Identifiable, Equatable, Sendable {
    let block: ThreadContentBlock
    let runs: [TiebaRichTextRun]
    var id: ThreadContentNodeID? { block.id }
    static func make(_ document: ThreadContentDocument) -> [Self] {
        ThreadContentBlock.make(document.nodes).map { block in
            let runs: [TiebaRichTextRun]
            if case let .richText(nodes) = block { runs = TiebaRichText.runs(nodes: nodes) } else { runs = [] }
            return Self(block: block, runs: runs)
        }
    }
}
