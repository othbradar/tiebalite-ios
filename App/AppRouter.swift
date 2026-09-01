import SwiftUI

enum AppFeatureScope: Hashable, Sendable {
    case root(RootID)
    case settings
}

@MainActor
struct AppRouteDependencies {
    let featureStores: AppFeatureStoreRegistry
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void
}

@MainActor
enum AppRouter {
    static func threadRoute(
        for recommendation: RecommendationSummary
    ) -> RouteIdentity? {
        guard let threadID = ThreadID(recommendation.threadID) else {
            return nil
        }
        return .thread(threadID)
    }

    static func forumRoute(for forum: FollowedForum) -> RouteIdentity? {
        guard let forum = ForumRoute(
            forumID: forum.forumID,
            forumName: forum.name
        ) else {
            return nil
        }
        return .forum(forum)
    }

    static func forumRoute(
        for result: ForumSearchResult
    ) -> RouteIdentity? {
        guard let forum = ForumRoute(
            forumID: result.forumID,
            forumName: result.name
        ) else {
            return nil
        }
        return .forum(forum)
    }

    static func threadRoute(
        for thread: ForumThreadSummary
    ) -> RouteIdentity? {
        guard let threadID = ThreadID(thread.threadID) else {
            return nil
        }
        return .thread(threadID)
    }

    static func threadRoute(
        for result: ThreadSearchResult
    ) -> RouteIdentity? {
        guard let threadID = ThreadID(result.threadID) else {
            return nil
        }
        return .thread(threadID)
    }

    @ViewBuilder
    static func destination(
        for route: RouteIdentity,
        root: RootID,
        navigation: AppNavigationStore,
        dependencies: AppRouteDependencies
    ) -> some View {
        destination(
            for: route,
            scope: .root(root),
            openRoute: { navigation.push($0, in: root) },
            dependencies: dependencies
        )
    }

    @ViewBuilder
    static func destination(
        for route: RouteIdentity,
        scope: AppFeatureScope,
        openRoute: @escaping (RouteIdentity) -> Void,
        dependencies: AppRouteDependencies
    ) -> some View {
        switch route {
        case .search:
            searchDestination(
                scope: scope,
                openRoute: openRoute,
                dependencies: dependencies
            )
        case let .thread(threadID):
            ThreadReaderView(
                store: dependencies.featureStores.threadReaderStore(
                    for: scope,
                    threadID: threadID
                ),
                imageLoader: dependencies.imageLoader,
                readingTextSize:
                    dependencies.featureStores.settingsStore.readingTextSize,
                onOpenMedia: dependencies.onOpenMedia,
                onOpenUser: { openRoute(.userProfile($0)) },
                onDisplayed: {
                    await dependencies.featureStores.browsingHistoryStore
                        .recordThread($0)
                }
            )
        case let .forum(forum):
            ForumHomeView(
                store: dependencies.featureStores.forumHomeStore(
                    for: scope,
                    route: forum
                ),
                route: forum,
                imageLoader: dependencies.imageLoader,
                onOpenThread: { thread in
                    guard let route = threadRoute(for: thread) else {
                        return
                    }
                    openRoute(route)
                },
                onDisplayed: {
                    await dependencies.featureStores.browsingHistoryStore
                        .recordForum(route: forum, forum: $0)
                }
            )
        case let .userProfile(profileRoute):
            UserProfileView(
                store: dependencies.featureStores.userProfileStore(
                    for: scope,
                    route: profileRoute
                ),
                onDisplayed: {
                    await dependencies.featureStores.browsingHistoryStore
                        .recordUser($0)
                }
            )
        case .subposts:
            FixtureRouteView(
                route: route,
                openThread: {},
                openSubposts: { threadID in
                    guard let postID = PostID(2_001) else {
                        return
                    }
                    openRoute(
                        .subposts(threadID: threadID, postID: postID)
                    )
                }
            )
        }
    }

    private static func searchDestination(
        scope: AppFeatureScope,
        openRoute: @escaping (RouteIdentity) -> Void,
        dependencies: AppRouteDependencies
    ) -> some View {
        SearchView(
            store: dependencies.featureStores.searchStore,
            onOpenForum: { result in
                guard let route = forumRoute(for: result) else {
                    return
                }
                openRoute(route)
            },
            onOpenThread: { result in
                guard let route = threadRoute(for: result),
                      case let .thread(threadID) = route else {
                    return
                }
                _ = dependencies.featureStores.threadReaderStore(
                    for: scope,
                    threadID: threadID
                )
                openRoute(route)
            }
        )
    }
}
