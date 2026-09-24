import Foundation

enum SubpostsRowID: Hashable, Sendable {
    case parent(Int64)
    case count
    case reply(Int64)
    case footer
}

struct SubpostsRow: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case parent(ThreadReaderPost, threadAuthorID: Int64)
        case count(Int)
        case reply(Subpost, isThreadAuthor: Bool)
        case footer(SubpostsPhase, hasMore: Bool)
    }
    let id: SubpostsRowID
    let content: Content

    static func make(_ snapshot: SubpostsPage, phase: SubpostsPhase) -> [Self] {
        var result: [Self] = []
        if let parent = snapshot.parent {
            result.append(.init(id: .parent(parent.id.postID), content: .parent(parent, threadAuthorID: snapshot.threadAuthorID)))
        }
        result.append(.init(id: .count, content: .count(snapshot.totalCount)))
        result += snapshot.items.map {
            .init(id: .reply($0.id), content: .reply($0, isThreadAuthor: $0.author.isThreadAuthor(snapshot.threadAuthorID)))
        }
        result.append(.init(id: .footer, content: .footer(phase, hasMore: snapshot.hasMore)))
        return result
    }
}
