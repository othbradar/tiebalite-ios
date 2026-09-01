#if TEST_SUPPORT
@testable import TiebaLite

@MainActor
extension AppFeatureStoreRegistry {
    convenience init(
        fixtureDefaults: Void,
        followedForumsStore: FollowedForumsStore,
        recommendationsStore: RecommendationsStore,
        browsingHistoryStore: BrowsingHistoryStore = BrowsingHistoryStore(
            repository: InMemoryBrowsingHistoryRepository(),
            clock: SystemAppClock()
        ),
        settingsStore: SettingsStore = SettingsStore(
            repository: InMemoryAppSettingsRepository()
        ),
        searchStore: SearchStore = SearchStore(
            repository: FixtureSearchRepository()
        ),
        makeThreadReaderStore: @escaping @MainActor (Int64) -> ThreadReaderStore,
        makeForumHomeStore: @escaping @MainActor (ForumRoute) -> ForumHomeStore = {
            ForumHomeStore(
                route: $0,
                repository: FixtureForumHomeRepository()
            )
        },
        makeUserProfileStore: @escaping @MainActor (UserProfileRoute) ->
            UserProfileStore = {
                UserProfileStore(
                    route: $0,
                    repository: FixtureUserProfileRepository()
                )
            }
    ) {
        self.init(
            followedForumsStore: followedForumsStore,
            recommendationsStore: recommendationsStore,
            browsingHistoryStore: browsingHistoryStore,
            settingsStore: settingsStore,
            searchStore: searchStore,
            makeThreadReaderStore: makeThreadReaderStore,
            makeForumHomeStore: makeForumHomeStore,
            makeUserProfileStore: makeUserProfileStore
        )
    }
}
#endif
