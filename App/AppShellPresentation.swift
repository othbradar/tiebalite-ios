import Foundation

enum AppShellPresentation {
    static func layout(hasRegularWidth: Bool, viewport: CGSize) -> AppShellLayout {
        hasRegularWidth && viewport.width > viewport.height ? .regular : .compact
    }

    static func showsPhoneTabSelector(in state: AppNavigationState) -> Bool {
        let routes: [RouteIdentity]
        if let root = state.selectedTab.rootID {
            routes = state.routes(for: root)
        } else if state.selectedTab == .settings {
            routes = state.settingsPath.compactMap {
                guard case let .content(route) = $0 else { return nil }
                return route
            }
        } else {
            routes = []
        }
        return !routes.contains { route in
            switch route {
            case .forum, .thread, .subposts: true
            case .search, .userProfile: false
            }
        }
    }
}
