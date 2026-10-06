import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite
import UIKit

struct U07ContentActionsTests {
    @Test
    func recommendationDoesNotDiscardLinkedAbstract() {
        var wire = Tieba_ThreadInfo()
        wire.richAbstract = [.with {
            $0.type = 1
            $0.text = "正文链接"
            $0.link = "https://tieba.baidu.com/p/100001"
        }]
        let feed = RecommendationFeedMapper.map(wire, ownerThreadID: 100_002)
        #expect(feed.abstractText == "正文链接")
        #expect(TiebaRichText.runs(nodes: feed.abstractNodes).compactMap(\.linkIntent).count == 1)
    }

    @Test @MainActor
    func contentIntentDispatchesIntoTheCurrentProductionStack() throws {
        var routes: [RouteIdentity] = []
        var webURLs: [URL] = []
        let thread = try #require(ThreadID(100_001))
        let forum = try #require(ForumRoute("钢笔"))
        for url in [try #require(PublicContentURL.thread(thread.rawValue)), try #require(PublicContentURL.forum("钢笔"))] {
            #expect(ContentLinkHandler.open(url, openRoute: { routes.append($0) }, openWeb: { webURLs.append($0) }))
        }
        #expect(routes == [.thread(thread), .forum(forum)])
        #expect(webURLs.isEmpty)
        let external = try #require(URL(string: "https://fixture.invalid/article?ref=example#section"))
        ContentLinkHandler.open(external, openRoute: { routes.append($0) }, openWeb: { webURLs.append($0) })
        #expect(routes.count == 2)
        #expect(webURLs == [external])
    }

    @Test @MainActor
    func productionContentLinksCanPushAndReturnInExistingNavigationStore() throws {
        let store = AppNavigationStore()
        let first = try #require(ThreadID(100_001))
        let second = try #require(ThreadID(100_002))
        let post = try #require(PostID(12))
        #expect(store.push(.thread(first), in: .recommendations))
        #expect(store.push(.subposts(threadID: first, postID: post), in: .recommendations))
        let url = try #require(PublicContentURL.thread(second.rawValue))
        ContentLinkHandler.open(url, openRoute: { #expect(store.push($0, in: .recommendations)) }, openWeb: { _ in Issue.record() })
        #expect(store.state.routes(for: .recommendations) == [.thread(first), .subposts(threadID: first, postID: post), .thread(second)])
        let forum = try #require(ForumRoute("钢笔"))
        #expect(store.push(.forum(forum), in: .recommendations))
        #expect(store.push(.thread(first), in: .recommendations))
        #expect(store.state.routes(for: .recommendations) == [.thread(first)])
        #expect(!store.push(.subposts(threadID: second, postID: post), in: .recommendations))
        #expect(store.state.routes(for: .followedForums).isEmpty)
        store.openSettingsRoute(.history)
        #expect(store.pushSettingsRoute(.content(.thread(first))))
        #expect(store.pushSettingsRoute(.content(.thread(second))))
        #expect(store.pushSettingsRoute(.content(.forum(forum))))
    }

    @Test @MainActor
    func productionHandlerRejectsUnsafeLinksAndDoesNotGuessUnknownRoutes() throws {
        var routes: [RouteIdentity] = []
        var webURLs: [URL] = []
        for value in ["/p/123", "javascript:alert(1)", "file:///tmp/x", "custom://p/123",
                      "https://user:pass@tieba.baidu.com/p/123"] {
            let url = try #require(URL(string: value))
            #expect(!ContentLinkHandler.open(url, openRoute: { routes.append($0) }, openWeb: { webURLs.append($0) }))
        }
        #expect(routes.isEmpty && webURLs.isEmpty)
        let http = try #require(URL(string: "http://tieba.baidu.com/p/123"))
        ContentLinkHandler.open(http, openRoute: { routes.append($0) }, openWeb: { webURLs.append($0) })
        #expect(routes == [.thread(try #require(ThreadID(123)))])
        let unknown = try #require(URL(string: "https://tieba.baidu.com/unknown?id=123"))
        ContentLinkHandler.open(unknown, openRoute: { routes.append($0) }, openWeb: { webURLs.append($0) })
        #expect(webURLs == [unknown])
    }

    @Test @MainActor
    func mentionsRequireRealIdentityAndKeepDisplayedLabelAndCopyText() throws {
        let source = ThreadContentSource(threadID: 1, postID: 2, scope: .post)
        let nodes = [nil, 0, -1, 7301].enumerated().map { index, id in
            ThreadContentNode(id: .init(source: source, ordinal: index), rawType: 4,
                              payload: .mention(.init(userID: id, label: "@同名用户")))
        }
        let runs = TiebaRichText.runs(nodes: nodes)
        #expect(runs.compactMap(\.profileIntent).map { $0.route.userID.rawValue } == [7301])
        #expect(runs.compactMap(\.linkIntent).isEmpty)
        let text = TiebaRichTextBuilder.build(runs: runs, font: .systemFont(ofSize: 17))
        #expect(TiebaRichTextBuilder.copyText(text) == String(repeating: "@同名用户", count: 4))
        #expect(text.attribute(.link, at: 0, effectiveRange: nil) == nil)
        #expect(text.attribute(.link, at: text.length - 1, effectiveRange: nil) != nil)
    }

    @Test
    func publicShareLinksRoundTripWithoutAPIOrTrackingFields() throws {
        let url = try #require(PublicContentURL.forum("名字 & 中文"))
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.queryItems == [URLQueryItem(name: "kw", value: "名字 & 中文")])
        #expect(PublicContentURL.thread(42)?.absoluteString == "https://tieba.baidu.com/p/42")
        #expect(PublicContentURL.thread(0) == nil)
        #expect(PublicContentURL.forum(" ") == nil)
        #expect(PublicContentURL.forum("吧\n名") == nil)
    }

    @Test
    func legacyAbstractDoesNotInventMentionIdentityOrLoseLinks() {
        var wire = Tieba_ThreadInfo()
        wire.abstract = [.with { $0.type = 4; $0.text = "@用户123" },
                         .with { $0.type = 1; $0.text = "链接"; $0.link = "https://fixture.invalid/page" }]
        let feed = RecommendationFeedMapper.map(wire, ownerThreadID: 7)
        let runs = TiebaRichText.runs(nodes: feed.abstractNodes)
        #expect(runs.compactMap(\.profileIntent).isEmpty)
        #expect(runs.compactMap(\.linkIntent).count == 1)
        #expect(runs.map(\.alternativeText).joined() == "@用户123链接")
    }
}
