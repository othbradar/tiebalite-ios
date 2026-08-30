import SwiftUI

@MainActor
struct AppShellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var navigation: AppNavigationStore
    let harnessLabel: String?
    let environment: AppEnvironment
    let featureStores: AppFeatureStoreRegistry
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let onOpenLogin: () -> Void
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        shellContent
        .safeAreaInset(edge: .top, spacing: 0) {
            if let harnessLabel {
                HStack(spacing: Spacing.small) {
                    Text("Shell")
                        .accessibilityIdentifier(AppAccessibilityID.shellRoot)
                    Text(harnessLabel)
                        .accessibilityIdentifier(
                            AppAccessibilityID.shellScenario
                        )
                    Text(
                        horizontalSizeClass == .regular
                            ? "Layout: Regular"
                            : "Layout: Compact"
                    )
                    .accessibilityIdentifier(
                        horizontalSizeClass == .regular
                            ? AppAccessibilityID.layoutRegular
                            : AppAccessibilityID.layoutCompact
                    )
                }
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xSmall)
                    .background(SemanticColor.surface)
            }
        }
        .background(SemanticColor.background)
    }

    @ViewBuilder
    private var shellContent: some View {
#if DEBUG
        if navigation.state.selectedTab == .settings,
           navigation.state.settingsPath.last == .interactionLab {
            StableInteractionLabShell(
                navigation: navigation,
                imageLoader: environment.imageLoader,
                environment: environment,
                featureStores: featureStores,
                sessionStore: sessionStore,
                authContextProvider: authContextProvider,
                onOpenLogin: onOpenLogin,
                onOpenMedia: onOpenMedia
            )
        } else {
            adaptiveShellContent
        }
#else
        adaptiveShellContent
#endif
    }

    @ViewBuilder
    private var adaptiveShellContent: some View {
            if horizontalSizeClass == .regular {
                IPadAppShellView(
                    navigation: navigation,
                    imageLoader: environment.imageLoader,
                    environment: environment,
                    featureStores: featureStores,
                    sessionStore: sessionStore,
                    authContextProvider: authContextProvider,
                    onOpenLogin: onOpenLogin,
                    onOpenMedia: onOpenMedia
                )
            } else {
                IPhoneAppShellView(
                    navigation: navigation,
                    imageLoader: environment.imageLoader,
                    environment: environment,
                    featureStores: featureStores,
                    sessionStore: sessionStore,
                    authContextProvider: authContextProvider,
                    onOpenLogin: onOpenLogin,
                    onOpenMedia: onOpenMedia
                )
            }
    }
}

#if DEBUG
@MainActor
private struct StableInteractionLabShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var navigation: AppNavigationStore
    let imageLoader: any ImageLoading
    let environment: AppEnvironment
    let featureStores: AppFeatureStoreRegistry
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let onOpenLogin: () -> Void
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        NavigationStack(path: settingsPathBinding) {
            AppSettingsRootView(
                settingsStore: featureStores.settingsStore,
                historyStore: featureStores.browsingHistoryStore,
                openDebugGallery: {
                    navigation.openSettingsRoute(.componentGallery)
                },
                openInteractionLab: {
                    navigation.openSettingsRoute(.interactionLab)
                },
                openThreadContentRenderer: {
                    navigation.openSettingsRoute(.threadContentRendererLab)
                },
                sessionStore: sessionStore,
                environment: environment,
                authContextProvider: authContextProvider,
                openLogin: onOpenLogin,
                openHistory: { navigation.openSettingsRoute(.history) },
                openAbout: { navigation.openSettingsRoute(.about) }
            )
            .navigationDestination(for: SettingsRoute.self) { route in
                SettingsRouteDestinationView(
                    route: route,
                    navigation: navigation,
                    featureStores: featureStores,
                    imageLoader: imageLoader,
                    onOpenMedia: onOpenMedia
                )
            }
        }
        .padding(
            .horizontal,
            horizontalSizeClass == .regular ? Spacing.large : 0
        )
        .background(SemanticColor.background)
    }

    private var settingsPathBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { navigation.state.settingsPath },
            set: { navigation.replaceSettingsPathFromSystem($0) }
        )
    }
}
#endif

@MainActor
private struct IPhoneAppShellView: View {
    @Bindable var navigation: AppNavigationStore
    let imageLoader: any ImageLoading
    let environment: AppEnvironment
    let featureStores: AppFeatureStoreRegistry
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let onOpenLogin: () -> Void
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        TabView(selection: selectedTabBinding) {
            rootStack(for: .recommendations)
                .tag(AppTab.recommendations)

            rootStack(for: .followedForums)
                .tag(AppTab.followedForums)

            NavigationStack(path: settingsPathBinding) {
                AppSettingsRootView(
                    settingsStore: featureStores.settingsStore,
                    historyStore: featureStores.browsingHistoryStore,
                    openDebugGallery: {
                        navigation.openSettingsRoute(.componentGallery)
                    },
                    openInteractionLab: {
#if DEBUG
                        navigation.openSettingsRoute(.interactionLab)
#endif
                    },
                    openThreadContentRenderer: {
#if DEBUG
                        navigation.openSettingsRoute(
                            .threadContentRendererLab
                        )
#endif
                    },
                    sessionStore: sessionStore,
                    environment: environment,
                    authContextProvider: authContextProvider,
                    openLogin: onOpenLogin,
                    openHistory: { navigation.openSettingsRoute(.history) },
                    openAbout: { navigation.openSettingsRoute(.about) }
                )
                .navigationDestination(for: SettingsRoute.self) { route in
                    SettingsRouteDestinationView(
                        route: route,
                        navigation: navigation,
                        featureStores: featureStores,
                        imageLoader: imageLoader,
                        onOpenMedia: onOpenMedia
                    )
                }
            }
            .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PhoneTabSelector(navigation: navigation)
        }
        .tint(SemanticColor.accent)
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { navigation.state.selectedTab },
            set: { navigation.selectTab($0) }
        )
    }

    private func pathBinding(for root: RootID) -> Binding<[RouteIdentity]> {
        Binding(
            get: { navigation.state.routes(for: root) },
            set: { navigation.replacePathFromSystem($0, in: root) }
        )
    }

    private var settingsPathBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { navigation.state.settingsPath },
            set: { navigation.replaceSettingsPathFromSystem($0) }
        )
    }

    private func rootStack(for root: RootID) -> some View {
        NavigationStack(path: pathBinding(for: root)) {
            rootContent(for: root)
            .navigationDestination(for: RouteIdentity.self) { route in
                AppRouter.destination(
                    for: route,
                    root: root,
                    navigation: navigation,
                    dependencies: routeDependencies
                )
            }
        }
    }

    private var routeDependencies: AppRouteDependencies {
        AppRouteDependencies(
            featureStores: featureStores,
            imageLoader: imageLoader,
            onOpenMedia: onOpenMedia
        )
    }

    @ViewBuilder
    private func rootContent(for root: RootID) -> some View {
        switch root {
        case .recommendations:
            RecommendationsView(
                store: featureStores.recommendationsStore,
                imageLoader: imageLoader,
                onOpenThread: { recommendation in
                    guard let route = AppRouter.threadRoute(
                        for: recommendation
                    ), case let .thread(threadID) = route else {
                        return
                    }
                    _ = featureStores.threadReaderStore(
                        for: root,
                        threadID: threadID
                    )
                    navigation.push(route, in: root)
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("搜索", systemImage: "magnifyingglass") {
                        navigation.push(.search, in: root)
                    }
                    .accessibilityIdentifier(AppAccessibilityID.openSearch)
                }
            }
        case .followedForums:
            FollowedForumsAppRootView(
                store: featureStores.followedForumsStore,
                sessionStore: sessionStore,
                authContextProvider: authContextProvider,
                openLogin: onOpenLogin,
                openRoute: { route in
                    navigation.push(route, in: root)
                }
            )
        }
    }
}

@MainActor
private struct PhoneTabSelector: View {
    @Bindable var navigation: AppNavigationStore

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SemanticColor.separator)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        navigation.selectTab(tab)
                    } label: {
                        VStack(spacing: Spacing.xSmall) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: IconSize.medium))
                            Text(tab.title)
                                .font(Typography.font(.caption))
                        }
                        .foregroundStyle(
                            navigation.state.selectedTab == tab
                                ? SemanticColor.accent
                                : SemanticColor.secondaryText
                        )
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityValue(
                        navigation.state.selectedTab == tab ? "已选择" : ""
                    )
                    .selectedAccessibilityTrait(
                        navigation.state.selectedTab == tab
                    )
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
            }
            .background(SemanticColor.surface)
        }
    }
}

@MainActor
private struct IPadAppShellView: View {
    @Bindable var navigation: AppNavigationStore
    let imageLoader: any ImageLoading
    let environment: AppEnvironment
    let featureStores: AppFeatureStoreRegistry
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let onOpenLogin: () -> Void
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        navigation.selectTab(tab)
                    } label: {
                        Label(tab.title, systemImage: tab.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityValue(
                        navigation.state.selectedTab == tab ? "已选择" : ""
                    )
                    .selectedAccessibilityTrait(
                        navigation.state.selectedTab == tab
                    )
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                    .listRowBackground(
                        navigation.state.selectedTab == tab
                            ? SemanticColor.surface
                            : Color.clear
                    )
                }
            }
            .navigationTitle("TiebaLite")
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch navigation.state.selectedTab {
        case .recommendations:
            rootContent(for: .recommendations)
        case .followedForums:
            rootContent(for: .followedForums)
        case .settings:
            NavigationStack {
                AppSettingsRootView(
                    settingsStore: featureStores.settingsStore,
                    historyStore: featureStores.browsingHistoryStore,
                    openDebugGallery: {
                        navigation.openSettingsRoute(.componentGallery)
                    },
                    openInteractionLab: {
#if DEBUG
                        navigation.openSettingsRoute(.interactionLab)
#endif
                    },
                    openThreadContentRenderer: {
#if DEBUG
                        navigation.openSettingsRoute(
                            .threadContentRendererLab
                        )
#endif
                    },
                    sessionStore: sessionStore,
                    environment: environment,
                    authContextProvider: authContextProvider,
                    openLogin: onOpenLogin,
                    openHistory: { navigation.openSettingsRoute(.history) },
                    openAbout: { navigation.openSettingsRoute(.about) }
                )
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let root = navigation.state.selectedTab.rootID {
            RegularDetailColumn(
                navigation: navigation,
                root: root,
                imageLoader: imageLoader,
                featureStores: featureStores,
                onOpenMedia: onOpenMedia
            )
        } else if !navigation.state.settingsPath.isEmpty {
            NavigationStack(path: settingsDetailTailBinding) {
                SettingsRouteDestinationView(
                    route: navigation.state.settingsPath[0],
                    navigation: navigation,
                    featureStores: featureStores,
                    imageLoader: imageLoader,
                    onOpenMedia: onOpenMedia
                )
                .navigationDestination(for: SettingsRoute.self) { child in
                    SettingsRouteDestinationView(
                        route: child,
                        navigation: navigation,
                        featureStores: featureStores,
                        imageLoader: imageLoader,
                        onOpenMedia: onOpenMedia
                    )
                }
            }
        } else {
            EmptyStateView(
                title: "设置与账户",
                message: "可在左侧管理网页登录、会话恢复与退出登录。",
                systemImage: "gearshape"
            )
        }
    }

    private var settingsDetailTailBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { Array(navigation.state.settingsPath.dropFirst()) },
            set: { tail in
                guard let root = navigation.state.settingsPath.first else {
                    navigation.replaceSettingsPathFromSystem([])
                    return
                }
                navigation.replaceSettingsPathFromSystem([root] + tail)
            }
        )
    }

    private func rootContent(for root: RootID) -> some View {
        NavigationStack {
            switch root {
            case .recommendations:
                RecommendationsView(
                    store: featureStores.recommendationsStore,
                    imageLoader: imageLoader,
                    onOpenThread: { recommendation in
                        guard let route = AppRouter.threadRoute(
                            for: recommendation
                        ), case let .thread(threadID) = route else {
                            return
                        }
                        _ = featureStores.threadReaderStore(
                            for: root,
                            threadID: threadID
                        )
                        navigation.replaceRootDetail(route, in: root)
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("搜索", systemImage: "magnifyingglass") {
                            navigation.replaceRootDetail(.search, in: root)
                        }
                        .accessibilityIdentifier(
                            AppAccessibilityID.openSearch
                        )
                    }
                }
            case .followedForums:
                FollowedForumsAppRootView(
                    store: featureStores.followedForumsStore,
                    sessionStore: sessionStore,
                    authContextProvider: authContextProvider,
                    openLogin: onOpenLogin,
                    openRoute: { route in
                        navigation.replaceRootDetail(route, in: root)
                    }
                )
            }
        }
    }
}

@MainActor
private struct RegularDetailColumn: View {
    @Bindable var navigation: AppNavigationStore
    let root: RootID
    let imageLoader: any ImageLoading
    let featureStores: AppFeatureStoreRegistry
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        let projection = navigation.state.projection(for: .regular)
        if let detailRoot = projection.detailRoot {
            NavigationStack(path: detailTailBinding) {
                AppRouter.destination(
                    for: detailRoot,
                    root: root,
                    navigation: navigation,
                    dependencies: routeDependencies
                )
                .navigationDestination(for: RouteIdentity.self) { route in
                    AppRouter.destination(
                        for: route,
                        root: root,
                        navigation: navigation,
                        dependencies: routeDependencies
                    )
                }
            }
        } else {
            EmptyStateView(
                title: "选择内容",
                message: "从列表中选择关注的吧或推荐帖子。",
                systemImage: "sidebar.right"
            )
        }
    }

    private var detailTailBinding: Binding<[RouteIdentity]> {
        Binding(
            get: {
                navigation.state.projection(for: .regular).detailTail
            },
            set: {
                navigation.replaceDetailTailFromSystem($0, in: root)
            }
        )
    }

    private var routeDependencies: AppRouteDependencies {
        AppRouteDependencies(
            featureStores: featureStores,
            imageLoader: imageLoader,
            onOpenMedia: onOpenMedia
        )
    }
}

private extension View {
    @ViewBuilder
    func selectedAccessibilityTrait(_ isSelected: Bool) -> some View {
        if isSelected {
            accessibilityAddTraits(.isSelected)
        } else {
            self
        }
    }
}
