import Foundation
import Observation

@MainActor
@Observable
final class AppNavigationStore {
    private(set) var state: AppNavigationState
    private var readingEntries: [AppFeatureScope: [RouteIdentity: ThreadReadingEntry]] = [:]

    func readingEntry(for route: RouteIdentity, scope: AppFeatureScope) -> ThreadReadingEntry {
        readingEntries[scope]?[route] ?? .unspecified
    }

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
    func push(_ route: RouteIdentity, in root: RootID, readingEntry: ThreadReadingEntry = .unspecified) -> Bool {
        var candidate = state.routes(for: root)
        if let existingIndex = candidate.firstIndex(of: route) {
            candidate = Array(candidate.prefix(through: existingIndex))
        } else {
            candidate.append(route)
        }
        guard replaceRoutes(candidate, in: root) else { return false }
        recordReadingEntry(readingEntry, route: route, scope: .root(root))
        return true
    }

    @discardableResult
    func replaceRootDetail(_ route: RouteIdentity, in root: RootID, readingEntry: ThreadReadingEntry = .unspecified) -> Bool {
        guard replaceRoutes([route], in: root) else { return false }
        recordReadingEntry(readingEntry, route: route, scope: .root(root))
        return true
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
        readingEntries[.settings] = [:]
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
        pruneSettingsReadingEntries()
        return true
    }

    func pushSettingsContent(_ route: RouteIdentity) {
        pushSettingsContent(route, readingEntry: .unspecified)
    }

    func pushSettingsContent(_ route: RouteIdentity, readingEntry: ThreadReadingEntry) {
        guard pushSettingsRoute(.content(route)) else { return }
        recordReadingEntry(readingEntry, route: route, scope: .settings)
    }

    func replaceSettingsPathFromSystem(_ path: [SettingsRoute]) {
        state.replaceSettingsPath(path)
        pruneSettingsReadingEntries()
    }

    @discardableResult
    func apply(_ command: NavigationCommand) -> Bool {
        switch command {
        case let .replaceRootDetail(root, route):
            guard RouteGrammar.isValid([route], for: root) else {
                return false
            }
            state.replaceRoutes([route], for: root)
            readingEntries[.root(root)] = [:]
            state.selectTab(root.tab)
            return true
        }
    }

    @discardableResult
    func handleExternalURL(_ url: URL) -> Bool {
        guard let command = DeepLinkParser.parse(url) else {
            return false
        }
        guard apply(command) else { return false }
        if case let .replaceRootDetail(root, route) = command,
           case .thread = route {
            // The supported com.baidu.tieba/unidispatch builder keeps native
            // default 0. It is distinct from the iOStbclient (31) entry point.
            let entry: ThreadReadingEntry = url.scheme?.lowercased() == "https" ? .universalLink : .unspecified
            recordReadingEntry(entry, route: route, scope: .root(root))
        }
        return true
    }

    private func replaceRoutes(
        _ routes: [RouteIdentity],
        in root: RootID
    ) -> Bool {
        guard RouteGrammar.isValid(routes, for: root) else {
            return false
        }
        state.replaceRoutes(routes, for: root)
        readingEntries[.root(root)] = readingEntries[.root(root)]?.filter { routes.contains($0.key) }
        return true
    }

    private func recordReadingEntry(_ entry: ThreadReadingEntry, route: RouteIdentity, scope: AppFeatureScope) {
        switch route {
        case .thread, .subposts, .notification: readingEntries[scope, default: [:]][route] = entry
        default: break
        }
    }

    private func pruneSettingsReadingEntries() {
        readingEntries[.settings] = readingEntries[.settings]?.filter { state.settingsPath.contains(.content($0.key)) }
    }
}
