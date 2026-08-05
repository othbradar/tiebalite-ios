import Testing
@testable import TiebaLite

@MainActor
struct AppNavigationStoreTests {
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
        let store = AppNavigationStore()

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
