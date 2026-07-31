import Foundation
import Testing
@testable import TiebaLite

struct DeepLinkParserTests {
    @Test
    func allowlistedForumAndThreadLinksProduceDeterministicCommands() throws {
        let forum = try #require(ForumName("Swift UI"))
        let thread = try #require(ThreadID(123))
        let cases: [(String, NavigationCommand)] = [
            (
                "com.baidu.tieba://unidispatch/frs?kw=Swift%20UI",
                .replaceRootDetail(root: .recommendations, route: .forum(forum))
            ),
            (
                "com.baidu.tieba://unidispatch/pb?tid=123",
                .replaceRootDetail(root: .recommendations, route: .thread(thread))
            ),
            (
                "https://tieba.baidu.com/f?kw=Swift%20UI",
                .replaceRootDetail(root: .recommendations, route: .forum(forum))
            ),
            (
                "https://tieba.baidu.com/p/123",
                .replaceRootDetail(root: .recommendations, route: .thread(thread))
            )
        ]

        for (rawURL, expected) in cases {
            let url = try #require(URL(string: rawURL))
            #expect(DeepLinkParser.parse(url) == expected)
        }
    }

    @Test
    func invalidOrAmbiguousLinksAreRejectedWithoutGuessing() throws {
        let invalidURLs = [
            "http://tieba.baidu.com/p/123",
            "https://example.invalid/p/123",
            "https://tieba.baidu.com/p/0",
            "https://tieba.baidu.com/p/-1",
            "https://tieba.baidu.com/p/123/",
            "https://tieba.baidu.com/p/9223372036854775808",
            "https://tieba.baidu.com/f",
            "https://tieba.baidu.com/f?kw=",
            "https://tieba.baidu.com/f?kw=one&kw=two",
            "com.baidu.tieba://unidispatch/pb?tid=123&extra=1",
            "com.baidu.tieba://other/frs?kw=Swift"
        ]

        for rawURL in invalidURLs {
            let url = try #require(URL(string: rawURL))
            #expect(DeepLinkParser.parse(url) == nil)
        }
    }

    @Test
    @MainActor
    func applyingExternalLinkPreservesTheUnselectedRootPath() throws {
        let followedForum = try #require(ForumName("followed"))
        let deepLinkedThread = try #require(ThreadID(123))
        let store = AppNavigationStore()

        store.selectTab(.followedForums)
        #expect(store.push(.forum(followedForum), in: .followedForums))
        let beforeFollowedPath = store.state.routes(for: .followedForums)
        let url = try #require(URL(string: "https://tieba.baidu.com/p/123"))
        let command = try #require(DeepLinkParser.parse(url))

        #expect(store.apply(command))
        #expect(store.state.selectedTab == .recommendations)
        #expect(
            store.state.routes(for: .recommendations) == [.thread(deepLinkedThread)]
        )
        #expect(store.state.routes(for: .followedForums) == beforeFollowedPath)
    }

    @Test
    @MainActor
    func rejectedExternalLinkLeavesTheEntireNavigationStateUnchanged() throws {
        let forum = try #require(ForumName("swiftui"))
        let thread = try #require(ThreadID(123))
        let store = AppNavigationStore()

        #expect(store.push(.thread(thread), in: .recommendations))
        #expect(store.push(.forum(forum), in: .followedForums))
        store.openSettingsRoute(.componentGallery)
        store.selectTab(.settings)
        let before = store.state
        let invalidURL = try #require(
            URL(string: "https://tieba.baidu.com/p/0")
        )

        #expect(!store.handleExternalURL(invalidURL))
        #expect(store.state == before)
    }
}
