import SwiftUI

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
        switch route {
        case .search:
            SearchView(
                store: dependencies.featureStores.searchStore,
                onOpenForum: { result in
                    guard let route = forumRoute(for: result) else {
                        return
                    }
                    navigation.push(route, in: root)
                },
                onOpenThread: { result in
                    guard let route = threadRoute(for: result),
                          case let .thread(threadID) = route else {
                        return
                    }
                    _ = dependencies.featureStores.threadReaderStore(
                        for: root,
                        threadID: threadID
                    )
                    navigation.push(route, in: root)
                }
            )
        case let .thread(threadID):
            ThreadReaderView(
                store: dependencies.featureStores.threadReaderStore(
                    for: root,
                    threadID: threadID
                ),
                imageLoader: dependencies.imageLoader,
                onOpenMedia: dependencies.onOpenMedia
            )
        case let .forum(forum):
            ForumHomeView(
                store: dependencies.featureStores.forumHomeStore(
                    for: root,
                    route: forum
                ),
                route: forum,
                onOpenThread: { thread in
                    guard let route = threadRoute(for: thread) else {
                        return
                    }
                    navigation.push(route, in: root)
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
                    navigation.push(
                        .subposts(threadID: threadID, postID: postID),
                        in: root
                    )
                }
            )
        }
    }
}
