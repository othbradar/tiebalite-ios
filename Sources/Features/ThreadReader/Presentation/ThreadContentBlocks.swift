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
