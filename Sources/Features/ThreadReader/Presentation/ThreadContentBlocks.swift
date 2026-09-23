import Foundation

enum ThreadContentBlock: Identifiable, Equatable, Sendable {
    case node(ThreadContentNode)
    case images([ThreadContentNode])

    var id: ThreadContentNodeID? {
        switch self {
        case let .node(node): node.id
        case let .images(nodes): nodes.first?.id
        }
    }

    static func make(_ nodes: [ThreadContentNode]) -> [Self] {
        var blocks: [Self] = []
        var images: [ThreadContentNode] = []
        for node in nodes {
            if case .image = node.payload {
                images.append(node)
            } else {
                if !images.isEmpty { blocks.append(.images(images)); images = [] }
                blocks.append(.node(node))
            }
        }
        if !images.isEmpty { blocks.append(.images(images)) }
        return blocks
    }

    static func mediaIntent(nodes: [ThreadContentNode], selecting id: ThreadMediaID) -> ThreadMediaIntent? {
        guard let source = nodes.first?.id.source else { return nil }
        return ThreadContentDocument(source: source, availability: .available, nodes: nodes, poll: nil)
            .mediaIntent(selecting: id)
    }
}
