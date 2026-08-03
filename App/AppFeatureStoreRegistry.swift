@MainActor
final class AppFeatureStoreRegistry {
    let recommendationsStore: RecommendationsStore

    private let makeThreadReaderStore: @MainActor (Int64) -> ThreadReaderStore
    private var threadReaderStores: [ThreadStoreKey: ThreadReaderStore] = [:]

    init(
        recommendationsStore: RecommendationsStore,
        makeThreadReaderStore: @escaping @MainActor (Int64) -> ThreadReaderStore
    ) {
        self.recommendationsStore = recommendationsStore
        self.makeThreadReaderStore = makeThreadReaderStore
    }

    convenience init(compositionRoot: AppCompositionRoot) {
        self.init(
            recommendationsStore: compositionRoot.makeRecommendationsStore(),
            makeThreadReaderStore: compositionRoot.makeThreadReaderStore
        )
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

    func retainThreadStores(in navigationState: AppNavigationState) {
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
}

private struct ThreadStoreKey: Hashable {
    let root: RootID
    let threadID: ThreadID
}
