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
            fixtureDefaults: (),
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

    @Test
    func retainedValueUpdateAfterSettledAnchorDoesNotRepositionLiveTable()
        async throws {
        let anchor = Stage17TestBox<Int?>(nil)
        var list = makeList(anchor: anchor)
        let coordinator = list.makeCoordinator()
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
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
        await waitForInitialSnapshot(coordinator: coordinator)
        window.layoutIfNeeded()
        table.layoutIfNeeded()

        let target = IndexPath(row: 40, section: 0)
        let targetOffset = table.rectForRow(at: target).minY + 37
        table.setContentOffset(
            CGPoint(x: 0, y: targetOffset),
            animated: false
        )
        table.layoutIfNeeded()
        let settledOffset = table.contentOffset.y
        #expect(abs(settledOffset - targetOffset) < 0.5)

        coordinator.scrollViewDidEndDecelerating(table)
        let emittedAnchor = try #require(anchor.value)
        #expect(emittedAnchor == 40)

        list = makeList(
            anchor: anchor,
            restoredAnchor: emittedAnchor,
            revision: 1
        )
        coordinator.parent = list
        coordinator.synchronize()
        await waitForSnapshotApplyCount(2, table: table)
        table.layoutIfNeeded()

        #expect(abs(table.contentOffset.y - settledOffset) < 0.5)
        coordinator.dismantle()
        table.removeFromSuperview()
    }

    @Test
    func initialAnchorStillRestoresWhenTheTableIsCreated() async throws {
        let anchor = Stage17TestBox<Int?>(nil)
        let list = makeList(anchor: anchor, restoredAnchor: 40)
        let coordinator = list.makeCoordinator()
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
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
        await waitForInitialSnapshot(coordinator: coordinator)
        window.layoutIfNeeded()
        table.layoutIfNeeded()

        #expect(table.indexPathsForVisibleRows?.first?.row == 40)
        coordinator.dismantle()
        table.removeFromSuperview()
    }

    private func makeList(
        anchor: Stage17TestBox<Int?>,
        restoredAnchor: Int? = nil,
        revision: Int = 0
    ) -> VirtualizedList<Stage17ListItem, Stage17ListRow> {
        VirtualizedList(
            items: (0..<100).map { Stage17ListItem(id: $0, revision: revision) },
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage17.resize-list",
            restoredAnchor: restoredAnchor,
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

    private func waitForInitialSnapshot<RowContent: View>(
        coordinator: VirtualizedList<Stage17ListItem, RowContent>.Coordinator
    ) async {
        for _ in 0..<100 {
            if coordinator.hasAppliedSnapshot {
                return
            }
            await Task.yield()
        }
    }

}

private struct Stage17ListItem: Identifiable, Equatable, Sendable {
    let id: Int
    let revision: Int

    init(id: Int, revision: Int = 0) {
        self.id = id
        self.revision = revision
    }
}

private struct Stage17ListRow: View {
    let item: Stage17ListItem

    var body: some View {
        Text(
            "Stage 17 row \(item.id): a deterministic long line that "
                + "must reflow when the available container width changes. "
                + "revision \(item.revision)"
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
