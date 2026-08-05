import SwiftUI

@MainActor
struct FollowedForumsAppRootView: View {
    @Bindable var store: FollowedForumsStore
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let openLogin: () -> Void
    let openRoute: (RouteIdentity) -> Void

    var body: some View {
        FollowedForumsView(
            store: store,
            sessionAccess: sessionAccess,
            openLogin: openLogin,
            openForum: { forum in
                guard let route = AppRouter.forumRoute(for: forum) else {
                    return
                }
                openRoute(route)
            }
        )
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
