import SwiftUI

/// The two shell projections reuse the same scene-owned navigation and feature stores.
@MainActor
struct AppShellContent {
    let navigation: AppNavigationStore
    let environment: AppEnvironment
    let featureStores: AppFeatureStoreRegistry
    let sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let onOpenLogin: () -> Void
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var personalRoot: some View {
        AppPersonalRootView(
            sessionStore: sessionStore,
            openLogin: onOpenLogin,
            openRoute: navigation.openSettingsRoute
        )
    }

    var personalStack: some View {
        NavigationStack(path: Binding(
            get: { navigation.state.settingsPath },
            set: { navigation.replaceSettingsPathFromSystem($0) }
        )) {
            personalRoot
                .navigationDestination(for: SettingsRoute.self) { route in
                    personalDestination(for: route)
                }
        }
    }

    func personalDestination(for route: SettingsRoute) -> some View {
        SettingsRouteDestinationView(
            route: route,
            navigation: navigation,
            featureStores: featureStores,
            imageLoader: environment.imageLoader,
            onOpenMedia: onOpenMedia,
            settingsPage: { settingsPage }
        )
    }

    private var settingsPage: AppSettingsRootView {
        AppSettingsRootView(
            settingsStore: featureStores.settingsStore,
            historyStore: featureStores.browsingHistoryStore,
            openDebugGallery: {
#if DEBUG
                navigation.pushSettingsRoute(.componentGallery)
#endif
            },
            openInteractionLab: {
#if DEBUG
                navigation.pushSettingsRoute(.interactionLab)
#endif
            },
            openThreadContentRenderer: {
#if DEBUG
                navigation.pushSettingsRoute(.threadContentRendererLab)
#endif
            },
            sessionStore: sessionStore,
            environment: environment,
            authContextProvider: authContextProvider,
            openLogin: onOpenLogin,
            openHistory: { navigation.pushSettingsRoute(.history) },
            openAbout: { navigation.pushSettingsRoute(.about) }
        )
    }

    func rootStack(for root: RootID) -> some View {
        NavigationStack(path: Binding(
            get: { navigation.state.routes(for: root) },
            set: { navigation.replacePathFromSystem($0, in: root) }
        )) {
            rootContent(for: root, regular: false)
                .navigationDestination(for: RouteIdentity.self) { route in
                    businessDestination(for: route, root: root)
                }
        }
    }

    func businessDestination(for route: RouteIdentity, root: RootID) -> some View {
        AppRouter.destination(
            for: route,
            root: root,
            navigation: navigation,
            dependencies: AppRouteDependencies(
                featureStores: featureStores,
                imageLoader: environment.imageLoader,
                onOpenMedia: onOpenMedia
            )
        )
    }

    @ViewBuilder
    func rootContent(for root: RootID, regular: Bool) -> some View {
        switch root {
        case .recommendations:
            RecommendationsAppRootView(
                store: featureStores.recommendationsStore,
                sessionStore: sessionStore,
                authContextProvider: authContextProvider,
                accessPolicy: environment.recommendationsAccessPolicy,
                imageLoader: environment.imageLoader,
                openLogin: onOpenLogin,
                onOpenThread: { recommendation in
                    guard let route = AppRouter.threadRoute(for: recommendation),
                          case let .thread(threadID) = route else { return }
                    _ = featureStores.threadReaderStore(for: root, threadID: threadID)
                    open(route, in: root, regular: regular)
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("搜索", systemImage: "magnifyingglass") {
                        open(.search, in: root, regular: regular)
                    }
                    .accessibilityIdentifier(AppAccessibilityID.openSearch)
                }
                .tiebaFlatToolbarItem()
            }
        case .followedForums:
            FollowedForumsAppRootView(
                store: featureStores.followedForumsStore,
                sessionStore: sessionStore,
                historyStore: featureStores.browsingHistoryStore,
                authContextProvider: authContextProvider,
                imageLoader: environment.imageLoader,
                openLogin: onOpenLogin,
                openRoute: { open($0, in: root, regular: regular) }
            )
        }
    }

    private func open(_ route: RouteIdentity, in root: RootID, regular: Bool) {
        if regular {
            navigation.replaceRootDetail(route, in: root)
        } else {
            navigation.push(route, in: root)
        }
    }
}
