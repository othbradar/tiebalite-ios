import SwiftUI

@MainActor
struct AppSettingsRootView: View {
    @Bindable var settingsStore: SettingsStore
    @Bindable var historyStore: BrowsingHistoryStore
    @Bindable var sessionStore: SessionStore
    let environment: AppEnvironment
    let authContextProvider: SessionAuthContextProvider
    let openLogin: () -> Void
    let openHistory: () -> Void
    let openAbout: () -> Void
    let openDebugGallery: () -> Void
    let openInteractionLab: () -> Void
    let openThreadContentRenderer: () -> Void

    init(
        settingsStore: SettingsStore,
        historyStore: BrowsingHistoryStore,
        openDebugGallery: @escaping () -> Void,
        openInteractionLab: @escaping () -> Void,
        openThreadContentRenderer: @escaping () -> Void,
        sessionStore: SessionStore,
        environment: AppEnvironment,
        authContextProvider: SessionAuthContextProvider,
        openLogin: @escaping () -> Void,
        openHistory: @escaping () -> Void,
        openAbout: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.openDebugGallery = openDebugGallery
        self.openInteractionLab = openInteractionLab
        self.openThreadContentRenderer = openThreadContentRenderer
        self.sessionStore = sessionStore
        self.environment = environment
        self.authContextProvider = authContextProvider
        self.openLogin = openLogin
        self.openHistory = openHistory
        self.openAbout = openAbout
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                SettingsOptionsView(
                    store: settingsStore,
                    historyStore: historyStore,
                    openHistory: openHistory,
                    openAbout: openAbout,
                    runtimeModeDescription: runtimeModeDescription
                )

                SessionAccountView(
                    store: sessionStore,
                    openLogin: openLogin
                )

#if DEBUG
                DebugAuthenticatedSessionProbeView(
                    sessionStore: sessionStore,
                    client: environment.httpClient,
                    authContextProvider: authContextProvider
                )
                DebugFollowedForumsProbeView(
                    sessionStore: sessionStore,
                    client: environment.httpClient,
                    authContextProvider: authContextProvider
                )
                DebugScenarioMenuView(
                    openGallery: openDebugGallery,
                    openInteractionLab: openInteractionLab,
                    openThreadContentRenderer: openThreadContentRenderer
                )
#endif
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, TiebaParityTokens.horizontalInset)
            .padding(.vertical, Spacing.medium)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(SemanticColor.background)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AppAccessibilityID.settingsRoot)
    }

    private var runtimeModeDescription: String? {
#if DEBUG
        switch environment.readingDataSourceMode {
        case .fixture:
            "Fixture"
        case .live:
            "Live"
        }
#else
        nil
#endif
    }
}

@MainActor
struct SettingsRouteDestinationView: View {
    let route: SettingsRoute
    @Bindable var navigation: AppNavigationStore
    let featureStores: AppFeatureStoreRegistry
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let settingsPage: () -> AppSettingsRootView

    @ViewBuilder
    var body: some View {
        switch route {
        case .preferences:
            settingsPage()
        case .accountProfile:
            if let profile = featureStores.currentAccountStore.profile,
               let profileRoute = UserProfileRoute(userID: profile.userID.rawValue, fallbackDisplayName: profile.displayName,
                                                   portraitResourceID: profile.portraitResourceID) {
                UserProfileView(imageLoader: imageLoader,
                                store: featureStores.userProfileStore(for: .settings, route: profileRoute),
                                onDisplayed: { await featureStores.browsingHistoryStore.recordUser($0) })
            } else {
                EmptyStateView(title: "暂无账户资料", message: "请返回我的页重新加载。", systemImage: "info.circle")
                    .background(SemanticColor.background)
                    .accessibilityIdentifier("personal.profile.unavailable")
            }
        case .about:
            AboutView {
                navigation.pushSettingsRoute(.licenses)
            }
        case .history:
            BrowsingHistoryView(
                store: featureStores.browsingHistoryStore,
                openRoute: navigation.pushSettingsContent
            )
        case .licenses:
            OpenSourceLicensesView()
        case let .content(contentRoute):
            AppRouter.destination(
                for: contentRoute,
                scope: .settings,
                openRoute: navigation.pushSettingsContent,
                dependencies: routeDependencies
            )
#if DEBUG
        case .componentGallery:
            DebugComponentGalleryView()
        case .interactionLab:
            DebugInteractionLabView()
        case .threadContentRendererLab:
            DebugThreadContentRendererLabView(
                imageLoader: imageLoader,
                onOpenMedia: onOpenMedia
            )
#endif
        }
    }

    private var routeDependencies: AppRouteDependencies {
        AppRouteDependencies(
            featureStores: featureStores,
            imageLoader: imageLoader,
            onOpenMedia: onOpenMedia
        )
    }
}
