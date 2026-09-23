extension AppTab {
    var title: String {
        switch self {
        case .recommendations:
            return "动态"
        case .followedForums:
            return "首页"
        case .notifications:
            return "消息"
        case .settings:
            return "我的"
        }
    }

    var iconAssetName: String {
        switch self {
        case .followedForums: "root-home"
        case .recommendations: "root-dynamic"
        case .notifications: "root-messages"
        case .settings: "root-personal"
        }
    }

    var systemImage: String {
        switch self {
        case .recommendations:
            return "fanblades"
        case .followedForums:
            return "archivebox"
        case .notifications:
            return "bell"
        case .settings:
            return "person"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .recommendations:
            return AppAccessibilityID.tabRecommendations
        case .followedForums:
            return AppAccessibilityID.tabFollowedForums
        case .notifications:
            return AppAccessibilityID.tabNotifications
        case .settings:
            return AppAccessibilityID.tabSettings
        }
    }
}
