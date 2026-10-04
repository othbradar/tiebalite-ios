import SwiftUI

@MainActor
struct FollowedForumsAppRootView: View {
    @Bindable var accountStore: CurrentAccountStore
    @Bindable var store: FollowedForumsStore
    @Bindable var sessionStore: SessionStore
    @Bindable var historyStore: BrowsingHistoryStore
    let authContextProvider: SessionAuthContextProvider
    let imageLoader: any ImageLoading
    let openLogin: () -> Void
    let openRoute: (RouteIdentity) -> Void

    var body: some View {
        FollowedForumsView(
            store: store,
            sessionAccess: sessionAccess,
            imageLoader: imageLoader,
            accountAvatar: accountStore.profile.flatMap {
                TiebaAvatarResource.user(userID: $0.userID.rawValue, portrait: $0.portraitResourceID)
            },
            recentForums: RecentForum.project(historyStore.entries, followedForums: store.state.retainedForums),
            openLogin: openLogin,
            openSearch: { openRoute(.search) },
            openForum: { forum in
                guard let route = AppRouter.forumRoute(for: forum) else {
                    return
                }
                openRoute(route)
            },
            openRecentForum: { openRoute(.forum($0)) },
            removeRecentForum: { forumID in Task { await historyStore.delete(.forum(forumID)) } }
        )
        .task { await historyStore.loadIfNeeded() }
        .task(id: sessionStore.state) {
            accountStore.updateContext(authContextProvider.context())
            await accountStore.loadIfNeeded()
        }
    }

    private var sessionAccess: FollowedForumsSessionAccess {
        switch sessionStore.state {
        case .expired:
            return .expired
        case .signingIn:
            return .signingIn
        case .signedIn:
            let context = authContextProvider.context()
            guard case .active = context else {
                return .signedOut
            }
            return .active(context)
        case .failed, .signedOut, .signingOut:
            return .signedOut
        }
    }
}
