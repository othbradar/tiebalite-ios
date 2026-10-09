import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct AppNavigationStoreTests {
    @Test func searchThenContentLinkKeepSeparateOriginsAndSchemeDoesNotInheritEither() throws {
        let first = RouteIdentity.thread(try #require(ThreadID(101)))
        let second = RouteIdentity.thread(try #require(ThreadID(102)))
        let store = AppNavigationStore()
        #expect(store.push(.search, in: .recommendations))
        #expect(store.push(first, in: .recommendations, readingEntry: .search))
        let url = try #require(URL(string: "https://tieba.baidu.com/p/102"))
        ContentLinkHandler.open(url, openRoute: {
            #expect(store.push($0, in: .recommendations, readingEntry: .contentLink))
        }, openWeb: { _ in Issue.record("Known thread must stay in the native reader") })
        #expect(store.readingEntry(for: first, scope: .root(.recommendations)) == .search)
        #expect(store.readingEntry(for: second, scope: .root(.recommendations)) == .contentLink)
        #expect(store.replacePathFromSystem([.search, first], in: .recommendations))
        #expect(store.readingEntry(for: first, scope: .root(.recommendations)) == .search)
        #expect(store.readingEntry(for: second, scope: .root(.recommendations)) == .unspecified)
        #expect(store.handleExternalURL(try #require(URL(string: "com.baidu.tieba://unidispatch/pb?tid=101"))))
        #expect(store.readingEntry(for: first, scope: .root(.recommendations)) == .unspecified)
    }

    @Test func incomingWebThreadKeepsNativeUniversalLinkOriginUntilItsRouteIsRemoved() throws {
        let thread = RouteIdentity.thread(try #require(ThreadID(101)))
        let store = AppNavigationStore()
        store.openSettingsRoute(.history)
        store.pushSettingsContent(thread, readingEntry: .history)
        #expect(store.replaceRootDetail(thread, in: .recommendations, readingEntry: .recommendations))
        #expect(store.handleExternalURL(try #require(URL(string: "https://tieba.baidu.com/p/101"))))
        #expect(store.state.routes(for: .recommendations) == [thread])
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)).rawValue == 32)
        #expect(store.readingEntry(for: thread, scope: .settings) == .history)
        #expect(store.replacePathFromSystem([], in: .recommendations))
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)) == .unspecified)
    }

    @Test func rejectedWebLinksAndUnprovenSchemeDoNotReuseUniversalLinkOrigin() throws {
        let thread = RouteIdentity.thread(try #require(ThreadID(101)))
        let store = AppNavigationStore()
        #expect(store.handleExternalURL(try #require(URL(string: "https://tieba.baidu.com/p/101"))))
        let state = store.state
        #expect(!store.handleExternalURL(try #require(URL(string: "https://example.invalid/p/101"))))
        #expect(store.state == state)
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)).rawValue == 32)
        #expect(store.handleExternalURL(try #require(URL(string: "com.baidu.tieba://unidispatch/pb?tid=101"))))
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)) == .unspecified)
    }

    @Test func notificationEntryPreservesExactTargetAndResetsAfterReturn() throws {
        let target = NotificationTarget(threadID: 101, postID: 303, isSubpost: true)
        let route = RouteIdentity.notification(target)
        let store = AppNavigationStore()
        for kind in NotificationKind.allCases {
            let entry = ThreadReadingEntry.notification(kind, opensQuotedThread: false)
            #expect(store.push(route, in: .notifications, readingEntry: entry))
            #expect(store.readingEntry(for: route, scope: .root(.notifications)) == entry)
            #expect(store.state.routes(for: .notifications) == [.notification(target)])
            #expect(store.replacePathFromSystem([], in: .notifications))
            #expect(store.readingEntry(for: route, scope: .root(.notifications)) == .unspecified)
        }
    }

    @Test func readingOriginFollowsItsPathWithoutChangingIdentityOrLeakingToReentry() throws {
        let thread = RouteIdentity.thread(try #require(ThreadID(101)))
        let subposts = RouteIdentity.subposts(threadID: try #require(ThreadID(101)), postID: try #require(PostID(303)))
        let forum = RouteIdentity.forum(try #require(ForumRoute("fixture")))
        let store = AppNavigationStore()
        #expect(store.push(thread, in: .recommendations, readingEntry: .recommendations))
        #expect(store.push(forum, in: .followedForums))
        #expect(store.push(thread, in: .followedForums, readingEntry: .forum))
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)) == .recommendations)
        #expect(store.readingEntry(for: thread, scope: .root(.followedForums)) == .forum)
        #expect(store.push(subposts, in: .followedForums, readingEntry: .forum))
        #expect(store.readingEntry(for: subposts, scope: .root(.followedForums)) == .forum)
        #expect(store.replacePathFromSystem([forum, thread], in: .followedForums))
        #expect(store.readingEntry(for: thread, scope: .root(.followedForums)) == .forum)
        #expect(store.readingEntry(for: subposts, scope: .root(.followedForums)) == .unspecified)
        #expect(store.replacePathFromSystem([forum], in: .followedForums))
        #expect(store.push(thread, in: .followedForums))
        #expect(store.readingEntry(for: thread, scope: .root(.followedForums)) == .unspecified)
        #expect(store.state.routes(for: .followedForums) == [forum, thread])
        #expect(store.state.routes(for: .recommendations) == [thread])
    }

    @Test func settingsHistoryOriginIsIndependentAndExternalNavigationClearsPreviousOrigin() throws {
        let thread = RouteIdentity.thread(try #require(ThreadID(101)))
        let store = AppNavigationStore()
        store.openSettingsRoute(.history)
        store.pushSettingsContent(thread, readingEntry: .history)
        #expect(store.readingEntry(for: thread, scope: .settings) == .history)
        #expect(store.replaceRootDetail(thread, in: .recommendations, readingEntry: .recommendations))
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)) == .recommendations)
        #expect(store.apply(.replaceRootDetail(root: .recommendations, route: thread)))
        #expect(store.readingEntry(for: thread, scope: .root(.recommendations)) == .unspecified)
        #expect(store.readingEntry(for: thread, scope: .settings) == .history)
        store.replaceSettingsPathFromSystem([.history])
        #expect(store.readingEntry(for: thread, scope: .settings) == .unspecified)
    }

    @Test
    func rootsKeepIndependentPathsAndCurrentTabReselectionIsANoOp() throws {
        let forum = try #require(ForumRoute("swiftui"))
        let recommendationsThread = try #require(ThreadID(101))
        let followedThread = try #require(ThreadID(202))
        let store = AppNavigationStore()

        #expect(store.push(.forum(forum), in: .recommendations))
        #expect(store.push(.thread(recommendationsThread), in: .recommendations))

        store.selectTab(.followedForums)
        #expect(store.push(.forum(forum), in: .followedForums))
        #expect(store.push(.thread(followedThread), in: .followedForums))

        store.selectTab(.recommendations)
        let beforeReselection = store.state
        store.selectTab(.recommendations)

        #expect(store.state == beforeReselection)
        #expect(
            store.state.routes(for: .recommendations) == [
                .forum(forum),
                .thread(recommendationsThread)
            ]
        )
        #expect(
            store.state.routes(for: .followedForums) == [
                .forum(forum),
                .thread(followedThread)
            ]
        )
    }

    @Test
    func duplicateRoutePopsToExistingIdentityWithoutDuplicatingIt() throws {
        let forum = try #require(ForumRoute("swiftui"))
        let thread = try #require(ThreadID(101))
        let post = try #require(PostID(303))
        let store = AppNavigationStore()

        #expect(store.push(.forum(forum), in: .recommendations))
        #expect(store.push(.thread(thread), in: .recommendations))
        #expect(
            store.push(
                .subposts(threadID: thread, postID: post),
                in: .recommendations
            )
        )
        #expect(store.push(.forum(forum), in: .recommendations))

        #expect(store.state.routes(for: .recommendations) == [.forum(forum)])
    }

    @Test
    func invalidGrammarLeavesCanonicalStateUnchanged() throws {
        let thread = try #require(ThreadID(101))
        let mismatchedThread = try #require(ThreadID(202))
        let post = try #require(PostID(303))
        let store = AppNavigationStore()
        let before = store.state

        #expect(
            !store.push(
                .subposts(threadID: mismatchedThread, postID: post),
                in: .recommendations
            )
        )
        #expect(!store.push(.thread(thread), in: .followedForums))
        #expect(store.state == before)
    }

    @Test
    func regularAndCompactProjectionNeverMutateCanonicalRoutes() throws {
        let forum = try #require(ForumRoute("swiftui"))
        let thread = try #require(ThreadID(101))
        let store = AppNavigationStore(
            initialState: AppNavigationState(selectedTab: .recommendations)
        )

        #expect(store.push(.forum(forum), in: .recommendations))
        #expect(store.push(.thread(thread), in: .recommendations))
        let before = store.state

        let regular = store.state.projection(for: .regular)
        let compact = store.state.projection(for: .compact)

        #expect(store.state == before)
        #expect(regular.detailRoot == .forum(forum))
        #expect(regular.detailTail == [.thread(thread)])
        #expect(compact.fullPath == [.forum(forum), .thread(thread)])
    }

    @Test
    func settingsSelectionDoesNotCreateAThirdBusinessRoot() {
        let store = AppNavigationStore()

        store.selectTab(.settings)
        store.openSettingsRoute(.componentGallery)
        let beforeReselection = store.state
        store.selectTab(.settings)

        #expect(store.state.selectedTab == .settings)
        #expect(store.state.settingsPath == [.componentGallery])
        #expect(store.state == beforeReselection)
        #expect(AppTab.settings.rootID == nil)
        #expect(Set(store.state.routesByRoot.keys) == Set(RootID.allCases))
    }

    @Test
    func settingsPathAndBusinessPathsRemainIndependent() throws {
        let forum = try #require(ForumRoute("swiftui"))
        let store = AppNavigationStore()

        #expect(store.push(.forum(forum), in: .recommendations))
        store.openSettingsRoute(.componentGallery)
        store.selectTab(.settings)
        store.selectTab(.recommendations)

        #expect(store.state.settingsPath == [.componentGallery])
        #expect(
            store.state.routes(for: .recommendations) == [.forum(forum)]
        )

        store.replaceSettingsPathFromSystem([])
        #expect(store.state.settingsPath.isEmpty)
        #expect(
            store.state.routes(for: .recommendations) == [.forum(forum)]
        )
    }

    @Test
    func currentTabReselectionDoesNotBlockARealSystemPop() throws {
        let forum = try #require(ForumRoute("swiftui"))
        let thread = try #require(ThreadID(101))
        let store = AppNavigationStore()

        #expect(store.push(.forum(forum), in: .recommendations))
        #expect(store.push(.thread(thread), in: .recommendations))
        store.selectTab(.recommendations)

        #expect(store.replacePathFromSystem([.forum(forum)], in: .recommendations))
        #expect(
            store.state.routes(for: .recommendations) == [.forum(forum)]
        )

        #expect(store.replacePathFromSystem([], in: .recommendations))
        #expect(store.state.routes(for: .recommendations).isEmpty)
    }
}
