import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct Stage17AdaptiveLayoutTests {
    @Test
    func deepRoutesAndStoreIdentitySurviveProjectionRoundTrip() throws {
        let forum = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let threadID = try #require(ThreadID(140_006))
        let profile = try #require(
            UserProfileRoute(userID: 17_001, fallbackDisplayName: "作者")
        )
        let routes: [RouteIdentity] = [
            .search,
            .forum(forum),
            .thread(threadID),
            .userProfile(profile)
        ]
        let settingsPath: [SettingsRoute] = [
            .history,
            .content(.forum(forum)),
            .content(.thread(threadID)),
            .content(.userProfile(profile))
        ]
        let state = AppNavigationState(
            selectedTab: .settings,
            routesByRoot: [.recommendations: routes],
            settingsPath: settingsPath
        )
        let navigation = AppNavigationStore(initialState: state)
        let registry = AppFeatureStoreRegistry(
            followedForumsStore: FollowedForumsStore(
                repository: FixtureFollowedForumsRepository()
            ),
            recommendationsStore: RecommendationsStore(
                repository: FixtureRecommendationRepository()
            ),
            makeThreadReaderStore: {
                ThreadReaderStore(
                    threadID: $0,
                    repository: FixtureThreadReaderRepository()
                )
            }
        )
        let forumStore = registry.forumHomeStore(
            for: .recommendations,
            route: forum
        )
        let threadStore = registry.threadReaderStore(
            for: .recommendations,
            threadID: threadID
        )
        let profileStore = registry.userProfileStore(
            for: .root(.recommendations),
            route: profile
        )

        _ = navigation.state.projection(for: .regular)
        _ = navigation.state.projection(for: .compact)
        _ = navigation.state.projection(for: .regular)
        registry.retainFeatureStores(in: navigation.state)

        #expect(navigation.state == state)
        #expect(navigation.state.settingsPath == settingsPath)
        #expect(
            registry.forumHomeStore(
                for: .recommendations,
                route: forum
            ) === forumStore
        )
        #expect(
            registry.threadReaderStore(
                for: .recommendations,
                threadID: threadID
            ) === threadStore
        )
        #expect(
            registry.userProfileStore(
                for: .root(.recommendations),
                route: profile
            ) === profileStore
        )
    }

    @Test
    func displayedClaimsBelongToStableRouteStores() async throws {
        let forum = try #require(
            ForumRoute(forumID: 13_001, forumName: "Swift开发")
        )
        let forumStore = ForumHomeStore(
            route: forum,
            repository: FixtureForumHomeRepository()
        )
        #expect(forumStore.claimDisplayedForum(13_001))
        #expect(!forumStore.claimDisplayedForum(13_001))

        let threadStore = ThreadReaderStore(
            threadID: 140_006,
            repository: FixtureThreadReaderRepository()
        )
        #expect(threadStore.claimDisplayedThread(140_006))
        #expect(!threadStore.claimDisplayedThread(140_006))
        #expect(!threadStore.claimDisplayedThread(140_007))

        let profileRoute = try #require(
            UserProfileRoute(userID: 17_001, fallbackDisplayName: "作者")
        )
        let profileStore = UserProfileStore(
            route: profileRoute,
            repository: FixtureUserProfileRepository()
        )
        #expect(profileStore.claimDisplayedUser(profileRoute.userID))
        #expect(!profileStore.claimDisplayedUser(profileRoute.userID))
    }

    @Test
    func unchangedResizeKeepsOneDiffableSnapshotAndStableIdentity() async throws {
        let anchor = Stage17TestBox<Int?>(nil)
        var list = makeList(anchor: anchor)
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(
            frame: CGRect(x: 0, y: 0, width: 1_024, height: 768),
            style: .plain
        )
        coordinator.install(on: table)
        coordinator.synchronize()
        await waitForSnapshotApplyCount(1, table: table)

        let dataSource = try #require(coordinator.dataSource)
        let expectedIDs = dataSource.snapshot().itemIdentifiers

        for width in [700.0, 520.0, 320.0, 1_024.0] {
            table.frame.size.width = width
            list = makeList(anchor: anchor)
            coordinator.parent = list
            coordinator.synchronize()
            table.setNeedsLayout()
            table.layoutIfNeeded()
            await Task.yield()

            #expect(coordinator.dataSource === dataSource)
            #expect(
                coordinator.dataSource?.snapshot().itemIdentifiers
                    == expectedIDs
            )
        }

        #expect(table.virtualListDiagnostics.snapshotApplyCount == 1)
        #expect(table.virtualListDiagnostics.itemCount == expectedIDs.count)
        coordinator.dismantle()
    }

    @Test
    func dismantleCapturesTheCurrentStableTopRow() async throws {
        let anchor = Stage17TestBox<Int?>(nil)
        let list = makeList(anchor: anchor)
        let coordinator = list.makeCoordinator()
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 507, height: 768)
        )
        let table = VirtualizedTableView(
            frame: window.bounds,
            style: .plain
        )
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        await waitForSnapshotApplyCount(1, table: table)
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        table.scrollToRow(
            at: IndexPath(row: 40, section: 0),
            at: .top,
            animated: false
        )
        table.layoutIfNeeded()

        coordinator.dismantle()

        #expect(anchor.value == 40)
        table.removeFromSuperview()
    }

    private func makeList(
        anchor: Stage17TestBox<Int?>
    ) -> VirtualizedList<Stage17ListItem, Stage17ListRow> {
        VirtualizedList(
            items: (0..<100).map(Stage17ListItem.init),
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage17.resize-list",
            onScrollSettled: { anchor.value = $0 },
            rowContent: { item in
                Stage17ListRow(item: item)
            }
        )
    }

    private func waitForSnapshotApplyCount(
        _ expected: Int,
        table: VirtualizedTableView
    ) async {
        for _ in 0..<100 {
            if table.virtualListDiagnostics.snapshotApplyCount >= expected {
                return
            }
            await Task.yield()
        }
    }

}

private struct Stage17ListItem: Identifiable, Equatable, Sendable {
    let id: Int

    init(_ id: Int) {
        self.id = id
    }
}

private struct Stage17ListRow: View {
    let item: Stage17ListItem

    var body: some View {
        Text(
            "Stage 17 row \(item.id): a deterministic long line that "
                + "must reflow when the available container width changes."
        )
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding()
    }
}

@MainActor
private final class Stage17TestBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
