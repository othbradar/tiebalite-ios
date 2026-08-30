import Foundation
import Observation

@MainActor
@Observable
final class AppNavigationStore {
    private(set) var state: AppNavigationState

    init(initialState: AppNavigationState = AppNavigationState()) {
        state = initialState
    }

    func selectTab(_ tab: AppTab) {
        guard state.selectedTab != tab else {
            return
        }
        state.selectTab(tab)
    }

    @discardableResult
    func push(_ route: RouteIdentity, in root: RootID) -> Bool {
        var candidate = state.routes(for: root)
        if let existingIndex = candidate.firstIndex(of: route) {
            candidate = Array(candidate.prefix(through: existingIndex))
        } else {
            candidate.append(route)
        }
        return replaceRoutes(candidate, in: root)
    }

    @discardableResult
    func replaceRootDetail(_ route: RouteIdentity, in root: RootID) -> Bool {
        return replaceRoutes([route], in: root)
    }

    @discardableResult
    func replacePathFromSystem(
        _ routes: [RouteIdentity],
        in root: RootID
    ) -> Bool {
        return replaceRoutes(routes, in: root)
    }

    @discardableResult
    func replaceDetailTailFromSystem(
        _ tail: [RouteIdentity],
        in root: RootID
    ) -> Bool {
        guard let detailRoot = state.routes(for: root).first else {
            return tail.isEmpty
        }
        return replaceRoutes([detailRoot] + tail, in: root)
    }

    func openSettingsRoute(_ route: SettingsRoute) {
        state.replaceSettingsPath([route])
    }

    @discardableResult
    func pushSettingsRoute(_ route: SettingsRoute) -> Bool {
        var candidate = state.settingsPath
        if let existingIndex = candidate.firstIndex(of: route) {
            candidate = Array(candidate.prefix(through: existingIndex))
        } else {
            candidate.append(route)
        }
        let canonical = SettingsRouteGrammar.canonical(candidate)
        guard canonical == candidate else {
            return false
        }
        state.replaceSettingsPath(candidate)
        return true
    }

    func pushSettingsContent(_ route: RouteIdentity) {
        pushSettingsRoute(.content(route))
    }

    func replaceSettingsPathFromSystem(_ path: [SettingsRoute]) {
        state.replaceSettingsPath(path)
    }

    @discardableResult
    func apply(_ command: NavigationCommand) -> Bool {
        switch command {
        case let .replaceRootDetail(root, route):
            guard RouteGrammar.isValid([route], for: root) else {
                return false
            }
            state.replaceRoutes([route], for: root)
            state.selectTab(root.tab)
            return true
        }
    }

    @discardableResult
    func handleExternalURL(_ url: URL) -> Bool {
        guard let command = DeepLinkParser.parse(url) else {
            return false
        }
        return apply(command)
    }

    private func replaceRoutes(
        _ routes: [RouteIdentity],
        in root: RootID
    ) -> Bool {
        guard RouteGrammar.isValid(routes, for: root) else {
            return false
        }
        state.replaceRoutes(routes, for: root)
        return true
    }
}
