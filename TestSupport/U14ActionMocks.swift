import Foundation
@testable import TiebaLite

@MainActor final class U14ActionGate {
    private var entered = false
    private var starting: CheckedContinuation<Void, Never>?
    private var pending: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true; starting?.resume(); starting = nil
        await withCheckedContinuation { pending = $0 }
    }
    func waitForEntry() async {
        if !entered { await withCheckedContinuation { starting = $0 } }
    }
    func release() { pending?.resume(); pending = nil }
}

@MainActor final class U14ActionMock: ContentActionRepository {
    var failure: ContentActionFailure?
    var inspectGate: U14ActionGate?
    var writeGate: U14ActionGate?
    var account: Int64 = 42
    var author: Int64 = 42
    var liked = false
    var writes = 0
    var deletes = 0
    var inspections = 0
    func inspect(_ target: ContentActionTarget) async throws -> ContentActionInspection {
        inspections += 1
        let info = ContentActionInspection(target: target, accountID: account, authorID: author, forumID: 9,
                                           forumName: "Fixture", firstPostID: 1, likeCount: liked ? 3 : 2, liked: liked,
                                           permitsOwnDeletion: author == account)
        await inspectGate?.pause()
        return info
    }
    func like(_ inspection: ContentActionInspection, selected: Bool) async throws {
        writes += 1
        await writeGate?.pause()
        if let failure { throw failure }
        liked = selected
    }
    func delete(_ inspection: ContentActionInspection) async throws {
        deletes += 1
        if let failure { throw failure }
    }
}

@MainActor final class U14Session {
    var value = ContentCacheContext(namespace: "fixture-a", revision: 1)
}
