import SwiftUI

/// Forum search shares the existing system navigation path and scoped store lifetime.
@MainActor
struct ForumHomeDestination: View {
    let forum: ForumRoute
    let scope: AppFeatureScope
    let dependencies: AppRouteDependencies
    let openRoute: (RouteIdentity) -> Void
    var openReadingRoute: ((RouteIdentity, ThreadReadingEntry) -> Void)?

    var body: some View {
        ForumHomeView(
            store: dependencies.featureStores.forumHomeStore(for: scope, route: forum),
            route: forum, imageLoader: dependencies.imageLoader,
            onOpenThread: { thread in
                guard let route = AppRouter.threadRoute(for: thread) else { return }
                if let openReadingRoute { openReadingRoute(route, .forum) } else { openRoute(route) }
            },
            onDisplayed: { await dependencies.featureStores.browsingHistoryStore.recordForum(route: forum, forum: $0) },
            onOpenSearch: {
                let loadedForum = dependencies.featureStores.forumHomeStore(for: scope, route: forum).displayedForum
                let resolved = loadedForum.flatMap { ForumRoute(forumID: $0.forumID, forumName: $0.name) } ?? forum
                openRoute(.search(scope: .forum(resolved)))
            }
        )
    }
}
