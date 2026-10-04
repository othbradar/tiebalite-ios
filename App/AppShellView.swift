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
    let notificationCounts: any NotificationCountSource
    let onOpenLogin: () -> Void
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        GeometryReader { geometry in
            // Include safe-area occlusion so the keyboard cannot change the window's aspect.
            let viewport = CGSize(
                width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
                height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            )
            let layout = AppShellPresentation.layout(
                hasRegularWidth: horizontalSizeClass == .regular, viewport: viewport
            )
            shellContent(layout: layout)
#if UITESTING
            .safeAreaInset(edge: .top, spacing: 0) {
                if let harnessLabel {
                    HStack(spacing: Spacing.small) {
                        Text("Shell")
                            .accessibilityIdentifier(AppAccessibilityID.shellRoot)
                        Text(harnessLabel)
                            .accessibilityIdentifier(AppAccessibilityID.shellScenario)
                        Text(layout == .regular ? "Layout: Regular" : "Layout: Compact")
                            .accessibilityIdentifier(
                                layout == .regular
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
#endif
        }
        .background(SemanticColor.background)
    }

    private var content: AppShellContent {
        AppShellContent(
            navigation: navigation,
            environment: environment,
            featureStores: featureStores,
            sessionStore: sessionStore,
            authContextProvider: authContextProvider,
            onOpenLogin: onOpenLogin,
            onOpenMedia: onOpenMedia
        )
    }

    @ViewBuilder
    private func shellContent(layout: AppShellLayout) -> some View {
#if DEBUG
        if navigation.state.selectedTab == .settings,
           navigation.state.settingsPath.last == .interactionLab {
            // Keep the existing interaction lab container stable across size classes.
            content.personalStack()
                .padding(.horizontal, layout == .regular ? Spacing.large : 0)
        } else {
            adaptiveShellContent(layout: layout)
        }
#else
        adaptiveShellContent(layout: layout)
#endif
    }

    @ViewBuilder
    private func adaptiveShellContent(layout: AppShellLayout) -> some View {
        if layout == .regular {
            IPadAppShellView(content: content, notificationCounts: notificationCounts)
        } else {
            IPhoneAppShellView(content: content, notificationCounts: notificationCounts)
        }
    }
}

@MainActor
private struct IPhoneAppShellView: View {
    let content: AppShellContent
    let notificationCounts: any NotificationCountSource

    var body: some View {
        // The navigation containers keep their full viewport during push/pop.
        // Each non-reading page owns its selector inset inside its own destination.
        TabView(selection: selectedTabBinding) {
            content.rootStack(for: .followedForums, notificationCounts: notificationCounts)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.followedForums)
            content.rootStack(for: .recommendations, notificationCounts: notificationCounts)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.recommendations)
            content.rootStack(for: .notifications, notificationCounts: notificationCounts)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.notifications)
            content.personalStack(notificationCounts: notificationCounts)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.settings)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .tint(SemanticColor.primaryText)
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { content.navigation.state.selectedTab },
            set: { content.navigation.selectTab($0) }
        )
    }
}

@MainActor
private struct IPadAppShellView: View {
    let content: AppShellContent
    let notificationCounts: any NotificationCountSource

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(AppTab.allCases) { tab in
                    AppSidebarItem(
                        tab: tab,
                        navigation: content.navigation,
                        notificationCounts: notificationCounts
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
        .tint(SemanticColor.primaryText)
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch content.navigation.state.selectedTab {
        case .recommendations:
            NavigationStack { content.rootContent(for: .recommendations, regular: true) }
        case .followedForums:
            NavigationStack { content.rootContent(for: .followedForums, regular: true) }
        case .notifications:
            NavigationStack { content.rootContent(for: .notifications, regular: true) }
        case .settings:
            NavigationStack { content.personalRoot }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let root = content.navigation.state.selectedTab.rootID {
            RegularDetailColumn(content: content, root: root)
        } else if content.navigation.state.selectedTab == .settings {
            NavigationStack(path: settingsDetailTailBinding) {
                if let first = content.navigation.state.settingsPath.first {
                    content.personalDestination(for: first)
                        .navigationDestination(for: SettingsRoute.self) { route in
                            content.personalDestination(for: route)
                        }
                } else {
                    // Keep an explicit empty stack so the split column cannot retain
                    // a pushed destination from the previously selected business root.
                    Text("选择资料、浏览历史或设置")
                        .foregroundStyle(SemanticColor.secondaryText)
                }
            }
        } else {
            // A message placeholder must never project the personal tab's path.
            SemanticColor.background
        }
    }

    private var settingsDetailTailBinding: Binding<[SettingsRoute]> {
        Binding(
            get: { Array(content.navigation.state.settingsPath.dropFirst()) },
            set: { tail in
                guard let first = content.navigation.state.settingsPath.first else { return }
                content.navigation.replaceSettingsPathFromSystem([first] + tail)
            }
        )
    }
}

@MainActor
private struct RegularDetailColumn: View {
    let content: AppShellContent
    let root: RootID

    var body: some View {
        let projection = content.navigation.state.projection(for: .regular)
        if let detailRoot = projection.detailRoot {
            NavigationStack(path: detailTailBinding) {
                content.businessDestination(for: detailRoot, root: root)
                    .navigationDestination(for: RouteIdentity.self) { route in
                        content.businessDestination(for: route, root: root)
                    }
            }
        } else {
            EmptyStateView(
                title: "选择内容",
                message: "从列表中选择关注的吧或动态帖子。",
                systemImage: "sidebar.right"
            )
        }
    }

    private var detailTailBinding: Binding<[RouteIdentity]> {
        Binding(
            get: { Array(content.navigation.state.routes(for: root).dropFirst()) },
            set: { content.navigation.replaceDetailTailFromSystem($0, in: root) }
        )
    }
}
