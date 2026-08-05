extension AppTab {
    var title: String {
        switch self {
        case .recommendations:
            return "推荐"
        case .followedForums:
            return "关注的吧"
        case .settings:
            return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .recommendations:
            return "sparkles"
        case .followedForums:
            return "star"
        case .settings:
            return "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .recommendations:
            return AppAccessibilityID.tabRecommendations
        case .followedForums:
            return AppAccessibilityID.tabFollowedForums
        case .settings:
            return AppAccessibilityID.tabSettings
        }
    }
}
