import Foundation
import Testing
@testable import TiebaLite

struct R05ReadingShellTests {
    @Test
    func portraitAndNarrowWindowsUseStacksWhileWideRegularWindowsKeepSplit() {
        for viewport in [CGSize(width: 1_032, height: 1_376), CGSize(width: 834, height: 1_194),
                         CGSize(width: 390, height: 1_024), CGSize(width: 800, height: 800)] {
            #expect(AppShellPresentation.layout(hasRegularWidth: true, viewport: viewport) == .compact)
        }
        #expect(AppShellPresentation.layout(
            hasRegularWidth: true, viewport: CGSize(width: 1_376, height: 1_032)
        ) == .regular)
        #expect(AppShellPresentation.layout(
            hasRegularWidth: false, viewport: CGSize(width: 852, height: 393)
        ) == .compact)
    }

    @Test
    func onlyTheSelectedReadingChainHidesTheSelectorWithoutChangingRoutes() throws {
        let forum = try #require(ForumRoute("Swift"))
        let thread = try #require(ThreadID(140_003))
        let author = try #require(UserProfileRoute(userID: 17_001, fallbackDisplayName: "作者"))
        let readingPath: [RouteIdentity] = [.forum(forum), .thread(thread), .userProfile(author)]
        for tab in AppTab.allCases {
            let state = AppNavigationState(selectedTab: tab, routesByRoot: [.followedForums: readingPath])
            #expect(AppShellPresentation.showsPhoneTabSelector(in: state) == (tab != .followedForums))
            #expect(state.routes(for: .followedForums) == readingPath)
        }
        for path in [[RouteIdentity.forum(forum)], [.forum(forum), .thread(thread)], readingPath] {
            let state = AppNavigationState(selectedTab: .followedForums, routesByRoot: [.followedForums: path])
            #expect(!AppShellPresentation.showsPhoneTabSelector(in: state))
        }
        let directThread = AppNavigationState(
            selectedTab: .recommendations, routesByRoot: [.recommendations: [.thread(thread)]]
        )
        #expect(!AppShellPresentation.showsPhoneTabSelector(in: directThread))
        let search = AppNavigationState(selectedTab: .recommendations, routesByRoot: [.recommendations: [.search]])
        #expect(AppShellPresentation.showsPhoneTabSelector(in: search))
        #expect(AppShellPresentation.showsPhoneTabSelector(in: AppNavigationState()))
    }

    @Test
    func historyReadingHidesSelectorButSettingsAndOtherTabsRemainAvailable() throws {
        let forum = try #require(ForumRoute("Swift"))
        let thread = try #require(ThreadID(140_003))
        let readingPaths: [[SettingsRoute]] = [
            [.history, .content(.forum(forum))],
            [.preferences, .history, .content(.thread(thread))]
        ]
        for path in readingPaths {
            let state = AppNavigationState(selectedTab: .settings, settingsPath: path)
            #expect(!AppShellPresentation.showsPhoneTabSelector(in: state))
            #expect(state.settingsPath == path)
            let otherRoot = AppNavigationState(selectedTab: .notifications, settingsPath: path)
            #expect(AppShellPresentation.showsPhoneTabSelector(in: otherRoot))
        }
        let nonReadingPaths: [[SettingsRoute]] = [[], [.preferences], [.preferences, .about], [.history]]
        for path in nonReadingPaths {
            #expect(AppShellPresentation.showsPhoneTabSelector(
                in: AppNavigationState(selectedTab: .settings, settingsPath: path)
            ))
        }
    }
}
