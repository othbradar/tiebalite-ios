import SwiftUI

@MainActor
struct FixtureRootPlaceholderView: View {
    let root: RootID
    let openForum: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                Text("TiebaLite")
                    .font(Typography.font(.largeTitle))
                    .foregroundStyle(SemanticColor.primaryText)
                    .accessibilityIdentifier(AppAccessibilityID.shellTitle)

                EmptyStateView(
                    title: root.title,
                    message: root.message,
                    systemImage: root.systemImage
                )

                Button("打开示例吧", action: openForum)
                    .buttonStyle(.borderedProminent)
                    .tint(SemanticColor.accent)
                    .accessibilityIdentifier(AppAccessibilityID.openForum)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .navigationTitle(root.title)
        .accessibilityIdentifier(root.accessibilityIdentifier)
    }
}

@MainActor
struct SettingsPlaceholderView: View {
    let openDebugGallery: () -> Void
    let openInteractionLab: () -> Void
    let openThreadContentRenderer: () -> Void
    @Bindable var sessionStore: SessionStore
    let authContextProvider: SessionAuthContextProvider
    let httpClient: any HTTPClient
    let openLogin: () -> Void

    init(
        openDebugGallery: @escaping () -> Void = {},
        openInteractionLab: @escaping () -> Void = {},
        openThreadContentRenderer: @escaping () -> Void = {},
        sessionStore: SessionStore,
        authContextProvider: SessionAuthContextProvider,
        httpClient: any HTTPClient,
        openLogin: @escaping () -> Void = {}
    ) {
        self.openDebugGallery = openDebugGallery
        self.openInteractionLab = openInteractionLab
        self.openThreadContentRenderer = openThreadContentRenderer
        self.sessionStore = sessionStore
        self.authContextProvider = authContextProvider
        self.httpClient = httpClient
        self.openLogin = openLogin
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                Text("TiebaLite")
                    .font(Typography.font(.largeTitle))
                    .foregroundStyle(SemanticColor.primaryText)
                    .accessibilityIdentifier(AppAccessibilityID.shellTitle)

                EmptyStateView(
                    title: "设置与账户",
                    message: "网页登录仅由用户手工操作，App 不读取或保存密码。",
                    systemImage: "gearshape"
                )

                SessionAccountView(
                    store: sessionStore,
                    openLogin: openLogin
                )

#if DEBUG
                DebugAuthenticatedSessionProbeView(
                    sessionStore: sessionStore,
                    client: httpClient,
                    authContextProvider: authContextProvider
                )

                DebugFollowedForumsProbeView(
                    sessionStore: sessionStore,
                    client: httpClient,
                    authContextProvider: authContextProvider
                )
#endif

#if DEBUG
                DebugScenarioMenuView(
                    openGallery: openDebugGallery,
                    openInteractionLab: openInteractionLab,
                    openThreadContentRenderer: openThreadContentRenderer
                )
#endif
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .navigationTitle("设置")
        .accessibilityIdentifier(AppAccessibilityID.settingsRoot)
    }
}

@MainActor
struct FixtureRouteView: View {
    let route: RouteIdentity
    let openThread: () -> Void
    let openSubposts: (ThreadID) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                EmptyStateView(
                    title: route.title,
                    message: route.message,
                    systemImage: route.systemImage
                )

                switch route {
                case .forum:
                    Button("打开示例帖子", action: openThread)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(AppAccessibilityID.openThread)
                case let .thread(threadID):
                    Button("打开示例楼中楼") {
                        openSubposts(threadID)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AppAccessibilityID.openSubposts)
                case .subposts:
                    EmptyView()
                case .search:
                    EmptyView()
                case .userProfile:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .navigationTitle(route.title)
        .accessibilityIdentifier(route.accessibilityIdentifier)
    }
}

@MainActor
struct ForumRouteUnavailableView: View {
    let forum: ForumRoute

    var body: some View {
        EmptyStateView(
            title: "\(forum.forumName.rawValue)吧",
            message: "吧首页暂未开放，将在后续版本提供。",
            systemImage: "rectangle.stack"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle(forum.forumName.rawValue)
        .accessibilityIdentifier(AppAccessibilityID.routeForum)
    }
}

private extension RootID {
    var title: String {
        switch self {
        case .recommendations:
            "推荐"
        case .followedForums:
            "关注的吧"
        }
    }

    var message: String {
        switch self {
        case .recommendations:
            "固定占位用于验证独立导航路径，不接入贴吧数据。"
        case .followedForums:
            "固定占位用于验证跨 Tab 状态保持，不读取登录态。"
        }
    }

    var systemImage: String {
        switch self {
        case .recommendations:
            "sparkles"
        case .followedForums:
            "star"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .recommendations:
            AppAccessibilityID.recommendationsRoot
        case .followedForums:
            AppAccessibilityID.followedForumsRoot
        }
    }
}

private extension RouteIdentity {
    var title: String {
        switch self {
        case let .forum(route):
            "吧占位：\(route.forumName.rawValue)"
        case .search:
            "搜索"
        case let .thread(threadID):
            "帖子占位：\(threadID.rawValue)"
        case let .subposts(_, postID):
            "楼中楼占位：\(postID.rawValue)"
        case let .userProfile(route):
            "用户占位：\(route.fallbackDisplayName)"
        }
    }

    var message: String {
        "仅使用稳定 route identity 验证系统导航，不创建业务 Store 或请求。"
    }

    var systemImage: String {
        switch self {
        case .forum:
            "rectangle.stack"
        case .search:
            "magnifyingglass"
        case .thread:
            "doc.text"
        case .subposts:
            "text.bubble"
        case .userProfile:
            "person.crop.circle"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .forum:
            AppAccessibilityID.routeForum
        case .search:
            AppAccessibilityID.routeSearch
        case .thread:
            AppAccessibilityID.routeThread
        case .subposts:
            AppAccessibilityID.routeSubposts
        case .userProfile:
            "route.user-profile"
        }
    }
}
