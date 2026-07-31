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

    init(openDebugGallery: @escaping () -> Void = {}) {
        self.openDebugGallery = openDebugGallery
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
                    message: "阶段 05 仅提供静态占位，不读取或修改账户数据。",
                    systemImage: "gearshape"
                )

#if DEBUG
                DebugScenarioMenuView(openGallery: openDebugGallery)
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
        case let .forum(name):
            "吧占位：\(name.rawValue)"
        case let .thread(threadID):
            "帖子占位：\(threadID.rawValue)"
        case let .subposts(_, postID):
            "楼中楼占位：\(postID.rawValue)"
        }
    }

    var message: String {
        "仅使用稳定 route identity 验证系统导航，不创建业务 Store 或请求。"
    }

    var systemImage: String {
        switch self {
        case .forum:
            "rectangle.stack"
        case .thread:
            "doc.text"
        case .subposts:
            "text.bubble"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .forum:
            AppAccessibilityID.routeForum
        case .thread:
            AppAccessibilityID.routeThread
        case .subposts:
            AppAccessibilityID.routeSubposts
        }
    }
}
