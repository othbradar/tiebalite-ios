import Foundation
#if TEST_SUPPORT
@testable import TiebaLite

actor ExploreTestSource: ExplorePageLoading {
    var count = 0
    var held = false
    let started = HarnessContinuationGate<Void>()
    let release = HarnessContinuationGate<Void>()
    func hold() { held = true }
    func load(_ feed: ExploreFeed, cursor: ExploreCursor?) async throws -> ExplorePage {
        count += 1
        if held { started.succeed(()); _ = try? await release.wait() }
        let item = RecommendationSummary(
            threadID: feed == .following ? 110 : 210, title: "Synthetic", forumName: "Fixture", authorName: "Author",
            replyCount: 5, thumbnail: nil,
            feed: .init(abstractText: "Body", media: [.init(resourceID: "fixture", candidateURLs: [])]))
        return .init(items: [item], next: nil)
    }
}
#endif
