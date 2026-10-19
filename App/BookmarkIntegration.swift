import SwiftUI

extension AppCompositionRoot {
    func makeBookmarkStore() -> BookmarkStore {
#if DEBUG
        if case .fixture = environment.readingDataSourceMode {
            return BookmarkStore(repository: BookmarkRepository(directory: nil),
                                 context: { .init(namespace: "fixture", revision: 1) }, account: { "fixture-account" })
        }
#endif
        let auth = authContextProvider
        let account = currentAccountStore
        let repository = LiveCurrentAccountRepository(client: environment.httpClient, authContextProvider: auth)
        return BookmarkStore(repository: BookmarkRepository.production(), context: { auth.contentCacheContext }, account: {
            let context = auth.context()
            guard case .active = context else { throw BookmarkFailure.accountUnavailable }
            account.updateContext(context)
            let profile: UserProfile
            if let current = account.profile { profile = current } else { profile = try await repository.loadProfile(context: context) }
            guard auth.context() == context else { throw CancellationError() }
            return String(profile.userID.rawValue)
        })
    }
}

@MainActor
struct BookmarkDestination: View {
    let target: ThreadBookmarkTarget
    let dependencies: AppRouteDependencies
    let openRoute: (RouteIdentity) -> Void
    @State private var reader: ThreadReaderStore
    @State private var ready = false
    @State private var failed = false
    @State private var retry: UInt64 = 0

    init(target: ThreadBookmarkTarget, dependencies: AppRouteDependencies, openRoute: @escaping (RouteIdentity) -> Void) {
        self.target = target; self.dependencies = dependencies; self.openRoute = openRoute
        _reader = State(initialValue: dependencies.featureStores.makeBookmarkedReader(threadID: target.threadID))
    }

    var body: some View {
        Group {
            if ready {
                ThreadReaderView(store: reader, imageLoader: dependencies.imageLoader,
                                 accountAvatar: dependencies.currentAccountAvatar,
                                 readingTextSize: dependencies.featureStores.settingsStore.readingTextSize,
                                 followsGlobalReplyPreferences: target.postID == nil,
                                 onOpenMedia: dependencies.onOpenMedia, onOpenUser: { openRoute(.userProfile($0)) },
                                 onDisplayed: { await dependencies.featureStores.browsingHistoryStore.recordThread($0) },
                                 onOpenSubposts: { source in
                    if let tid = ThreadID(source.threadID), let pid = PostID(source.postID) {
                        openRoute(.subposts(threadID: tid, postID: pid))
                    }
                })
            } else if failed {
                FullPageErrorView(title: "书签位置暂不可用", message: "帖子或楼层可能已失效，也可能是网络暂时不可用。",
                                  retry: { retry &+= 1 })
                    .accessibilityIdentifier("bookmarks.target-unavailable")
            } else { InitialLoadingView(title: "正在定位书签") }
        }
        .background(SemanticColor.background)
        .task(id: retry) {
            guard !ready else { return }
            failed = false
            let loaded = await BookmarkNavigation.open(target, in: reader)
            guard !Task.isCancelled else { return }
            ready = loaded; failed = !loaded
        }
        .onDisappear { reader.cancel() }
    }
}
