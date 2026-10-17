import Foundation

/// A narrow cache admission rule. It does not alter posting, reply refresh,
/// page cursors or saved scroll anchors. Known-deleted bodies are never reused.
struct ContentRemovalCachePolicy: Sendable {
    var targets = Set<ContentActionTarget>()
    var dates: [ContentActionTarget: Date] = [:]
    func allows(_ data: Data, key: String) -> Bool {
        guard !targets.isEmpty else { return true }
        let decoder = JSONDecoder()
        if key.contains("thread-v1|") {
            // Manifest records/reading positions contain no content and remain valid.
            if key.contains("|pn:") {
                if let page = try? decoder.decode(CachedReadingPage<ThreadReaderSnapshot>.self, from: data) {
                    return !page.value.posts.contains { post in
                        excludes(post.document.source) || hasNewerSubpostRemoval(post.document.source, than: page.fetchedAt)
                            || post.subposts.contains { excludes($0.document.source) }
                    }
                }
                if let page = try? decoder.decode(CachedReadingPage<SubpostsPage>.self, from: data) {
                    return page.value.parent.map { !excludes($0.document.source) } != false
                        && !page.value.items.contains { excludes($0.document.source) }
                }
            } else if key.contains("|reply-delta|"), let value = try? decoder.decode(ReplyPostUpdate.self, from: data) {
                return !value.posts.contains { excludes($0.document.source) }
            }
        } else if key.hasPrefix("profile-v1:"), let page = try? decoder.decode(ProfileRecord.self, from: data) {
            return !page.posts.contains { post in
                targets.contains { $0.threadID == post.thread.threadID && ($0.kind == .thread || $0.postID == post.postID) }
            }
        } else if key.hasPrefix("forum-v1:"), let page = try? decoder.decode(ForumCachedPage.self, from: data) {
            return !page.page.threads.contains { thread in targets.contains { $0.kind == .thread && $0.threadID == thread.threadID } }
        }
        return true
    }
    private func excludes(_ source: ThreadContentSource) -> Bool {
        targets.contains { $0.threadID == source.threadID && ($0.kind == .thread || $0.postID == source.postID) }
    }
    private func hasNewerSubpostRemoval(_ source: ThreadContentSource, than fetchedAt: Date) -> Bool {
        dates.contains { target, date in
            target.kind == .subpost && target.threadID == source.threadID && target.parentPostID == source.postID && date > fetchedAt
        }
    }
    private struct ProfileRecord: Decodable {
        let posts: [ProfilePostRecord]
    }
    private struct ProfilePostRecord: Decodable { let postID: Int64?; let thread: ProfileThreadRecord }
    private struct ProfileThreadRecord: Decodable { let threadID: Int64 }
}
