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

    @MainActor static func make(_ snapshot: SubpostsPage, phase: SubpostsPhase) -> [Self] {
        let removals = ContentRemovalVisibility.shared
        let removedCount = snapshot.items.filter { removals.contains($0.document.source) }.count
        let blocked = LocalUserVisibility.shared.ids
        var result: [Self] = []
        if let parent = snapshot.parent, !blocked.contains(parent.author.rawUserID) {
            result.append(.init(id: .parent(parent.id.postID), content: .parent(parent, threadAuthorID: snapshot.threadAuthorID)))
        }
        result.append(.init(id: .count, content: .count(max(0, snapshot.totalCount - removedCount))))
        result += snapshot.items.filter { !blocked.contains($0.author.rawUserID) && !removals.contains($0.document.source) }.map {
            .init(id: .reply($0.id), content: .reply($0, isThreadAuthor: $0.author.isThreadAuthor(snapshot.threadAuthorID)))
        }
        result.append(.init(id: .footer, content: .footer(phase, hasMore: snapshot.hasMore)))
        return result
    }
}
