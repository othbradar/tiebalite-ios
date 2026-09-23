import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct R02RootShellTests {
    @Test
    func everyNavigationIconHasBothBundledStates() {
        for tab in AppTab.allCases {
            #expect(UIImage(named: tab.iconAssetName) != nil)
            #expect(UIImage(named: tab.iconAssetName + "-selected") != nil)
        }
    }

    @Test
    func fourDestinationsStartAtHomeAndKeepExistingBusinessIdentities() {
        #expect(AppTab.allCases.map(\.title) == ["首页", "动态", "消息", "我的"])
        #expect(AppNavigationState().selectedTab == .followedForums)
        #expect(AppTab.followedForums.rootID == .followedForums)
        #expect(AppTab.recommendations.rootID == .recommendations)
        #expect(AppTab.notifications.rootID == nil)
        #expect(AppTab.settings.rootID == nil)
    }

    @Test
    func allFourTabsPreserveIndependentPathsAndReselectionDoesNothing() throws {
        let navigation = AppNavigationStore()
        let forum = try #require(ForumRoute("Swift"))
        let thread = try #require(ThreadID(100_003))
        #expect(navigation.push(.forum(forum), in: .followedForums))
        #expect(navigation.push(.thread(thread), in: .recommendations))
        navigation.openSettingsRoute(.preferences)
        #expect(navigation.pushSettingsRoute(.about))
        for _ in 0..<5 {
            for tab in AppTab.allCases {
                navigation.selectTab(tab)
                let before = navigation.state
                navigation.selectTab(tab)
                #expect(navigation.state == before)
                #expect(navigation.state.routes(for: .followedForums) == [.forum(forum)])
                #expect(navigation.state.routes(for: .recommendations) == [.thread(thread)])
                #expect(navigation.state.settingsPath == [.preferences, .about])
            }
        }
    }

    @Test
    func personalSettingsAcceptValidChildrenAndRejectCrossStackRoots() {
        #expect(SettingsRouteGrammar.canonical([.preferences, .about, .licenses])
                == [.preferences, .about, .licenses])
        #expect(SettingsRouteGrammar.canonical([.preferences, .preferences]).isEmpty)
        #expect(SettingsRouteGrammar.canonical([.accountProfile]) == [.accountProfile])
        #expect(SettingsRouteGrammar.canonical([.accountProfile, .history]).isEmpty)
    }

    @Test
    func fourTabsRetainSceneStoresAndScrollAnchors() throws {
        let descriptor = LaunchScenarioFactory.make(scenario: .sessionSignedInFixture)
        let registry = AppFeatureStoreRegistry(compositionRoot: descriptor.compositionRoot)
        let navigation = AppNavigationStore()
        let forum = try #require(ForumRoute("Swift"))
        let thread = try #require(ThreadID(100_003))
        navigation.push(.forum(forum), in: .followedForums)
        navigation.push(.thread(thread), in: .recommendations)
        let forumStore = registry.forumHomeStore(for: .followedForums, route: forum)
        let threadStore = registry.threadReaderStore(for: .recommendations, threadID: thread)
        registry.recommendationsStore.setScrollAnchor(100_003)
        registry.followedForumsStore.setScrollAnchor(13_001)
        for tab in AppTab.allCases {
            navigation.selectTab(tab)
            registry.retainFeatureStores(in: navigation.state)
            #expect(registry.forumHomeStore(for: .followedForums, route: forum) === forumStore)
            #expect(registry.threadReaderStore(for: .recommendations, threadID: thread) === threadStore)
            #expect(registry.recommendationsStore.scrollAnchor == 100_003)
            #expect(registry.followedForumsStore.scrollAnchor == 13_001)
        }
        #expect(descriptor.compositionRoot.notificationCounts.unreadCount == 3)
    }

    @Test
    func badgeIsInjectedAndProductionDoesNotFabricateUnreadMessages() {
        let production = UnavailableNotificationCountSource()
        #expect(production.unreadCount == 0)
        let fixture = NotificationBadgeState(unreadCount: 3)
        #expect(fixture.unreadCount == 3)
        fixture.update(unreadCount: -1)
        #expect(fixture.unreadCount == 0)
        fixture.update(unreadCount: 128)
        #expect(fixture.unreadCount == 128)
        #expect(NotificationBadgePresentation.text(for: 128) == "99+")
        #expect(NotificationBadgePresentation.text(for: 0) == nil)
    }
}
