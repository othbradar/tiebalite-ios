import SwiftUI

/// Search has its own system sheet path so the owning forum/list remains mounted.
@MainActor
struct ForumHomeDestination: View {
    let forum: ForumRoute
    let scope: AppFeatureScope
    let dependencies: AppRouteDependencies
    let openRoute: (RouteIdentity) -> Void
    var openReadingRoute: ((RouteIdentity, ThreadReadingEntry) -> Void)?
    @State private var searchPresented = false
    @State private var searchPath: [RouteIdentity] = []
    @State private var searchEntries: [RouteIdentity: ThreadReadingEntry] = [:]

    var body: some View {
        ForumHomeView(
            store: dependencies.featureStores.forumHomeStore(for: scope, route: forum),
            route: forum, imageLoader: dependencies.imageLoader,
            onOpenThread: { thread in
                guard let route = AppRouter.threadRoute(for: thread) else { return }
                if let openReadingRoute { openReadingRoute(route, .forum) } else { openRoute(route) }
            },
            onDisplayed: { await dependencies.featureStores.browsingHistoryStore.recordForum(route: forum, forum: $0) },
            onOpenSearch: { searchPresented = true }
        )
        .sheet(isPresented: $searchPresented, onDismiss: { searchPath = []; searchEntries = [:] }, content: {
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
        .onChange(of: searchPath) { _, path in searchEntries = searchEntries.filter { path.contains($0.key) } }
    }

    private func searchDestination(_ route: RouteIdentity) -> some View {
        ForumSearchDestination(
            route: route, scope: scope, dependencies: dependencies,
            openRoute: { searchEntries[$0] = .unspecified; searchPath.append($0) },
            readingEntry: searchEntries[route] ?? .unspecified,
            openReadingRoute: { route, entry in searchEntries[route] = entry; searchPath.append(route) }
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
    let readingEntry: ThreadReadingEntry
    let openReadingRoute: (RouteIdentity, ThreadReadingEntry) -> Void

    var body: some View {
        AppRouter.destination(for: route, scope: scope, openRoute: openRoute, dependencies: dependencies,
                              readingEntry: readingEntry, openReadingRoute: openReadingRoute)
    }
}
