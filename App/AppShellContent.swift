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
            accountStore: featureStores.currentAccountStore,
            settingsStore: featureStores.settingsStore,
            imageLoader: environment.imageLoader,
            authContextProvider: authContextProvider,
            sessionStore: sessionStore,
            openLogin: onOpenLogin,
            openRoute: navigation.openSettingsRoute
        )
    }

    func personalStack(notificationCounts: (any NotificationCountSource)? = nil) -> some View {
        NavigationStack(path: Binding(
            get: { navigation.state.settingsPath },
            set: { navigation.replaceSettingsPathFromSystem($0) }
        )) {
            personalRoot
                .safeAreaInset(edge: .bottom, spacing: 0) { phoneSelector(notificationCounts, atRoot: true) }
                .navigationDestination(for: SettingsRoute.self) { route in
                    personalDestination(for: route)
                        .safeAreaInset(edge: .bottom, spacing: 0) { phoneSelector(notificationCounts) }
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

    func rootStack(for root: RootID, notificationCounts: (any NotificationCountSource)? = nil) -> some View {
        NavigationStack(path: Binding(
            get: { navigation.state.routes(for: root) },
            set: { navigation.replacePathFromSystem($0, in: root) }
        )) {
            rootContent(for: root, regular: false)
                .safeAreaInset(edge: .bottom, spacing: 0) { phoneSelector(notificationCounts, atRoot: true) }
                .navigationDestination(for: RouteIdentity.self) { route in
                    businessDestination(for: route, root: root)
                        .safeAreaInset(edge: .bottom, spacing: 0) { phoneSelector(notificationCounts) }
                }
        }
    }

    @ViewBuilder
    private func phoneSelector(_ counts: (any NotificationCountSource)?, atRoot: Bool = false) -> some View {
        if let counts, atRoot || AppShellPresentation.showsPhoneTabSelector(in: navigation.state) {
            PhoneTabSelector(navigation: navigation, notificationCounts: counts)
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
        case .notifications:
            NotificationsView(store: featureStores.notificationsStore, imageLoader: environment.imageLoader,
                              openLogin: onOpenLogin, openTarget: { target, kind in
                                  open(.notification(target), in: root, regular: regular,
                                       readingEntry: .notification(kind, opensQuotedThread: false))
                              }, openThread: { rawID, kind in
                                  guard let threadID = ThreadID(rawID) else { return }
                                  open(.thread(threadID), in: root, regular: regular,
                                       readingEntry: .notification(kind, opensQuotedThread: true))
                              })
        case .recommendations:
            RecommendationsAppRootView(
                store: featureStores.recommendationsStore,
                sessionStore: sessionStore,
                authContextProvider: authContextProvider,
                accessPolicy: environment.recommendationsAccessPolicy,
                imageLoader: environment.imageLoader,
                openLogin: onOpenLogin,
                onOpenUser: { open(.userProfile($0), in: root, regular: regular) },
                onOpenThread: { recommendation in
                    guard let route = AppRouter.threadRoute(for: recommendation),
                          case let .thread(threadID) = route else { return }
                    _ = featureStores.threadReaderStore(for: root, threadID: threadID)
                    open(route, in: root, regular: regular, readingEntry: .recommendations)
                }
            )
            .environment(\.openURL, ContentLinkHandler.action { open($0, in: root, regular: regular, readingEntry: .contentLink) })
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
                accountStore: featureStores.currentAccountStore,
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

    private func open(_ route: RouteIdentity, in root: RootID, regular: Bool, readingEntry: ThreadReadingEntry = .unspecified) {
        if regular {
            navigation.replaceRootDetail(route, in: root, readingEntry: readingEntry)
        } else {
            navigation.push(route, in: root, readingEntry: readingEntry)
        }
    }
}
