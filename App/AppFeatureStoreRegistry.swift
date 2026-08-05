@MainActor
final class AppFeatureStoreRegistry {
    let followedForumsStore: FollowedForumsStore
    let recommendationsStore: RecommendationsStore

    private let makeThreadReaderStore: @MainActor (Int64) -> ThreadReaderStore
    private let makeForumHomeStore: @MainActor (ForumRoute) -> ForumHomeStore
    private var forumHomeStores: [ForumStoreKey: ForumHomeStore] = [:]
    private var threadReaderStores: [ThreadStoreKey: ThreadReaderStore] = [:]

    init(
        followedForumsStore: FollowedForumsStore,
        recommendationsStore: RecommendationsStore,
        makeThreadReaderStore: @escaping @MainActor (Int64) -> ThreadReaderStore,
        makeForumHomeStore: @escaping @MainActor (ForumRoute) -> ForumHomeStore = {
            ForumHomeStore(
                route: $0,
                repository: FixtureForumHomeRepository()
            )
        }
    ) {
        self.followedForumsStore = followedForumsStore
        self.recommendationsStore = recommendationsStore
        self.makeThreadReaderStore = makeThreadReaderStore
        self.makeForumHomeStore = makeForumHomeStore
    }

    convenience init(compositionRoot: AppCompositionRoot) {
        self.init(
            followedForumsStore: compositionRoot.makeFollowedForumsStore(),
            recommendationsStore: compositionRoot.makeRecommendationsStore(),
            makeThreadReaderStore: compositionRoot.makeThreadReaderStore,
            makeForumHomeStore: compositionRoot.makeForumHomeStore
        )
    }

    func forumHomeStore(
        for root: RootID,
        route: ForumRoute
    ) -> ForumHomeStore {
        let key = ForumStoreKey(root: root, route: route)
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
        let key = ThreadStoreKey(root: root, threadID: threadID)
        if let existing = threadReaderStores[key] {
            return existing
        }
        let store = makeThreadReaderStore(threadID.rawValue)
        threadReaderStores[key] = store
        return store
    }

    func retainFeatureStores(in navigationState: AppNavigationState) {
        let activeForumKeys: Set<ForumStoreKey> = Set(
            RootID.allCases.flatMap { root in
                navigationState.routes(for: root).compactMap { route -> ForumStoreKey? in
                    guard case let .forum(forumRoute) = route else {
                        return nil
                    }
                    return ForumStoreKey(root: root, route: forumRoute)
                }
            }
        )
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
                    return ThreadStoreKey(root: root, threadID: threadID)
                }
            }
        )
        threadReaderStores = threadReaderStores.filter { key, _ in
            activeKeys.contains(key)
        }
    }

    func retainThreadStores(in navigationState: AppNavigationState) {
        retainFeatureStores(in: navigationState)
    }
}

private struct ForumStoreKey: Hashable {
    let root: RootID
    let route: ForumRoute
}

private struct ThreadStoreKey: Hashable {
    let root: RootID
    let threadID: ThreadID
}
