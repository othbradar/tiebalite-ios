import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U01ForumSortMemoryTests {
    @Test
    func persistenceRestoresBeforeStoreAndItsFirstRequest() async throws {
        let suite = "U01ForumSortMemoryTests.Persistence"
        let defaults = UserDefaults(suiteName: suite)
        defaults?.removePersistentDomain(forName: suite)
        defer { defaults?.removePersistentDomain(forName: suite) }
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let settings = SettingsStore(repository: UserDefaultsAppSettingsRepository(suiteName: suite))
        await settings.loadIfNeeded()
        settings.setDefaultForumSort(.creation)
        settings.updateForumSort(.lastReply, for: route)
        let nameOnly = try #require(ForumRoute("另一个吧"))
        settings.updateForumSort(.creation, for: nameOnly)
        settings.associateForumSort(route: nameOnly, forumID: 13_002, canonicalName: "另一个吧")
        settings.setAppearance(.dark)
        await settings.waitForPendingSave()
        let restored = SettingsStore(repository: UserDefaultsAppSettingsRepository(suiteName: suite))
        await restored.loadIfNeeded()
        let repository = R05ForumFixture()
        let store = ForumHomeStore(route: route, repository: repository, sortPreferences: restored)
        #expect(store.query == .latest(.lastReply))
        #expect(restored.defaultForumSort == .creation)
        #expect(restored.appearance == .dark)
        #expect(restored.forumSortPreferences.identity(for: nameOnly) == .id(13_002))
        let otherRoute = try #require(ForumRoute(forumID: 13_002, forumName: "另一个吧"))
        #expect(restored.forumSortPreferences.order(for: otherRoute) == .creation)
        await store.synchronize(with: route)
        #expect(await repository.recordedRequests().map(\.query) == [.latest(.lastReply)])
    }

    @Test
    func twoForumsKeepIndependentOverridesAndResetFollowsGlobal() async throws {
        let settings = SettingsStore(repository: InMemoryAppSettingsRepository())
        await settings.loadIfNeeded()
        let first = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let second = try #require(ForumRoute(forumID: 13_002, forumName: "另一个吧"))
        let repo = R05ForumFixture()
        let store = ForumHomeStore(route: first, repository: repo, sortPreferences: settings)
        await store.synchronize(with: first)
        await store.changeQuery(.latest(.creation))
        #expect(settings.forumSortPreferences.order(for: first) == .creation)
        #expect(settings.forumSortPreferences.order(for: second) == .lastReply)
        settings.setDefaultForumSort(.creation)
        settings.updateForumSort(.lastReply, for: first)
        await store.synchronize(with: first)
        #expect(store.query == .latest(.lastReply))
        #expect(settings.forumSortPreferences.order(for: second) == .creation)
        await store.followGlobalSort()
        #expect(!store.hasRememberedSort)
        #expect(store.query == .latest(.creation))
        // Explicitly choosing the already displayed value still creates an override.
        await store.changeQuery(.latest(.creation))
        settings.setDefaultForumSort(.lastReply)
        await store.synchronize(with: first)
        #expect(store.query == .latest(.creation))
        #expect(settings.forumSortPreferences.order(for: second) == .lastReply)
    }

    @Test
    func nameAliasMigratesToIDWithoutMergingConflictingForums() throws {
        var preferences = ForumSortPreferences()
        let nameOnly = try #require(ForumRoute("  Swift开发\n"))
        let identified = try #require(ForumRoute(forumID: 13_001, forumName: "swift开发"))
        let conflicting = try #require(ForumRoute(forumID: 13_002, forumName: "swift开发"))
        preferences.set(.creation, for: nameOnly)
        preferences.associate(route: nameOnly, forumID: 13_001, canonicalName: "Swift开发")
        #expect(preferences.order(for: identified) == .creation)
        #expect(preferences.order(for: nameOnly) == .creation)
        preferences.associate(route: conflicting, forumID: 13_002, canonicalName: "swift开发")
        #expect(preferences.order(for: conflicting) == .lastReply)
        #expect(preferences.order(for: identified) == .creation)
        preferences.set(.lastReply, for: conflicting)
        #expect(preferences.order(for: identified) == .creation)
        #expect(preferences.identity(for: nameOnly) == .name("swift开发"))
        let suffix = try #require(ForumRoute("Swift开发吧"))
        #expect(preferences.order(for: suffix) == .lastReply)
    }

    @Test
    func sceneRegistryUsesLoadedSettingsForStoreCreationAndReentry() async throws {
        let root = LaunchScenarioFactory.make(scenario: .forumHomeParity).compositionRoot
        let registry = AppFeatureStoreRegistry(compositionRoot: root)
        await registry.settingsStore.loadIfNeeded()
        registry.settingsStore.setDefaultForumSort(.creation)
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let first = registry.forumHomeStore(for: .followedForums, route: route)
        #expect(first.query == .latest(.creation))
        await first.synchronize(with: route)
        await first.changeQuery(.latest(.lastReply))
        registry.retainFeatureStores(in: AppNavigationState())
        let rebuilt = registry.forumHomeStore(for: .followedForums, route: route)
        #expect(first !== rebuilt)
        #expect(rebuilt.query == .latest(.lastReply))
        #expect(registry.settingsStore === root.makeSettingsStore())
    }

    @Test
    func queryIdentitySeparatesForumSortGoodAndCategory() throws {
        let first = try #require(ForumRoute(forumID: 1, forumName: "甲"))
        let second = try #require(ForumRoute(forumID: 2, forumName: "乙"))
        let category = ForumCategory(id: 7, title: "讨论", isDefault: 0, sorts: [])
        let keys: Set<ForumQueryIdentity> = [
            .init(route: first, query: .latest(.lastReply)), .init(route: first, query: .latest(.creation)),
            .init(route: first, query: .good(7)), .init(route: first, query: .category(category, sort: 0)),
            .init(route: first, query: .category(category, sort: 1)), .init(route: second, query: .latest(.lastReply))
        ]
        #expect(keys.count == 6)
    }

    @Test
    func retainedStoreAdoptsGlobalAndOtherTabsKeepTheirQuery() async throws {
        let settings = SettingsStore(repository: InMemoryAppSettingsRepository())
        await settings.loadIfNeeded()
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let repository = R05ForumFixture()
        let store = ForumHomeStore(route: route, repository: repository, sortPreferences: settings)
        await store.synchronize(with: route)
        store.selectPage(.good)
        await store.activateSelectedPage()
        let good = try #require(store.pageStore(for: .good))
        let original = good.state.snapshot
        settings.setDefaultForumSort(.creation)
        await store.synchronize(with: route)
        #expect(store.query == .latest(.creation))
        #expect(good.query == .good(0))
        #expect(good.state.snapshot == original)
        #expect(store.selectedPage == .good)
    }

    @Test
    func oldPaginationCannotAppendAfterSwitchAndNewRequestStartsAtOne() async throws {
        let route = try #require(ForumRoute(forumID: 13_001, forumName: "Swift开发"))
        let repository = U01SuspendedPaginationRepository()
        let store = ForumHomeStore(route: route, repository: repository)
        await store.synchronize(with: route)
        let page = Task { await store.loadNextPage() }
        try await repository.started.wait()
        await store.changeQuery(.latest(.creation))
        let current = store.state.snapshot
        repository.release.succeed(())
        await page.value
        #expect(store.state.snapshot == current)
        #expect(store.state.snapshot?.currentPage == 1)
        #expect(store.state.snapshot?.threads.allSatisfy { $0.title.contains("发帖排序") } == true)
        #expect(await repository.requests.last?.pageNumber == 1)
        #expect(store.queryIdentity == ForumQueryIdentity(route: route, query: .latest(.creation)))
    }
}

private actor U01SuspendedPaginationRepository: ForumHomeRepository {
    let started = HarnessContinuationGate<Void>()
    let release = HarnessContinuationGate<Void>()
    private(set) var requests: [ForumHomePageRequest] = []
    private let fixture = R05ForumFixture()

    func loadForumHomePage(_ request: ForumHomePageRequest) async throws -> ForumHomeSnapshot {
        requests.append(request)
        let result = try await fixture.loadForumHomePage(request)
        if request.pageNumber == 2 {
            started.succeed(())
            try await release.wait()
        }
        return result
    }
}
