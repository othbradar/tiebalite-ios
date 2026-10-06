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

    @MainActor var currentAccountAvatar: ImageResourceDescriptor? {
        featureStores.currentAccountStore.profile.flatMap {
            TiebaAvatarResource.user(userID: $0.userID.rawValue, portrait: $0.portraitResourceID)
        }
    }
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
        Group {
            switch route {
            case let .notification(target):
                if let store = dependencies.featureStores.notificationDestination(for: target) {
                    NotificationDestination(store: store, dependencies: dependencies, openRoute: openRoute)
                }
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
                    accountAvatar: dependencies.currentAccountAvatar,
                    readingTextSize:
                        dependencies.featureStores.settingsStore.readingTextSize,
                    onOpenMedia: dependencies.onOpenMedia,
                    onOpenUser: { openRoute(.userProfile($0)) },
                    onDisplayed: {
                        await dependencies.featureStores.browsingHistoryStore
                            .recordThread($0)
                    },
                    onOpenSubposts: { source in
                        guard let threadID = ThreadID(source.threadID), let postID = PostID(source.postID) else { return }
                        openRoute(.subposts(threadID: threadID, postID: postID))
                    }
                )
            case let .forum(forum):
                ForumHomeDestination(
                    forum: forum, scope: scope, dependencies: dependencies, openRoute: openRoute
                )
                .ignoresSafeArea(.container, edges: .bottom)
            case let .userProfile(profileRoute):
                UserProfileView(
                    imageLoader: dependencies.imageLoader,
                    store: dependencies.featureStores.userProfileStore(
                        for: scope,
                        route: profileRoute
                    ),
                    onDisplayed: {
                        await dependencies.featureStores.browsingHistoryStore
                            .recordUser($0)
                    }
                )
            case let .subposts(threadID, postID):
                if let store = dependencies.featureStores.subpostsStore(
                    for: scope,
                    route: .init(threadID: threadID.rawValue, postID: postID.rawValue)) {
                    SubpostsView(
                        store: store, imageLoader: dependencies.imageLoader,
                        readingTextSize: dependencies.featureStores.settingsStore.readingTextSize,
                        onOpenMedia: dependencies.onOpenMedia, onOpenUser: { openRoute(.userProfile($0)) })
                        .ignoresSafeArea(.container, edges: .bottom)
                } else {
                    SubpostsUnavailableView(threadID: threadID, postID: postID)
                }
            }
        }
        .environment(\.openURL, ContentLinkHandler.action(openRoute: openRoute))
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
