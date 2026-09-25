import Foundation

enum RootID: String, CaseIterable, Codable, Hashable, Sendable {
    case recommendations
    case notifications
    case followedForums = "followed-forums"

    var tab: AppTab {
        switch self {
        case .recommendations:
            .recommendations
        case .notifications:
            .notifications
        case .followedForums:
            .followedForums
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Preserve existing route identity while aligning the visible product hierarchy.
    case followedForums = "followed-forums"
    case recommendations
    case notifications
    case settings

    var id: String {
        rawValue
    }

    var rootID: RootID? {
        switch self {
        case .recommendations:
            .recommendations
        case .followedForums:
            .followedForums
        case .notifications:
            .notifications
        case .settings:
            nil
        }
    }
}

struct ThreadID: Codable, Hashable, Sendable {
    let rawValue: Int64

    init?(_ value: Int64) {
        guard value > 0 else {
            return nil
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid thread ID"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct PostID: Codable, Hashable, Sendable {
    let rawValue: Int64

    init?(_ value: Int64) {
        guard value > 0 else {
            return nil
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid post ID"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum RouteIdentity: Codable, Hashable, Sendable {
    case notification(NotificationTarget)
    case forum(ForumRoute)
    case search
    case subposts(threadID: ThreadID, postID: PostID)
    case thread(ThreadID)
    case userProfile(UserProfileRoute)
}

enum SettingsRoute: Codable, Hashable, Sendable {
    case accountProfile
    case preferences
    case about
#if DEBUG
    case componentGallery
#endif
    case content(RouteIdentity)
    case history
    case licenses
#if DEBUG
    case interactionLab
    case threadContentRendererLab
#endif
}

enum NavigationCommand: Equatable, Sendable {
    case replaceRootDetail(root: RootID, route: RouteIdentity)
}

enum AppShellLayout: Equatable, Sendable {
    case compact
    case regular
}

struct AppNavigationProjection: Equatable, Sendable {
    let activeRoot: RootID?
    let fullPath: [RouteIdentity]
    let detailRoot: RouteIdentity?
    let detailTail: [RouteIdentity]
}

struct AppNavigationState: Equatable, Sendable {
    private(set) var selectedTab: AppTab
    private(set) var routesByRoot: [RootID: [RouteIdentity]]
    private(set) var settingsPath: [SettingsRoute]

    init(
        selectedTab: AppTab = .followedForums,
        routesByRoot: [RootID: [RouteIdentity]] = [:],
        settingsPath: [SettingsRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.settingsPath = SettingsRouteGrammar.canonical(settingsPath)
        self.routesByRoot = Dictionary(
            uniqueKeysWithValues: RootID.allCases.map { root in
                let candidate = routesByRoot[root] ?? []
                let routes = RouteGrammar.isValid(candidate, for: root)
                    ? candidate
                    : []
                return (root, routes)
            }
        )
    }

    func routes(for root: RootID) -> [RouteIdentity] {
        routesByRoot[root] ?? []
    }

    func projection(for layout: AppShellLayout) -> AppNavigationProjection {
        guard let activeRoot = selectedTab.rootID else {
            return AppNavigationProjection(
                activeRoot: nil,
                fullPath: [],
                detailRoot: nil,
                detailTail: []
            )
        }

        let routes = routes(for: activeRoot)
        switch layout {
        case .compact:
            return AppNavigationProjection(
                activeRoot: activeRoot,
                fullPath: routes,
                detailRoot: nil,
                detailTail: []
            )
        case .regular:
            return AppNavigationProjection(
                activeRoot: activeRoot,
                fullPath: routes,
                detailRoot: routes.first,
                detailTail: Array(routes.dropFirst())
            )
        }
    }

    mutating func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }

    mutating func replaceRoutes(
        _ routes: [RouteIdentity],
        for root: RootID
    ) {
        routesByRoot[root] = routes
    }

    mutating func replaceSettingsPath(_ path: [SettingsRoute]) {
        settingsPath = SettingsRouteGrammar.canonical(path)
    }
}

enum RouteGrammar {
    static func isValid(_ routes: [RouteIdentity], for root: RootID) -> Bool {
        guard routes.count <= 5, Set(routes).count == routes.count else {
            return false
        }

        if routes.count >= 2, case .userProfile = routes[routes.count - 1], case .subposts = routes[routes.count - 2] {
            return isValid(Array(routes.dropLast()), for: root)
        }
        guard !routes.isEmpty else {
            return true
        }

        switch root {
        case .recommendations:
            return isValidRecommendationsChain(routes)
        case .followedForums:
            return isValidFollowedForumsChain(routes)
        case .notifications:
            return isValidNotificationChain(routes)
        }
    }

    private static func isValidNotificationChain(_ routes: [RouteIdentity]) -> Bool {
        let threadID: Int64
        switch routes[0] {
        case let .notification(target):
            guard target.threadID > 0, target.postID > 0 else { return false }
            threadID = target.threadID
        case let .thread(thread):
            threadID = thread.rawValue
        default:
            return false
        }
        if routes.count == 1 { return true }
        if routes.count == 2 {
            if case .userProfile = routes[1] { return true }
            if case let .subposts(thread, _) = routes[1] { return thread.rawValue == threadID }
        }
        if routes.count == 3, case let .subposts(thread, _) = routes[1], case .userProfile = routes[2] {
            return thread.rawValue == threadID
        }
        return false
    }

    private static func isValidRecommendationsChain(
        _ routes: [RouteIdentity]
    ) -> Bool {
        switch routes.count {
        case 1:
            return isSearch(routes[0])
                || isForum(routes[0])
                || threadID(from: routes[0]) != nil
        case 2:
            if isSearch(routes[0]) {
                return isForum(routes[1]) || threadID(from: routes[1]) != nil
            }
            if isForum(routes[0]), threadID(from: routes[1]) != nil {
                return true
            }
            return matchingThreadAndSubposts(routes[0], routes[1])
                || matchingThreadAndProfile(routes[0], routes[1])
        case 3:
            if isSearch(routes[0]) {
                if isForum(routes[1]), threadID(from: routes[2]) != nil {
                    return true
                }
                return matchingThreadAndSubposts(routes[1], routes[2])
                    || matchingThreadAndProfile(routes[1], routes[2])
            }
            return isForum(routes[0])
                && (
                    matchingThreadAndSubposts(routes[1], routes[2])
                    || matchingThreadAndProfile(routes[1], routes[2])
                )
        case 4:
            return isSearch(routes[0])
                && isForum(routes[1])
                && (
                    matchingThreadAndSubposts(routes[2], routes[3])
                    || matchingThreadAndProfile(routes[2], routes[3])
                )
        default:
            return false
        }
    }

    private static func isValidFollowedForumsChain(
        _ routes: [RouteIdentity]
    ) -> Bool {
        if isSearch(routes[0]) {
            return isValidRecommendationsChain(routes)
        }
        switch routes.count {
        case 1:
            return isForum(routes[0])
        case 2:
            return isForum(routes[0]) && threadID(from: routes[1]) != nil
        case 3:
            return isForum(routes[0])
                && (
                    matchingThreadAndSubposts(routes[1], routes[2])
                    || matchingThreadAndProfile(routes[1], routes[2])
                )
        default:
            return false
        }
    }

    private static func matchingThreadAndSubposts(
        _ threadRoute: RouteIdentity,
        _ subpostsRoute: RouteIdentity
    ) -> Bool {
        guard let threadID = threadID(from: threadRoute) else {
            return false
        }
        switch subpostsRoute {
        case let .subposts(childThreadID, _):
            return threadID == childThreadID
        case .forum, .search, .thread, .userProfile, .notification:
            return false
        }
    }

    private static func matchingThreadAndProfile(
        _ threadRoute: RouteIdentity,
        _ profileRoute: RouteIdentity
    ) -> Bool {
        threadID(from: threadRoute) != nil && isUserProfile(profileRoute)
    }

    private static func isSearch(_ route: RouteIdentity) -> Bool {
        if case .search = route {
            return true
        }
        return false
    }

    private static func isForum(_ route: RouteIdentity) -> Bool {
        if case .forum = route {
            return true
        }
        return false
    }

    private static func threadID(from route: RouteIdentity) -> ThreadID? {
        if case let .thread(threadID) = route {
            return threadID
        }
        return nil
    }

    private static func isUserProfile(_ route: RouteIdentity) -> Bool {
        if case .userProfile = route {
            return true
        }
        return false
    }
}

enum SettingsRouteGrammar {
    static func canonical(_ routes: [SettingsRoute]) -> [SettingsRoute] {
        if routes.first == .preferences {
            return canonicalPreferences(routes)
        }
        guard routes.count <= 5 else { return [] }
        guard let first = routes.first else { return routes }
        return isValidRootPath(routes, first: first) ? routes : []
    }

    private static func isValidRootPath(
        _ routes: [SettingsRoute], first: SettingsRoute
    ) -> Bool {
        switch first {
        case .preferences:
            return false
        case .history:
            return isValidHistoryPath(routes)
        case .about:
            return isValidAboutPath(routes)
        case .accountProfile, .licenses:
            return routes.count == 1
#if DEBUG
        case .componentGallery, .interactionLab, .threadContentRendererLab:
            return routes.count == 1
#endif
        case .content:
            return false
        }
    }

    private static func isValidAboutPath(_ routes: [SettingsRoute]) -> Bool {
        routes.count == 1 || (routes.count == 2 && routes[1] == .licenses)
    }

    private static func isValidHistoryPath(_ routes: [SettingsRoute]) -> Bool {
        let contents = routes.dropFirst().compactMap { route -> RouteIdentity? in
            guard case let .content(content) = route else { return nil }
            return content
        }
        return contents.count == routes.count - 1 && isValidHistoryContentChain(contents)
    }

    private static func canonicalPreferences(_ routes: [SettingsRoute]) -> [SettingsRoute] {
        let children = Array(routes.dropFirst())
        guard routes.count <= 6, !children.contains(.preferences),
              canonical(children) == children else { return [] }
        return routes
    }

    private static func isValidHistoryContentChain(
        _ routes: [RouteIdentity]
    ) -> Bool {
        guard routes.count <= 4 else {
            return false
        }
        guard let first = routes.first else {
            return true
        }
        switch first {
        case .forum, .thread, .userProfile:
            break
        case .search, .subposts, .notification:
            return false
        }
        for (parent, child) in zip(routes, routes.dropFirst()) {
            switch (parent, child) {
            case (.forum, .thread), (.thread, .userProfile), (.subposts, .userProfile):
                continue
            case let (.thread(threadID), .subposts(childThreadID, _)):
                guard threadID == childThreadID else {
                    return false
                }
            default:
                return false
            }
        }
        return true
    }
}
