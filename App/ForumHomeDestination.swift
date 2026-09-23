import SwiftUI

/// Search has its own system sheet path so the owning forum/list remains mounted.
@MainActor
struct ForumHomeDestination: View {
    let forum: ForumRoute
    let scope: AppFeatureScope
    let dependencies: AppRouteDependencies
    let openRoute: (RouteIdentity) -> Void
    @State private var searchPresented = false
    @State private var searchPath: [RouteIdentity] = []

    var body: some View {
        ForumHomeView(
            store: dependencies.featureStores.forumHomeStore(for: scope, route: forum),
            route: forum, imageLoader: dependencies.imageLoader,
            onOpenThread: { thread in
                guard let route = AppRouter.threadRoute(for: thread) else { return }
                openRoute(route)
            },
            onDisplayed: { await dependencies.featureStores.browsingHistoryStore.recordForum(route: forum, forum: $0) },
            onOpenSearch: { searchPresented = true }
        )
        .sheet(isPresented: $searchPresented, onDismiss: { searchPath = [] }, content: {
            NavigationStack(path: $searchPath) {
                searchDestination(.search)
                    .navigationDestination(for: RouteIdentity.self) { searchDestination($0) }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { searchPresented = false }
                                .accessibilityIdentifier("forum-home.search.close")
                        }
                    }
            }
        })
    }

    private func searchDestination(_ route: RouteIdentity) -> some View {
        ForumSearchDestination(
            route: route, scope: scope, dependencies: dependencies, openRoute: { searchPath.append($0) }
        )
    }
}

/// A named destination keeps the recursive route graph concrete across the sheet boundary.
@MainActor
private struct ForumSearchDestination: View {
    let route: RouteIdentity
    let scope: AppFeatureScope
    let dependencies: AppRouteDependencies
    let openRoute: (RouteIdentity) -> Void

    var body: some View {
        AppRouter.destination(for: route, scope: scope, openRoute: openRoute, dependencies: dependencies)
    }
}
