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
        case .forum, .subposts:
            FixtureRouteView(
                route: route,
                openThread: {
                    guard let fixtureThreadID = ThreadID(100_003) else {
                        return
                    }
                    _ = dependencies.featureStores.threadReaderStore(
                        for: root,
                        threadID: fixtureThreadID
                    )
                    navigation.push(.thread(fixtureThreadID), in: root)
                },
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
