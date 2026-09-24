import Testing

@testable import TiebaLite

@MainActor
struct R08SubpostsNavigationTests {
    @Test func profileIsAValidChildWithoutChangingRootOrParentIdentity() throws {
        let thread = try #require(ThreadID(8_001))
        let post = try #require(PostID(9_002))
        let profile = try #require(UserProfileRoute(userID: 91, fallbackDisplayName: "样本"))
        let forum = try #require(ForumRoute(forumID: 90, forumName: "固定样本吧"))
        let routes: [RouteIdentity] = [
            .search, .forum(forum), .thread(thread),
            .subposts(threadID: thread, postID: post), .userProfile(profile)
        ]
        #expect(RouteGrammar.isValid(routes, for: .followedForums))
        #expect(RouteGrammar.isValid(routes, for: .recommendations))
        #expect(!RouteGrammar.isValid([.subposts(threadID: thread, postID: post), .userProfile(profile)], for: .recommendations))
        let settings: [SettingsRoute] = [.history] + routes.dropFirst().map { .content($0) }
        #expect(SettingsRouteGrammar.canonical(settings) == settings)
        let descriptor = LaunchScenarioFactory.make(scenario: .fixtureReadingFlow)
        let registry = AppFeatureStoreRegistry(compositionRoot: descriptor.compositionRoot)
        let route = SubpostsRoute(threadID: 8_001, postID: 9_002)
        let store = try #require(registry.subpostsStore(for: .root(.recommendations), route: route))
        let state = AppNavigationState(selectedTab: .recommendations, routesByRoot: [.recommendations: routes])
        registry.retainFeatureStores(in: state)
        #expect(registry.subpostsStore(for: .root(.recommendations), route: route) === store)
        #expect(state.projection(for: .regular).fullPath == state.projection(for: .compact).fullPath)
        registry.retainFeatureStores(in: AppNavigationState())
        #expect(registry.subpostsStore(for: .root(.recommendations), route: route) !== store)
    }
}
