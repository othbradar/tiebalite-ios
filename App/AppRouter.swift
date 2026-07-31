import SwiftUI

@MainActor
enum AppRouter {
    static func destination(
        for route: RouteIdentity,
        root: RootID,
        navigation: AppNavigationStore
    ) -> some View {
        FixtureRouteView(
            route: route,
            openThread: {
                guard let threadID = ThreadID(1_001) else {
                    return
                }
                navigation.push(.thread(threadID), in: root)
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
