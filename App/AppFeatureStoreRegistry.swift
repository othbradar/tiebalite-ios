@MainActor
final class AppFeatureStoreRegistry {
    let browsingHistoryStore: BrowsingHistoryStore
    let followedForumsStore: FollowedForumsStore
    let recommendationsStore: RecommendationsStore
    let searchStore: SearchStore
    let settingsStore: SettingsStore

    private let makeThreadReaderStore: @MainActor (Int64) -> ThreadReaderStore
    private let makeForumHomeStore: @MainActor (ForumRoute) -> ForumHomeStore
    private let makeUserProfileStore:
        @MainActor (UserProfileRoute) -> UserProfileStore
    private var forumHomeStores: [ForumStoreKey: ForumHomeStore] = [:]
    private var threadReaderStores: [ThreadStoreKey: ThreadReaderStore] = [:]
    private var userProfileStores: [UserProfileStoreKey: UserProfileStore] = [:]

    init(
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
        self.browsingHistoryStore = browsingHistoryStore
        self.followedForumsStore = followedForumsStore
        self.recommendationsStore = recommendationsStore
        self.searchStore = searchStore
        self.settingsStore = settingsStore
        self.makeThreadReaderStore = makeThreadReaderStore
        self.makeForumHomeStore = makeForumHomeStore
        self.makeUserProfileStore = makeUserProfileStore
    }

    convenience init(compositionRoot: AppCompositionRoot) {
        self.init(
            followedForumsStore: compositionRoot.makeFollowedForumsStore(),
            recommendationsStore: compositionRoot.makeRecommendationsStore(),
            browsingHistoryStore: compositionRoot.makeBrowsingHistoryStore(),
            settingsStore: compositionRoot.makeSettingsStore(),
            searchStore: compositionRoot.makeSearchStore(),
            makeThreadReaderStore: compositionRoot.makeThreadReaderStore,
            makeForumHomeStore: compositionRoot.makeForumHomeStore,
            makeUserProfileStore: compositionRoot.makeUserProfileStore
        )
    }

    func forumHomeStore(
        for root: RootID,
        route: ForumRoute
    ) -> ForumHomeStore {
        forumHomeStore(for: .root(root), route: route)
    }

    func forumHomeStore(
        for scope: AppFeatureScope,
        route: ForumRoute
    ) -> ForumHomeStore {
        let key = ForumStoreKey(scope: scope, route: route)
        if let existing = forumHomeStores[key] {
            return existing
        }
        let store = makeForumHomeStore(route)
        forumHomeStores[key] = store
        return store
    }

    func threadReaderStore(
        for root: RootID,
        threadID: ThreadID
    ) -> ThreadReaderStore {
        threadReaderStore(for: .root(root), threadID: threadID)
    }

    func threadReaderStore(
        for scope: AppFeatureScope,
        threadID: ThreadID
    ) -> ThreadReaderStore {
        let key = ThreadStoreKey(scope: scope, threadID: threadID)
        if let existing = threadReaderStores[key] {
            return existing
        }
        let store = makeThreadReaderStore(threadID.rawValue)
        threadReaderStores[key] = store
        return store
    }

    func userProfileStore(
        for scope: AppFeatureScope,
        route: UserProfileRoute
    ) -> UserProfileStore {
        let key = UserProfileStoreKey(scope: scope, userID: route.userID)
        if let existing = userProfileStores[key] {
            return existing
        }
        let store = makeUserProfileStore(route)
        userProfileStores[key] = store
        return store
    }

    func retainFeatureStores(in navigationState: AppNavigationState) {
        let activeForumKeys: Set<ForumStoreKey> = Set(
            RootID.allCases.flatMap { root in
                navigationState.routes(for: root).compactMap { route -> ForumStoreKey? in
                    guard case let .forum(forumRoute) = route else {
                        return nil
                    }
                    return ForumStoreKey(
                        scope: .root(root),
                        route: forumRoute
                    )
                }
            }
        ).union(settingsForumKeys(in: navigationState))
        forumHomeStores = forumHomeStores.filter { key, store in
            guard activeForumKeys.contains(key) else {
                store.cancel()
                return false
            }
            return true
        }

        let activeKeys: Set<ThreadStoreKey> = Set(
            RootID.allCases.flatMap { root in
                navigationState.routes(for: root).compactMap { route -> ThreadStoreKey? in
                    guard case let .thread(threadID) = route else {
                        return nil
                    }
                    return ThreadStoreKey(
                        scope: .root(root),
                        threadID: threadID
                    )
                }
            }
        ).union(settingsThreadKeys(in: navigationState))
        threadReaderStores = threadReaderStores.filter { key, store in
            guard activeKeys.contains(key) else {
                store.cancel()
                return false
            }
            return true
        }

        let activeProfileKeys = rootProfileKeys(in: navigationState)
            .union(settingsProfileKeys(in: navigationState))
        userProfileStores = userProfileStores.filter { key, store in
            guard activeProfileKeys.contains(key) else {
                store.cancel()
                return false
            }
            return true
        }
    }

    func retainThreadStores(in navigationState: AppNavigationState) {
        retainFeatureStores(in: navigationState)
    }

    private func settingsContentRoutes(
        in state: AppNavigationState
    ) -> [RouteIdentity] {
        state.settingsPath.compactMap { route in
            guard case let .content(contentRoute) = route else {
                return nil
            }
            return contentRoute
        }
    }

    private func settingsForumKeys(
        in state: AppNavigationState
    ) -> Set<ForumStoreKey> {
        Set(settingsContentRoutes(in: state).compactMap { route in
            guard case let .forum(forumRoute) = route else {
                return nil
            }
            return ForumStoreKey(scope: .settings, route: forumRoute)
        })
    }

    private func settingsThreadKeys(
        in state: AppNavigationState
    ) -> Set<ThreadStoreKey> {
        Set(settingsContentRoutes(in: state).compactMap { route in
            guard case let .thread(threadID) = route else {
                return nil
            }
            return ThreadStoreKey(scope: .settings, threadID: threadID)
        })
    }

    private func rootProfileKeys(
        in state: AppNavigationState
    ) -> Set<UserProfileStoreKey> {
        Set(RootID.allCases.flatMap { root in
            state.routes(for: root).compactMap { route in
                guard case let .userProfile(profileRoute) = route else {
                    return nil
                }
                return UserProfileStoreKey(
                    scope: .root(root),
                    userID: profileRoute.userID
                )
            }
        })
    }

    private func settingsProfileKeys(
        in state: AppNavigationState
    ) -> Set<UserProfileStoreKey> {
        Set(settingsContentRoutes(in: state).compactMap { route in
            guard case let .userProfile(profileRoute) = route else {
                return nil
            }
            return UserProfileStoreKey(
                scope: .settings,
                userID: profileRoute.userID
            )
        })
    }
}

private struct ForumStoreKey: Hashable {
    let scope: AppFeatureScope
    let route: ForumRoute
}

private struct ThreadStoreKey: Hashable {
    let scope: AppFeatureScope
    let threadID: ThreadID
}

private struct UserProfileStoreKey: Hashable {
    let scope: AppFeatureScope
    let userID: UserID
}
