#if DEBUG
@MainActor
final class ContentActionFixtureRepository: ContentActionRepository {
    private var selections: [ContentActionTarget: Bool] = [:]
    func inspect(_ target: ContentActionTarget) async throws -> ContentActionInspection {
        let author = target.kind == .thread ? target.threadID + 1_000_000 : target.threadID + (target.postID - target.threadID) / 10_000
        return .init(target: target, accountID: 1_100_001, authorID: author, forumID: 90,
                     forumName: "Fixture", firstPostID: target.threadID + 10_000,
                     likeCount: selections[target] == true ? 1 : 0, liked: selections[target] ?? false,
                     permitsOwnDeletion: author == 1_100_001)
    }
    func like(_ inspection: ContentActionInspection, selected: Bool) async throws { selections[inspection.target] = selected }
    func delete(_ inspection: ContentActionInspection) async throws {
        guard inspection.canDelete else { throw ContentActionFailure.unavailable }
    }
}
#endif
