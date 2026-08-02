import SwiftUI

@MainActor
struct AppShellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var navigation: AppNavigationStore
    let harnessLabel: String?
    let environment: AppEnvironment

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
                imageLoader: environment.imageLoader
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
                    imageLoader: environment.imageLoader
                )
            } else {
                IPhoneAppShellView(
                    navigation: navigation,
                    imageLoader: environment.imageLoader
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

    var body: some View {
        NavigationStack(path: settingsPathBinding) {
            SettingsPlaceholderView {
                navigation.openSettingsRoute(.componentGallery)
            } openInteractionLab: {
                navigation.openSettingsRoute(.interactionLab)
            } openThreadContentRenderer: {
                navigation.openSettingsRoute(.threadContentRendererLab)
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                SettingsRouteDestinationView(
                    route: route,
                    imageLoader: imageLoader
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

    var body: some View {
        TabView(selection: selectedTabBinding) {
            rootStack(for: .recommendations)
                .tag(AppTab.recommendations)

            rootStack(for: .followedForums)
                .tag(AppTab.followedForums)

            NavigationStack(path: settingsPathBinding) {
                SettingsPlaceholderView {
                    navigation.openSettingsRoute(.componentGallery)
                } openInteractionLab: {
#if DEBUG
                    navigation.openSettingsRoute(.interactionLab)
#endif
                } openThreadContentRenderer: {
#if DEBUG
                    navigation.openSettingsRoute(.threadContentRendererLab)
#endif
                }
                .navigationDestination(for: SettingsRoute.self) { route in
                    SettingsRouteDestinationView(
                        route: route,
                        imageLoader: imageLoader
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
            FixtureRootPlaceholderView(root: root) {
                guard let forum = ForumName("swiftui") else {
                    return
                }
                navigation.push(.forum(forum), in: root)
            }
            .navigationDestination(for: RouteIdentity.self) { route in
                AppRouter.destination(
                    for: route,
                    root: root,
                    navigation: navigation
                )
            }
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
                SettingsPlaceholderView {
                    navigation.openSettingsRoute(.componentGallery)
                } openInteractionLab: {
#if DEBUG
                    navigation.openSettingsRoute(.interactionLab)
#endif
                } openThreadContentRenderer: {
#if DEBUG
                    navigation.openSettingsRoute(.threadContentRendererLab)
#endif
                }
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let root = navigation.state.selectedTab.rootID {
            RegularDetailColumn(navigation: navigation, root: root)
        } else if let route = navigation.state.settingsPath.last {
            NavigationStack {
                SettingsRouteDestinationView(
                    route: route,
                    imageLoader: imageLoader
                )
            }
        } else {
            EmptyStateView(
                title: "设置与账户",
                message: "阶段 05 仅提供静态占位，不读取或修改账户数据。",
                systemImage: "gearshape"
            )
        }
    }

    private func rootContent(for root: RootID) -> some View {
        NavigationStack {
            FixtureRootPlaceholderView(root: root) {
                guard let forum = ForumName("swiftui") else {
                    return
                }
                navigation.replaceRootDetail(.forum(forum), in: root)
            }
        }
    }
}

@MainActor
private struct RegularDetailColumn: View {
    @Bindable var navigation: AppNavigationStore
    let root: RootID

    var body: some View {
        let projection = navigation.state.projection(for: .regular)
        if let detailRoot = projection.detailRoot {
            NavigationStack(path: detailTailBinding) {
                AppRouter.destination(
                    for: detailRoot,
                    root: root,
                    navigation: navigation
                )
                .navigationDestination(for: RouteIdentity.self) { route in
                    AppRouter.destination(
                        for: route,
                        root: root,
                        navigation: navigation
                    )
                }
            }
        } else {
            EmptyStateView(
                title: "选择一个占位项目",
                message: "阶段 05 只验证系统容器和导航状态。",
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
}

@MainActor
private struct SettingsRouteDestinationView: View {
    let route: SettingsRoute
    let imageLoader: any ImageLoading

    @ViewBuilder
    var body: some View {
        switch route {
        case .componentGallery:
#if DEBUG
            DebugComponentGalleryView()
#else
            EmptyStateView(
                title: "设置与账户",
                message: "阶段 05 仅提供静态占位。",
                systemImage: "gearshape"
            )
#endif
#if DEBUG
        case .interactionLab:
            DebugInteractionLabView()
        case .threadContentRendererLab:
            DebugThreadContentRendererLabView(imageLoader: imageLoader)
#endif
        }
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

private extension AppTab {
    var title: String {
        switch self {
        case .recommendations:
            "推荐"
        case .followedForums:
            "关注的吧"
        case .settings:
            "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .recommendations:
            "sparkles"
        case .followedForums:
            "star"
        case .settings:
            "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .recommendations:
            AppAccessibilityID.tabRecommendations
        case .followedForums:
            AppAccessibilityID.tabFollowedForums
        case .settings:
            AppAccessibilityID.tabSettings
        }
    }
}
