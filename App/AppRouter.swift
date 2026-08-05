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
        guard let forum = ForumRoute(forum.name) else {
            return nil
        }
        return .forum(forum)
    }

    @ViewBuilder
    static func destination(
        for route: RouteIdentity,
        root: RootID,
        navigation: AppNavigationStore,
        dependencies: AppRouteDependencies
    ) -> some View {
        switch route {
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
            ForumRouteUnavailableView(forum: forum)
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
